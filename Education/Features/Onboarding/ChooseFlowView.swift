//
//  ChooseFlowView.swift
//  Education
//
//  Features/Onboarding/Views/ChooseFlowView.swift
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
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 50)
                
                Text("Choose a Flow")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Select a dashboard layout for A/B testing")
                    .font(.custom("Arial", size: 15))
                    .foregroundColor(Color(hex: "#61758A"))
                    .multilineTextAlignment(.center)
                
                Spacer()
                    .frame(height: 20)
                
                VStack(spacing: 12) {
                    // Flow 1 - Current Design
                    FlowSelectionButton(
                        flowNumber: 1,
                        title: "Practice Scenario",
                        subtitle: "Bottom tabs + Vertical menu",
                        isEnabled: true
                    ) {
                        selectFlow(1)
                    }
                    .accessibilityFocused($flow1Focused)
                    
                    // Flow 2 - Top tabs design
                    FlowSelectionButton(
                        flowNumber: 2,
                        title: "Scenario 1",
                        subtitle: "Top tabs (Home/All files)",
                        isEnabled: true
                    ) {
                        selectFlow(2)
                    }
                    
                    // Flow 3 - Upload tabs design
                    FlowSelectionButton(
                        flowNumber: 3,
                        title: "Scenario 2",
                        subtitle: "Upload/Teacher/Recent tabs + Side menu",
                        isEnabled: true
                    ) {
                        selectFlow(3)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                    .frame(height: 20)
            
                // Export Data Button (keep visible, hide from VO so focus stays on flows)
                Button {
                    showExportSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                        Text("Export Interaction Data")
                            .font(.custom("Arial", size: 15))
                    }
                    .foregroundColor(ColorTokens.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ColorTokens.primary, lineWidth: 1)
                    )
                }
                .accessibilityHidden(isVoiceOverEnabled)
                
                // Entry counts (keep visible, hide from VO so focus stays on flows)
                VStack(spacing: 4) {
                    Text("Logged Interactions:")
                        .font(.custom("Arial", size: 13))
                        .foregroundColor(Color(hex: "#61758A"))
                    
                    HStack(spacing: 16) {
                        ForEach(1...3, id: \.self) { flow in
                            let count = InteractionLogger.shared.getEntryCount(for: flow)
                            Text("\(flow == 1 ? "Practice Scenario" : flow == 2 ? "Scenario 1" : "Scenario 2"): \(count)")
                                .font(.custom("Arial", size: 12))
                                .foregroundColor(Color(hex: "#91949B"))
                        }
                    }
                }
                .padding(.top, 8)
                .accessibilityHidden(isVoiceOverEnabled)
                
                Spacer()
            }
            
            // Navigation based on selected flow
            NavigationLink(
                destination: destinationView(),
                isActive: $goToDashboard
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationBarBackButtonHidden(true)
        .trackScreen("ChooseFlowView")
        .onAppear {
            // End any previous session
            InteractionLogger.shared.endSession()
            
            guard !didAnnounceScreen else { return }
            didAnnounceScreen = true
            
            UIAccessibility.post(notification: .announcement, argument: "Choose a Flow. All 3 flows are available for testing.")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                flow1Focused = true
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportDataSheet()
        }
    }
    
    private func selectFlow(_ flow: Int) {
        // Log the selection
        let scenarioName: String = {
            switch flow {
            case 1: return "Practice Scenario"
            case 2: return "Scenario 1"
            case 3: return "Scenario 2"
            default: return "Flow \(flow)"
            }
        }()
        InteractionLogger.shared.log(
            event: .tap,
            objectType: .button,
            label: "\(scenarioName) Selected",
            location: .zero,
            additionalInfo: "User selected \(scenarioName)"
        )
        
        appState.selectedFlow = flow
        appState.completeOnboarding()
        
        // Start logging session for this flow
        InteractionLogger.shared.startSession(flow: flow)

        // Phase 1: apply Flow 1 practice scenario lesson seeds only
        lessonStore.applySeedLessons(forFlow: flow)
        
        goToDashboard = true
    }
    
    @ViewBuilder
    private func destinationView() -> some View {
        switch appState.selectedFlow {
        case 1:
            DashboardView()
                .navigationBarBackButtonHidden(true)
        case 2:
            DashboardFlow2View()
                .navigationBarBackButtonHidden(true)
        case 3:
            DashboardFlow3View()
                .navigationBarBackButtonHidden(true)
        default:
            DashboardView()
                .navigationBarBackButtonHidden(true)
        }
    }
}

// MARK: - Flow Selection Button

private struct FlowSelectionButton: View {
    let flowNumber: Int
    let title: String
    let subtitle: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.custom("Arial", size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(isEnabled ? ColorTokens.primary : ColorTokens.primary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isEnabled)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint(isEnabled ? "Double tap to select this flow" : "Not available")
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
                            Text(flow == 1 ? "Practice Scenario" : flow == 2 ? "Scenario 1" : "Scenario 2")
                                .font(.custom("Arial", size: 17))
                                .foregroundColor(Color(hex: "#121417"))
                            
                            Spacer()
                            
                            Text("\(count) entries")
                                .font(.custom("Arial", size: 15))
                                .foregroundColor(Color(hex: "#61758A"))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#F6F7F8"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        exportAllFlows()
                    } label: {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            Text(isExporting ? "Exporting..." : "Export All Flows")
                                .font(.custom("Arial", size: 17).weight(.bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(ColorTokens.primary)
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
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if !exportedURLs.isEmpty {
                    ShareSheet(activityItems: exportedURLs)
                }
            }
        }
    }
    
    private func exportAllFlows() {
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Export ALL flows as separate Excel files (each with 3 tabs)
            let urls = InteractionLogger.shared.exportAllFlowsAsExcel()
            if !urls.isEmpty {
                DispatchQueue.main.async {
                    isExporting = false
                    exportedURLs = urls
                    print("[ChooseFlowView] Prepared \(urls.count) Excel file(s) for sharing")
                    showShareSheet = true
                }
            } else {
                DispatchQueue.main.async {
                    isExporting = false
                    print("[ChooseFlowView] Excel export failed – no files to share")
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
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ChooseFlowView()
            .environmentObject(AppState())
    }
}
