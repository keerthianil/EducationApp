//
//  APIService.swift
//  Education
//
//  Handles all communication with the PDF conversion backend.
//  Sends PDFs → receives JSON in the same format the app already uses.
//
//  HOW IT WORKS:
//  1. App picks a PDF file from the user's device
//  2. This service uploads the PDF bytes to your server
//  3. Server processes the PDF (OCR, math extraction, graphics)
//  4. Server returns JSON matching the format in raw_json/
//  5. App saves JSON to Documents/ and displays it like any other lesson
//
//  SETUP:
//  Replace `baseURL` with your actual server URL once it's deployed.
//

import Foundation
import UIKit
import Combine

// MARK: - API Configuration

/// Change this to  real server URL when you have one.
/// During development, you can use a local server: "http://localhost:8000"
/// For TestFlight / production, use your deployed URL: "https://your-server.com"
enum APIConfig {
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // CHANGE THIS to real server URL
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    static let baseURL = "https://YOURSERVER"
    
    /// The endpoint that accepts PDF uploads and returns JSON
    /// Your server should have a POST endpoint at this path
    static var uploadEndpoint: String { "\(baseURL)/api/convert" }
    
    /// The endpoint to check processing status (for async/queued processing)
    static var statusEndpoint: String { "\(baseURL)/api/status" }
    
    /// Timeout for the upload request (seconds)
    static let uploadTimeout: TimeInterval = 120
    
    /// Timeout for the status polling request (seconds)
    static let statusTimeout: TimeInterval = 30
    
    /// How often to poll for status when processing is async (seconds)
    static let pollingInterval: TimeInterval = 3.0
}

// MARK: - API Response Models

/// What the server sends back after processing a PDF.
/// This matches the JSON structure your app already parses.
struct ConversionResponse: Codable {
    let status: String           // "completed", "processing", "error"
    let jobId: String?           // For async processing — track the job
    let title: String?           // Document title extracted from PDF
    let pages: [PageData]?       // The actual content (same format as your JSON files)
    let error: String?           // Error message if something went wrong
    
    struct PageData: Codable {
        let content: [[String: AnyCodable]]  // Array of node dictionaries
    }
}

/// What the server sends back when you check job status
struct StatusResponse: Codable {
    let status: String           // "processing", "completed", "error"
    let progress: Double?        // 0.0 to 1.0
    let result: ConversionResponse?  // Only present when status == "completed"
    let error: String?
}

// MARK: - AnyCodable (helper to decode arbitrary JSON)

/// Wrapper that lets us decode JSON with mixed types (strings, numbers, arrays, dicts).
/// Your existing FlexibleLessonParser already handles this — we just need to get
/// the raw JSON data to it.
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) { self.value = value }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) { value = string }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let array = try? container.decode([AnyCodable].self) { value = array.map { $0.value } }
        else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        }
        else { value = NSNull() }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String { try container.encode(string) }
        else if let int = value as? Int { try container.encode(int) }
        else if let double = value as? Double { try container.encode(double) }
        else if let bool = value as? Bool { try container.encode(bool) }
        else { try container.encodeNil() }
    }
}

// MARK: - API Error Types

enum APIError: LocalizedError {
    case serverUnreachable
    case uploadFailed(statusCode: Int)
    case processingFailed(message: String)
    case invalidResponse
    case timeout
    case noInternetConnection
    
    var errorDescription: String? {
        switch self {
        case .serverUnreachable:
            return "Cannot reach the server. Check your internet connection and try again."
        case .uploadFailed(let code):
            return "Upload failed (error \(code)). Please try again."
        case .processingFailed(let msg):
            return "Processing failed: \(msg)"
        case .invalidResponse:
            return "Received an unexpected response from the server."
        case .timeout:
            return "The request timed out. The server might be busy — try again in a moment."
        case .noInternetConnection:
            return "No internet connection. Please connect to Wi-Fi or cellular data."
        }
    }
}

// MARK: - API Service

final class APIService: ObservableObject {
    static let shared = APIService()
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    
    private var pollingTimer: Timer?
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.uploadTimeout
        config.timeoutIntervalForResource = APIConfig.uploadTimeout * 2
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Upload PDF and Get JSON Back
    
