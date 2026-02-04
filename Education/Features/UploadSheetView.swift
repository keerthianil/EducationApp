//
//  UploadSheetView.swift
//  Education
//

import SwiftUI
import UniformTypeIdentifiers

struct UploadSheetView: View {
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var haptics: HapticService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ObservedObject var uploadManager: UploadManager
    @State private var showPicker = false

    private var maxSheetWidth: CGFloat {
        horizontalSizeClass == .regular ? 500 : .infinity
    }
    
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 48 : 24
    }

    var body: some View {
        NavigationStack {
            sheetContent
        }
        // Apply gesture to entire sheet
        .onThreeFingerSwipeBack {
            haptics.tapSelection()
            uploadManager.reset()
            dismiss()
        }
    }
    
    private var sheetContent: some View {
        VStack(spacing: 20) {
            switch uploadManager.state {
            case .idle, .done:
                idleStateView
                
            case .confirming:
                idleStateView

            case .uploading:
                uploadingStateView

            case .processing:
                processingStateView

            case .error(let msg):
                errorStateView(message: msg)
            }

            Spacer()
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 24)
        .frame(maxWidth: maxSheetWidth)
        .frame(maxWidth: .infinity)
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
                .accessibilityLabel("Cancel")
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
                        uploadManager.uploadAndConvert(fileURL: url)
                        dismiss()
                    },
                    onCancel: {
                        haptics.tapSelection()
                        uploadManager.reset()
                    }
                )
            }
        }
        .onAppear {
            if case .done = uploadManager.state {
                uploadManager.reset()
            }
        }
    }
    
    // MARK: - State Views
    
    private var idleStateView: some View {
        VStack(spacing: 18) {
            Image(systemName: "icloud.and.arrow.up.fill")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.primary)
                .accessibilityHidden(true)

            Text("Browse a PDF to make it accessible")
                .font(.custom("Arial", size: 17))
                .foregroundColor(Color(hex: "#4E5055"))
                .multilineTextAlignment(.center)

            Button("Browse from Device") {
                haptics.tapSelection()
                showPicker = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Browse from Device")
        }
    }
    
    private var uploadingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityHidden(true)
            
            Text("Uploading…")
                .font(.custom("Arial", size: 17))
                .foregroundColor(Color(hex: "#4E5055"))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Uploading")
    }
    
    private var processingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityHidden(true)
            
            VStack(spacing: 4) {
                Text("Processing")
                    .font(.custom("Arial", size: 17))
                    .foregroundColor(Color(hex: "#121417"))
                
                Text("You can continue with other work")
                    .font(.custom("Arial", size: 15))
                    .foregroundColor(Color(hex: "#61758A"))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing")
    }
    
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.error)
                .accessibilityHidden(true)
            
            Text(message)
                .foregroundColor(ColorTokens.error)
                .font(.custom("Arial", size: 17))
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                haptics.tapSelection()
                uploadManager.reset()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Error")
    }
}

// MARK: - Document Picker

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
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var dialogWidth: CGFloat {
        horizontalSizeClass == .regular ? 450 : 394
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
                .accessibilityHidden(true)
            
            confirmationCard
        }
        .accessibilityAction(.escape) {
            onCancel()
        }
    }
    
    private var confirmationCard: some View {
        VStack(spacing: 0) {
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
            
            Text("Upload \u{201C}\(fileName)\u{201D}?")
                .font(.custom("Arial", size: 24))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .accessibilityLabel("Upload \(fileName)?")
            
            HStack(spacing: 16) {
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
                .accessibilityLabel("No")
                
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
                .accessibilityLabel("Yes")
            }
            .padding(.bottom, 20)
        }
        .frame(width: dialogWidth, height: 214)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onTapGesture { }
        .accessibilityAddTraits(.isModal)
    }
}
