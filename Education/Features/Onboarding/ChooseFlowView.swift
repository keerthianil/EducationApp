//
//  ChooseFlowView.swift
//  Education
//

import SwiftUI
import UIKit

struct ChooseFlowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lessonStore: LessonStore
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverEnabled
    @State private var goToDashboard = false
    @State private var didAnnounceScreen = false
    @State private var showExportSheet = false
    @AccessibilityFocusState private var flow1Focused: Bool

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 50)

                Text("Choose a Scenario")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer().frame(height: 20)

                VStack(spacing: 12) {
                    FlowSelectionButton(title: "Practice Scenario", isEnabled: true) { selectFlow(1) }
                        .accessibilityFocused($flow1Focused)

                    FlowSelectionButton(title: "Scenario 1", isEnabled: true) { selectFlow(2) }

                    FlowSelectionButton(title: "Scenario 2", isEnabled: true) { selectFlow(3) }
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 20)

                Button {
                    showExportSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 16))
                        Text("Export Interaction Data").font(.custom("Arial", size: 15))
                    }
                    .foregroundColor(ColorTokens.primary)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(ColorTokens.primary, lineWidth: 1))
                }
                .accessibilityHidden(true)

                VStack(spacing: 4) {
                    Text("Logged Interactions:").font(.custom("Arial", size: 13)).foregroundColor(Color(hex: "#61758A"))
                    HStack(spacing: 16) {
                        ForEach(1...3, id: \.self) { flow in
                            let count = InteractionLogger.shared.getEntryCount(for: flow)
                            Text("\(InteractionLogger.flowName(for: flow)): \(count)")
                                .font(.custom("Arial", size: 12)).foregroundColor(Color(hex: "#91949B"))
                        }
                    }
                }
                .padding(.top, 8)
                .accessibilityHidden(true)

                Spacer()
            }

            NavigationLink(destination: destinationView(), isActive: $goToDashboard) { EmptyView() }.hidden()
        }
        .navigationBarBackButtonHidden(true)
        .trackScreen("ChooseFlowView")
        .onAppear {
            InteractionLogger.shared.endSession()
            guard !didAnnounceScreen else { return }
            didAnnounceScreen = true
            UIAccessibility.post(notification: .announcement, argument: "Choose a scenario. All 3 scenarios are available for testing.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { flow1Focused = true }
        }
        .sheet(isPresented: $showExportSheet) { ExportDataSheet() }
    }

    private func selectFlow(_ flow: Int) {
        let name = InteractionLogger.flowDisplayName(for: flow)
        InteractionLogger.shared.log(event: .tap, objectType: .button, label: "\(name) Selected", location: .zero, additionalInfo: "User selected \(name)")
        appState.selectedFlow = flow
        appState.completeOnboarding()
        InteractionLogger.shared.startSession(flow: flow)
        lessonStore.applySeedLessons(forFlow: flow)
        goToDashboard = true
    }

    @ViewBuilder
    private func destinationView() -> some View {
        switch appState.selectedFlow {
        case 1: DashboardView().navigationBarBackButtonHidden(true)
        case 2: DashboardFlow2View().navigationBarBackButtonHidden(true)
        case 3: DashboardFlow3View().navigationBarBackButtonHidden(true)
        default: DashboardView().navigationBarBackButtonHidden(true)
        }
    }
}

// MARK: - Flow Selection Button (no subtitle)

private struct FlowSelectionButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .background(isEnabled ? ColorTokens.primary : ColorTokens.primary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(isEnabled ? "Double tap to select" : "Not available")
    }
}

// MARK: - Export Data Sheet

private struct ExportDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exportedURLs: [URL] = []
    @State private var isExporting = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(ColorTokens.primary)
                    .padding(.top, 40)

                Text("Export Interaction Logs")
                    .font(.custom("Arial", size: 22).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))

                VStack(spacing: 12) {
                    ForEach(1...3, id: \.self) { flow in
                        let count = InteractionLogger.shared.getEntryCount(for: flow)
                        HStack {
                            Text(InteractionLogger.flowDisplayName(for: flow))
                                .font(.custom("Arial", size: 17))
                                .foregroundColor(Color(hex: "#121417"))
                            Spacer()
                            Text("\(count) entries")
                                .font(.custom("Arial", size: 15))
                                .foregroundColor(Color(hex: "#61758A"))
                        }
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Color(hex: "#F6F7F8"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    // Export All Flows as Excel
                    Button {
                        exportAll(format: .excel)
                    } label: {
                        HStack {
                            if isExporting { ProgressView().scaleEffect(0.8).tint(.white) }
                            Text(isExporting ? "Exporting..." : "Export All Flows (Excel)")
                                .font(.custom("Arial", size: 17).weight(.bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(ColorTokens.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isExporting)

                    // Export All Flows as PDF
                    Button {
                        exportAll(format: .pdf)
                    } label: {
                        Text("Export All Flows (PDF)")
                            .font(.custom("Arial", size: 17).weight(.bold))
                            .foregroundColor(ColorTokens.primary)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ColorTokens.primary, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isExporting)

                    Button("Clear All Data") {
                        InteractionLogger.shared.clearAllData()
                        dismiss()
                    }
                    .font(.custom("Arial", size: 15))
                    .foregroundColor(ColorTokens.error)
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if !exportedURLs.isEmpty {
                    ShareSheet(activityItems: exportedURLs)
                }
            }
        }
    }

    private enum ExportFormat { case excel, pdf }

    private func exportAll(format: ExportFormat) {
        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            let urls: [URL]
            switch format {
            case .excel:
                urls = InteractionLogger.shared.exportAllFlowsAsExcel()
            case .pdf:
                urls = InteractionLogger.shared.exportAllFlowsAsPDF()
            }
            DispatchQueue.main.async {
                isExporting = false
                if !urls.isEmpty {
                    exportedURLs = urls
                    showShareSheet = true
                }
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
