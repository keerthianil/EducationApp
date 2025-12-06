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

    @ObservedObject var uploadManager: UploadManager
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch uploadManager.state {
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
                            let dummyFileURL = URL(fileURLWithPath: "Algebra.pdf")
                            uploadManager.beginConfirm(fileURL: dummyFileURL)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                case .confirming:
                    VStack(spacing: 18) {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.system(size: 48))
                            .foregroundColor(ColorTokens.primary)

                        Text("Browse a PDF to make it accessible")
                            .font(.custom("Arial", size: 17))
                            .foregroundColor(Color(hex: "#4E5055"))
                    }

                case .uploading:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Uploading…")
                            .font(.custom("Arial", size: 17))
                            .foregroundColor(Color(hex: "#4E5055"))
                    }
                    .onAppear {
                        haptics.tapSelection()
                        // VoiceOver announcement
                        if UIAccessibility.isVoiceOverRunning {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                UIAccessibility.post(
                                    notification: .announcement,
                                    argument: "Uploading file to server"
                                )
                            }
                        }
                    }

                case .processing:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        VStack(spacing: 4) {
                            Text("File uploaded. Processing in progress.")
                                .font(.custom("Arial", size: 17))
                                .foregroundColor(Color(hex: "#121417"))
                                .multilineTextAlignment(.center)
                            
                            Text("You can continue with other work")
                                .font(.custom("Arial", size: 15))
                                .foregroundColor(Color(hex: "#61758A"))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .onAppear {
                        haptics.success()
                        // VoiceOver announcement as per Use Case 2
                        if UIAccessibility.isVoiceOverRunning {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                UIAccessibility.post(
                                    notification: .announcement,
                                    argument: "File uploaded. Processing in progress. You can continue with other work."
                                )
                            }
                        }
                    }

                case .done(let item):
                    Text("File uploaded. Processing complete.")
                        .font(.custom("Arial", size: 17).weight(.bold))
                        .foregroundColor(ColorTokens.success)
                        .onAppear {
                            haptics.success()
                            lessonStore.addConverted(item)

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                uploadManager.reset()
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        haptics.tapSelection()
                        uploadManager.reset()
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
                    uploadManager.beginConfirm(fileURL: url)
                    showPicker = false
                }
            }
            .overlay {
                if case .confirming(let url) = uploadManager.state {
                    UploadConfirmationDialog(
                        fileName: url.lastPathComponent,
                        onConfirm: {
                            haptics.tapSelection()
                            // Start upload
                            uploadManager.uploadAndConvert(fileURL: url)
                            // Dismiss immediately - file will show in Dashboard "Uploaded" section
                            dismiss()
                        },
                        onCancel: {
                            haptics.tapSelection()
                            uploadManager.reset()
                        }
                    )
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

// MARK: - Upload Confirmation Dialog

struct UploadConfirmationDialog: View {
    let fileName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay (40% opacity black)
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Dialog card centered
            confirmationCard
        }
        .onAppear {
            if UIAccessibility.isVoiceOverRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Upload \(fileName)? Choose Yes to upload and convert, or No to cancel."
                    )
                }
            }
        }
    }
    
    private var confirmationCard: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#121417"))
                }
                .frame(width: 32, height: 32)
                .accessibilityLabel("Close")
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
            
            // Title
            Text("Upload \u{201C}\(fileName)\u{201D}?")
                .font(.custom("Arial", size: 24))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            
            // Buttons
            HStack(spacing: 16) {
                // No
                Button {
                    onCancel()
                } label: {
                    Text("No")
                        .font(.custom("Arial", size: 17).weight(.bold))
                        .foregroundColor(Color(hex: "#1C636F"))
                        .frame(width: 112, height: 42)
                }
                .background(Color(hex: "#E8F2F2"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#1C636F"), lineWidth: 1)
                )
                .accessibilityLabel("No, cancel upload")
                
                // Yes
                Button {
                    onConfirm()
                } label: {
                    Text("Yes")
                        .font(.custom("Arial", size: 17).weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 112, height: 42)
                }
                .background(Color(hex: "#1C636F"))
                .cornerRadius(8)
                .accessibilityLabel("Yes, upload and convert")
            }
            .padding(.bottom, 20)
        }
        .frame(width: 394, height: 214)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onTapGesture {
            // Prevent tap through to dismiss - do nothing
        }
    }
}