//
//  UploadSheetView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//
import SwiftUI
import UniformTypeIdentifiers

struct UploadSheetView: View {
    // Simple stage machine so every case returns a View
    private enum Stage: Equatable {
        case idle
        case confirming(URL)
        case uploading
        case processing
        case done(String)         // html file name (WITHOUT .html)
        case error(String)
    }

    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .idle
    @State private var showImporter = false

    // Present the HTML reader in a sheet
    private struct HTMLDoc: Identifiable { let id = UUID(); let name: String }
    @State private var htmlDoc: HTMLDoc?

    var body: some View {
        NavigationStack {
            content
                .padding(24)
                .navigationTitle("Upload")
                .fileImporter(
                    isPresented: $showImporter,
                    allowedContentTypes: [.pdf],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let url = urls.first else { return }
                        stage = .confirming(url)
                    case .failure(let error):
                        stage = .error(error.localizedDescription)
                    }
                }
        }
        // Present the HTML in a separate sheet so it scrolls and matches Figma (light mode)
        .sheet(item: $htmlDoc, onDismiss: { stage = .idle }) { doc in
            NavigationStack {
                WebLessonView(htmlFileName: doc.name)   // see file #2 below
                    .navigationTitle(doc.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { htmlDoc = nil }
                        }
                    }
                    .preferredColorScheme(.light)
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Screen content

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .idle:
            VStack(spacing: 16) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundColor(ColorTokens.primary)
                Text("Browse a PDF to make it accessible")
                    .font(Typography.body)
                    .foregroundColor(ColorTokens.textPrimary)
                Text("Use one of the three sample PDFs so we can open the matching accessible version.")
                    .font(Typography.footnote)
                    .foregroundColor(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Browse files") { showImporter = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint("Opens Files.")
            }

        case .confirming(let url):
            VStack(spacing: 20) {
                Text(url.lastPathComponent)
                    .font(Typography.bodyBold)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("Upload to make this document accessible?")
                    .font(Typography.body)
                    .foregroundColor(ColorTokens.textPrimary)
                HStack {
                    Button("No") { stage = .idle }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Yes") {
                        startSimulatedUpload(for: url)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }

        case .uploading:
            ProgressView("Uploading…")
                .onAppear {
                    UIAccessibility.post(notification: .announcement, argument: "Uploading")
                }

        case .processing:
            ProgressView("Processing on server…")
                .onAppear {
                    UIAccessibility.post(notification: .announcement, argument: "Processing on server")
                }

        case .done(let htmlName):
            // Show a small view AND run side-effect in onAppear (so we don't return `()`)
            VStack(spacing: 12) {
                Label("Accessible version ready", systemImage: "checkmark.circle.fill")
                    .font(Typography.headline)
                Text("Opening \(htmlName)…")
                    .font(Typography.subheadline)
                    .foregroundColor(ColorTokens.textSecondary)
            }
            .onAppear {
                // Present the HTML reader sheet
                htmlDoc = HTMLDoc(name: htmlName)
                // Close the upload sheet a moment later
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dismiss() }
            }

        case .error(let message):
            VStack(spacing: 16) {
                Text(message)
                    .foregroundColor(ColorTokens.error)
                    .multilineTextAlignment(.center)
                Button("Try again") { stage = .idle }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    // MARK: - Helpers

    /// Simulate upload + conversion and then move to .done(htmlName).
    private func startSimulatedUpload(for url: URL) {
        stage = .uploading
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            stage = .processing
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            let htmlName = mapPDFToHTMLName(url.lastPathComponent)
            stage = .done(htmlName)
        }
    }

    /// Map the three sample PDFs to your bundled HTML names (WITHOUT ".html").
    private func mapPDFToHTMLName(_ pdfFileName: String) -> String {
        let map: [String: String] = [
            "The Science of Accessible Design.pdf": "The Science of Accessible Design",
            "area-of-compound-figures.pdf": "area-of-compound-figures",
            "Precalculus Math Packet 4 (new).pdf": "Precalculus Math Packet 4"
        ]
        if let exact = map[pdfFileName] { return exact }
        // Fallback: strip common suffixes
        return pdfFileName
            .replacingOccurrences(of: ".pdf", with: "")
            .replacingOccurrences(of: " (new)", with: "")
    }
}
