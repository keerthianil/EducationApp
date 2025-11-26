//
//  UploadSheetView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct UploadSheetView: View {
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var haptics: HapticService
    @Environment(\.dismiss) private var dismiss

    @StateObject private var uploader = UploadManager()
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch uploader.state {
                case .idle:
                    VStack(spacing: 18) {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.system(size: 48))
                            .foregroundColor(ColorTokens.primary)

                        Text("Browse a PDF to make it accessible")
                            .font(.custom("Arial", size: 17))
                            .foregroundColor(Color(hex: "#4E5055"))

                        Button("Browse files") {
                            haptics.tapSelection()
                            showPicker = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                case .confirming(let url):
                    VStack(spacing: 12) {
                        Text(url.lastPathComponent)
                            .font(.custom("Arial", size: 17).weight(.bold))
                            .foregroundColor(Color(hex: "#121417"))

                        Text("Upload to convert?")
                            .font(.custom("Arial", size: 17))
                            .foregroundColor(Color(hex: "#4E5055"))

                        HStack(spacing: 12) {
                            Button("No") {
                                haptics.tapSelection()
                                uploader.reset()
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button("Yes") {
                                haptics.tapSelection()
                                uploader.uploadAndConvert(fileURL: url)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }

                case .uploading:
                    ProgressView("Uploading…")

                case .processing:
                    ProgressView("Processing on server…")

                case .done(let item):
                    Text("File uploaded. Processing complete.")
                        .font(.custom("Arial", size: 17).weight(.bold))
                        .foregroundColor(ColorTokens.success)
                        .onAppear {
                            haptics.success()
                            lessonStore.addConverted(item)

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                uploader.reset()
                                dismiss()
                            }
                        }

                case .error(let msg):
                    Text(msg)
                        .foregroundColor(ColorTokens.error)
                        .font(.custom("Arial", size: 17))
                }

                Spacer()
            }
            .padding(24)
            .background(Color(hex: "#F6F7F8"))
            .navigationTitle("Upload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // EXPLICIT Cancel button for blind users
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        haptics.tapSelection()
                        uploader.reset()
                        dismiss()
                    }
                    .font(.custom("Arial", size: 17))
                    .foregroundColor(ColorTokens.primary)
                    .accessibilityLabel("Cancel upload")
                    .accessibilityHint("Closes the upload screen and returns to the home screen.")
                }
            }
            .sheet(isPresented: $showPicker) {
                DocumentPicker { url in
                    uploader.beginConfirm(fileURL: url)
                    showPicker = false
                }
            }
        }
    }
}

// Simple Files picker
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .image, .data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
