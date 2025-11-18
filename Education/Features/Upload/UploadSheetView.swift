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
                    VStack(spacing: 12) {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.largeTitle)
                            .foregroundColor(ColorTokens.primary)

                        Text("Browse a PDF to make it accessible")
                            .font(Typography.body)

                        Button("Browse files") {
                            haptics.tapSelection()
                            showPicker = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                case .confirming(let url):
                    VStack(spacing: 12) {
                        Text(url.lastPathComponent)
                            .font(Typography.bodyBold)

                        Text("Upload to convert?")
                            .font(Typography.body)

                        HStack {
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
                        .font(Typography.bodyBold)
                        .onAppear {
                            // Haptic cue and push into Recent / banner
                            haptics.success()
                            lessonStore.addConverted(item)

                            // Dismiss after a short pause so VoiceOver can speak the message
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                uploader.reset()
                                dismiss()
                            }
                        }

                case .error(let msg):
                    Text(msg)
                        .foregroundColor(ColorTokens.error)
                        .font(Typography.body)
                }

                Spacer()
            }
            .padding(Spacing.screenPadding)
            .background(ColorTokens.backgroundAdaptive)
            .navigationTitle("Upload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Explicit Cancel so blind users don’t rely on swipe-to-dismiss
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        haptics.tapSelection()
                        uploader.reset()
                        dismiss()
                    }
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
