//
//  UploadSheetView.swift
//  Education
//
//  Created by Keerthi Reddy
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sample PDF Model for Demo

struct SamplePDF: Identifiable {
    let id: String
    let filename: String
    let displayName: String
    let iconName: String 
    
    static let samples: [SamplePDF] = [
        SamplePDF(
            id: "sample1",
            filename: "The Science of Accessible Design.pdf",
            displayName: "The Science of Accessible Design",
            iconName: "pdf-icon-blue"
        ),
        SamplePDF(
            id: "sample2",
            filename: "Area of Compound Figures.pdf",
            displayName: "Area of Compound Figures",
            iconName: "pdf-icon-green"
        ),
        SamplePDF(
            id: "sample3",
            filename: "Precalculus Math Packet 4.pdf",
            displayName: "Precalculus Math Packet 4",
            iconName: "pdf-icon-purple"
        )
    ]
}

struct UploadSheetView: View {
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var haptics: HapticService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ObservedObject var uploadManager: UploadManager
    @State private var showPicker = false
    @State private var showSampleSelection = false

    // iPad-aware sizing
    private var maxSheetWidth: CGFloat {
        horizontalSizeClass == .regular ? 500 : .infinity
    }
    
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 48 : 24
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch uploadManager.state {
                case .idle:
                    idleStateView
                    
                case .confirming:
                    idleStateView // Show same view while confirming

                case .uploading:
                    uploadingStateView

                case .processing:
                    processingStateView

                case .done(let item):
                    doneStateView(item: item)

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
            .sheet(isPresented: $showSampleSelection) {
                SamplePDFSelectionSheet(
                    onSelect: { samplePDF in
                        let dummyURL = URL(fileURLWithPath: samplePDF.filename)
                        showSampleSelection = false
                        uploadManager.beginConfirm(fileURL: dummyURL)
                    },
                    onCancel: {
                        showSampleSelection = false
                    }
                )
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

            // Demo: Select from sample PDFs
            Button("Browse Sample PDFs") {
                haptics.tapSelection()
                showSampleSelection = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Browse sample PDFs")
            .accessibilityHint("Opens a list of sample PDF files to upload")
            
            // Or use real file picker
            Button("Browse from Device") {
                haptics.tapSelection()
                showPicker = true
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Browse from device")
            .accessibilityHint("Opens file picker to select a PDF from your device")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Uploading file to server")
        .onAppear {
            haptics.tapSelection()
            // VoiceOver announcement
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Uploading file to server"
                )
            }
        }
    }
    
    private var processingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityHidden(true)
            
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("File uploaded. Processing in progress. You can continue with other work.")
        .onAppear {
            haptics.success()
            // VoiceOver announcement
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "File uploaded. Processing in progress. You can continue with other work."
                )
            }
        }
    }
    
    private func doneStateView(item: LessonIndexItem) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.success)
                .accessibilityHidden(true)
            
            Text("File uploaded. Processing complete.")
                .font(.custom("Arial", size: 17).weight(.bold))
                .foregroundColor(ColorTokens.success)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Processing complete. \(item.title) is ready.")
        .onAppear {
            haptics.success()
            lessonStore.addConverted(item)
            
            // VoiceOver announcement for completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Processing complete. \(item.title) is ready to view."
                )
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                uploadManager.reset()
                dismiss()
            }
        }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
        .onAppear {
            haptics.error()
            // VoiceOver announcement
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Error: \(message)"
                )
            }
        }
    }
}

// MARK: - Sample PDF Selection Sheet

struct SamplePDFSelectionSheet: View {
    let onSelect: (SamplePDF) -> Void
    let onCancel: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var maxWidth: CGFloat {
        horizontalSizeClass == .regular ? 500 : .infinity
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Select a sample PDF to convert")
                        .font(.custom("Arial", size: 15))
                        .foregroundColor(Color(hex: "#61758A"))
                        .padding(.top, 8)
                        .accessibilityAddTraits(.isHeader)
                    
                    ForEach(SamplePDF.samples) { sample in
                        Button {
                            onSelect(sample)
                        } label: {
                            SamplePDFRow(sample: sample)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(sample.displayName)
                        .accessibilityHint("Double tap to select this PDF for upload")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "#F6F7F8"))
            .navigationTitle("Sample PDFs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.custom("Arial", size: 17))
                    .foregroundColor(ColorTokens.primary)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Select a sample PDF to convert. \(SamplePDF.samples.count) samples available."
                )
            }
        }
    }
}

// MARK: - Sample PDF Row

struct SamplePDFRow: View {
    let sample: SamplePDF
    
    var body: some View {
        HStack(spacing: 12) {
            // PDF Icon - Use custom asset or fallback to SF Symbol
            Group {
                if UIImage(named: sample.iconName) != nil {
                    Image(sample.iconName)
                        .resizable()
                        .scaledToFit()
                } else {
                    // Fallback SF Symbol
                    Image(systemName: "doc.fill")
                        .font(.system(size: 24))
                        .foregroundColor(pdfIconColor(for: sample.id))
                }
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(sample.displayName)
                    .font(.custom("Arial", size: 17))
                    .foregroundColor(Color(hex: "#121417"))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(sample.filename)
                    .font(.custom("Arial", size: 13))
                    .foregroundColor(Color(hex: "#91949B"))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#91949B"))
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func pdfIconColor(for id: String) -> Color {
        switch id {
        case "sample1": return Color(hex: "#214F9A") // Blue
        case "sample2": return Color(hex: "#208515") // Green
        case "sample3": return Color(hex: "#332177") // Purple
        default: return Color(hex: "#B31111") // Red
        }
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
            
            confirmationCard
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Upload \(fileName)? Choose Yes to upload and convert, or No to cancel."
                )
            }
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
                .accessibilityLabel("No, cancel upload")
                
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
        .frame(width: dialogWidth, height: 214)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onTapGesture {
            // Prevent tap through
        }
    }
}