    /// The main method. Sends a PDF to the server and returns the raw JSON data
    /// that your FlexibleLessonParser can parse.
    ///
    /// - Parameters:
    ///   - fileURL: Local URL of the PDF file on the device
    ///   - progressCallback: Called with 0.0–1.0 as upload/processing progresses
    ///   - completion: Called with Result containing either [Data] (one per page) or an error
    func uploadPDF(
        fileURL: URL,
        progressCallback: @escaping (Double) -> Void,
        completion: @escaping (Result<ConversionResult, Error>) -> Void
    ) {
        // 1. Read the PDF file
        guard let pdfData = try? Data(contentsOf: fileURL) else {
            completion(.failure(APIError.uploadFailed(statusCode: 0)))
            return
        }
        
        DispatchQueue.main.async {
            self.isUploading = true
            self.uploadProgress = 0.0
        }
        
        progressCallback(0.05) // Starting upload
        
        // 2. Build the multipart/form-data request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: APIConfig.uploadEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = APIConfig.uploadTimeout
        
        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(pdfData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        progressCallback(0.15) // Upload prepared
        
        // 3. Send the request
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isUploading = false
            }
            
            // Handle network errors
            if let error = error as NSError? {
                if error.code == NSURLErrorNotConnectedToInternet {
                    completion(.failure(APIError.noInternetConnection))
                } else if error.code == NSURLErrorTimedOut {
                    completion(.failure(APIError.timeout))
                } else {
                    completion(.failure(APIError.serverUnreachable))
                }
                return
            }
            
            // Check HTTP status code
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.uploadFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            progressCallback(0.5) // Server received, processing
            
            // 4. Parse the response
            do {
                let response = try JSONDecoder().decode(ConversionResponse.self, from: data)
                
                switch response.status {
                case "completed":
                    // Server processed synchronously — we have the result
                    progressCallback(0.9)
                    let result = self.buildResult(from: response, rawData: data)
                    progressCallback(1.0)
                    completion(.success(result))
                    
                case "processing":
                    // Server is processing async — poll for status
                    if let jobId = response.jobId {
                        self.pollForCompletion(
                            jobId: jobId,
                            progressCallback: progressCallback,
                            completion: completion
                        )
                    } else {
                        completion(.failure(APIError.invalidResponse))
                    }
                    
                case "error":
                    let msg = response.error ?? "Unknown error"
                    completion(.failure(APIError.processingFailed(message: msg)))
                    
                default:
                    completion(.failure(APIError.invalidResponse))
                }
            } catch {
                // If the server returns raw JSON pages directly (not wrapped in ConversionResponse),
                // try to use the data as-is
                progressCallback(0.9)
                let result = ConversionResult(
                    title: fileURL.deletingPathExtension().lastPathComponent,
                    pageDataList: [data]
                )
                progressCallback(1.0)
                completion(.success(result))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Async/Await Version (iOS 15+)
    
    /// Modern async/await version of uploadPDF.
    @available(iOS 15.0, *)
    func uploadPDF(fileURL: URL, progressCallback: @escaping (Double) -> Void) async throws -> ConversionResult {
        try await withCheckedThrowingContinuation { continuation in
            uploadPDF(fileURL: fileURL, progressCallback: progressCallback) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // MARK: - Poll for Completion (async processing)
    
    /// When the server queues the job, we poll every few seconds until it's done.
    private func pollForCompletion(
        jobId: String,
        progressCallback: @escaping (Double) -> Void,
        completion: @escaping (Result<ConversionResult, Error>) -> Void
    ) {
        var pollCount = 0
        let maxPolls = 60 // Give up after ~3 minutes (60 * 3s)
        
        DispatchQueue.main.async { [weak self] in
            self?.pollingTimer?.invalidate()
            self?.pollingTimer = Timer.scheduledTimer(withTimeInterval: APIConfig.pollingInterval, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                
                pollCount += 1
                if pollCount > maxPolls {
                    timer.invalidate()
                    completion(.failure(APIError.timeout))
                    return
                }
                
                self.checkStatus(jobId: jobId) { statusResult in
                    switch statusResult {
                    case .success(let statusResponse):
                        switch statusResponse.status {
                        case "completed":
                            timer.invalidate()
                            if let result = statusResponse.result {
                                progressCallback(0.95)
                                let conversionResult = self.buildResult(from: result, rawData: nil)
                                progressCallback(1.0)
                                completion(.success(conversionResult))
                            } else {
                                completion(.failure(APIError.invalidResponse))
                            }
                            
                        case "processing":
                            let progress = statusResponse.progress ?? (0.5 + Double(pollCount) * 0.005)
                            progressCallback(min(progress, 0.9))
                            
                        case "error":
                            timer.invalidate()
                            let msg = statusResponse.error ?? "Processing failed"
                            completion(.failure(APIError.processingFailed(message: msg)))
                            
                        default:
                            break
                        }
                        
                    case .failure:
                        // Network blip during polling — keep trying
                        break
                    }
                }
            }
            if let t = self?.pollingTimer { RunLoop.current.add(t, forMode: .common) }
        }
    }
    
    /// Check the status of an async processing job.
    private func checkStatus(jobId: String, completion: @escaping (Result<StatusResponse, Error>) -> Void) {
        let urlString = "\(APIConfig.statusEndpoint)/\(jobId)"
        guard let url = URL(string: urlString) else {
            completion(.failure(APIError.invalidResponse))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = APIConfig.statusTimeout
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            do {
                let status = try JSONDecoder().decode(StatusResponse.self, from: data)
                completion(.success(status))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Build Result
    private func buildResult(from response: ConversionResponse, rawData: Data?) -> ConversionResult {
        var pageDataList: [Data] = []
        
        if let pages = response.pages {
            for page in pages {
                // Convert each page's content array back to raw JSON
                let rawContent: [[String: Any]] = page.content.map { dict in
                    dict.mapValues { $0.value }
                }
                let pageDict: [String: Any] = ["content": rawContent]
                if let jsonData = try? JSONSerialization.data(withJSONObject: pageDict) {
                    pageDataList.append(jsonData)
                }
            }
        }
        
        if pageDataList.isEmpty, let raw = rawData {
            pageDataList = [raw]
        }
        
        return ConversionResult(
            title: response.title ?? "Converted Document",
            pageDataList: pageDataList
        )
    }
    // MARK: - Cleanup
    
    func cancelPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    deinit {
        cancelPolling()
    }
}

// MARK: - Conversion Result

/// What we pass back to the app after a successful conversion.
/// Contains JSON data for each page, ready for FlexibleLessonParser.
struct ConversionResult {
    let title: String
    let pageDataList: [Data]  // Each element is JSON data for one page
}
