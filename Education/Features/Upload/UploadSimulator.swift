//
//  UploadSimulator.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import Combine

struct SimulatedLesson {
    let pdfName: String
    let jsonFiles: [String]   // we keep this for later JSON rendering
    let htmlFile: String?     // file name WITHOUT .html
}

enum UploadSimulator {
    // KEYS must match EXACT filenames seen in the Files picker.
    static let map: [String: SimulatedLesson] = [
        "The Science of Accessible Design.pdf": .init(
            pdfName: "The Science of Accessible Design",
            jsonFiles: ["sample1_page1.json", "sample1_page2.json"],
            htmlFile:  "The Science of Accessible Design"
        ),
        "area-of-compound-figures.pdf": .init(
            pdfName: "area-of-compound-figures",
            jsonFiles: ["sample2_page1.json", "sample2_page2.json"],
            htmlFile:  "area-of-compound-figures"
        ),
        "Precalculus Math Packet 4 (new).pdf": .init(
            pdfName: "Precalculus Math Packet 4",
            jsonFiles: (1...10).map { "sample3_page\($0).json" },
            htmlFile:  "Precalculus Math Packet 4"
        )
    ]

    static func uploadAndConvert(selectedFilename: String,
                                 delay seconds: Double = 1.2) async throws -> SimulatedLesson {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        guard let lesson = map[selectedFilename] else {
            throw NSError(domain: "Upload", code: 404,
                          userInfo: [NSLocalizedDescriptionKey:
                                     "No mapping for “\(selectedFilename)”. Use one of the 3 sample PDFs."])
        }
        return lesson
    }
}
