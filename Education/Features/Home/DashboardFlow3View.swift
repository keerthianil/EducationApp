//
//  DashboardFlow3View.swift
//  Education
//
//  CHANGED: Removed confusing dual navigation (top tabs + bottom tabs).
//  Now uses same Home / All Files top tabs as Flow 2.
//  All original card styling and layout preserved.
//

import SwiftUI
import UIKit

struct DashboardFlow3View: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var mathSpeech: MathSpeechService
    
    // CHANGED: Single tab enum replacing the old dual-tab system
    @State private var selectedTab: SimpleTab = .home
    @State private var selectedLesson: LessonIndexItem?
    @State private var showUpload = false
    @State private var navigateToFlowSelection = false
    @StateObject private var uploadManager = UploadManager()
    @StateObject private var notificationDelegate = NotificationDelegate.shared
    
    @State private var previousProcessingCount = 0
    @State private var previousCompletedCount = 0
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    
    // CHANGED: Simple 2-tab enum (was: separate Flow3Tab + Flow3BottomTab)
    enum SimpleTab: CaseIterable {
        case home, allFiles
        var title: String {
            switch self {
            case .home: return "Home"
            case .allFiles: return "All files"
            }
        }
    }
    
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 32 : 16
    }
    
    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 800 : .infinity
    }
    
    private var teacherFiles: [LessonIndexItem] {
        lessonStore.recent.filter { $0.teacher != nil }
    }
    
    var body: some View {
        // CHANGED: Removed ZStack wrapper and bottom tab bar
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                
                // CHANGED: Same tab style as Flow 2
                tabBar
                    .padding(.bottom, 16)
                
                if selectedTab == .home {
                    homeTabContent
                } else {
                    allFilesContent
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
        .background(Color(hex: "#F7FAFC"))
        // CHANGED: Removed .safeAreaInset that pushed heading down
        .sheet(isPresented: $showUpload) {
            UploadSheetView(uploadManager: uploadManager)
                .environmentObject(lessonStore)
                .environmentObject(haptics)
        }
        .onAppear {
            uploadManager.lessonStore = lessonStore
            previousProcessingCount = lessonStore.processing.count
            previousCompletedCount = lessonStore.downloaded.count
            InteractionLogger.shared.setCurrentScreen("DashboardFlow3View")
            
            if UIAccessibility.isVoiceOverRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UIAccessibility.post(notification: .announcement, argument: "StemAlly Dashboard, Scenario 2")
                }
            }
        }
        .fullScreenCover(item: $selectedLesson) { lesson in
            NavigationStack {
                Flow3ReaderContainer(item: lesson)
                    .environmentObject(lessonStore)
                    .environmentObject(speech)
                    .environmentObject(haptics)
                    .environmentObject(mathSpeech)
            }
        }
        .onChange(of: notificationDelegate.selectedLessonId) { _, newValue in
            if let lessonId = newValue,
               let lesson = lessonStore.recent.first(where: { $0.id == lessonId }) {
                selectedLesson = lesson
                notificationDelegate.selectedLessonId = nil
            }
        }
        .onChange(of: lessonStore.processing.count) { _, newCount in
            previousProcessingCount = newCount
        }
        .onChange(of: lessonStore.downloaded.count) { _, newCount in
            previousCompletedCount = newCount
        }
        .onChange(of: selectedTab) { _, newTab in
            InteractionLogger.shared.log(
                event: .tabChange, objectType: .tab,
                label: newTab.title, location: .zero,
                additionalInfo: "Flow 3 tab changed"
            )
        }
        .onThreeFingerSwipeBack {
            dismiss()
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(
            NavigationLink(destination: ChooseFlowView().navigationBarBackButtonHidden(true), isActive: $navigateToFlowSelection) {
                EmptyView()
            }
            .hidden()
        )
    }
    
    // MARK: - Top Bar (original style)
    private var topBar: some View {
        HStack {
            Button {
                haptics.tapSelection()
                InteractionLogger.shared.log(event: .tap, objectType: .button, label: "Back to Flows", location: .zero)
                InteractionLogger.shared.endSession()
                navigateToFlowSelection = true
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ColorTokens.primary)
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Back to flow selection")
            
            Spacer()
            
            Spacer().frame(width: 48)
        }
        .overlay(
            Text("StemAlly")
                .font(.custom("Arial", size: 18).weight(.bold))
                .foregroundColor(Color(hex: "#0D141C"))
                .accessibilityAddTraits(.isHeader),
            alignment: .center
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Tab Bar (CHANGED: replaces old dual-tab system)
    private var tabBar: some View {
        let allTabs = SimpleTab.allCases
        let tabCount = allTabs.count
        
        return HStack(spacing: 0) {
            ForEach(Array(allTabs.enumerated()), id: \.element) { index, tab in
                let isSelected = (selectedTab == tab)
                
                Button {
                    haptics.tapSelection()
                    InteractionLogger.shared.logTap(objectType: .tab, label: "Tab: \(tab.title)")
                    selectedTab = tab
                } label: {
                    VStack(spacing: 0) {
                        Text(tab.title)
                            .font(.custom("Arial", size: 15).weight(.bold))
                            .foregroundColor(isSelected ? ColorTokens.primary : Color(hex: "#8B919C"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.top, 16)
                            .padding(.bottom, 13)
                        
                        Rectangle()
                            .fill(isSelected ? ColorTokens.primary : Color(hex: "#E5E8EB"))
                            .frame(height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tab.title)
                .accessibilityValue(isSelected ? "selected" : "")
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
                .accessibilityHint("Tab \(index + 1) of \(tabCount)")
            }
        }
        .padding(.horizontal, 8)
        .background(Color.white)
        .overlay(
            Rectangle().fill(Color(hex: "#CFDBE8")).frame(height: 1),
            alignment: .bottom
        )
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Home Tab Content (original layout — upload + teacher + recent)
    private var homeTabContent: some View {
        VStack(spacing: 16) {
            // Upload section (original Flow 3 style)
            Text("Upload from Device")
                .font(.custom("Arial", size: 18).weight(.bold))
                .foregroundColor(Color(hex: "#0D141C"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 10) {
                VStack(spacing: 8) {
                    Text("Upload your files")
                        .font(.custom("Arial", size: 18).weight(.bold))
                        .foregroundColor(Color(hex: "#0D141C"))
                    
                    Text("Or")
                        .font(.custom("Arial", size: 14))
                        .foregroundColor(Color(hex: "#0D141C"))
                    
                    Button("Browse Files") {
                        haptics.tapSelection()
                        InteractionLogger.shared.logTap(objectType: .button, label: "Browse Files")
                        showUpload = true
                    }
                    .font(.custom("Arial", size: 14).weight(.bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 210, height: 48)
                    .background(ColorTokens.primary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(true)
                    .accessibilityLabel("Browse Files")
                    .accessibilityHint("Currently disabled")
                }
                .frame(maxWidth: 480)
                .padding(.vertical, 56)
                .padding(.horizontal, 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#ACD7DF"), style: StrokeStyle(lineWidth: 2, dash: [5]))
                )
            }
            .padding(16)
            
            // Processing files
            if !lessonStore.processing.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lessonStore.processing) { file in
                        Flow3ProcessingCard(processingFile: file)
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
            
            // Uploaded files
            if !lessonStore.downloaded.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Uploaded")
                        .font(.custom("Arial", size: 18).weight(.bold))
                        .foregroundColor(Color(hex: "#0D141C"))
                        .padding(.horizontal, horizontalPadding)
                        .accessibilityAddTraits(.isHeader)
                    
                    ForEach(lessonStore.downloaded.prefix(3)) { item in
                        Flow3UploadedCard(item: item) {
                            haptics.tapSelection()
                            InteractionLogger.shared.logTap(objectType: .fileCard, label: "Uploaded: \(item.title)")
                            selectedLesson = item
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                }
            }
            
            // Teacher files (original grid style)
            uploadedByTeacherSection
            
            // Recent upload history
            recentUploadHistorySection
        }
    }
    
    // MARK: - Uploaded by Teacher (original grid layout)
    @ViewBuilder
    private var uploadedByTeacherSection: some View {
        if !teacherFiles.isEmpty {
            VStack(spacing: 16) {
                Text("Uploaded by Teacher")
                    .font(.custom("Arial", size: 18).weight(.bold))
                    .foregroundColor(Color(hex: "#0D141C"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(teacherFiles) { item in
                        Flow3TeacherFileCard(item: item) {
                            haptics.tapSelection()
                            InteractionLogger.shared.logTap(objectType: .card, label: "Teacher: \(item.title)")
                            selectedLesson = item
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
        }
    }
    
    // MARK: - Recent Upload History (original style)
    private var recentUploadHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Upload History")
                .font(.custom("Arial", size: 18).weight(.bold))
                .foregroundColor(Color(hex: "#0D141C"))
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)
            
            ForEach(lessonStore.recent.prefix(5)) { item in
                Flow3HistoryRow(item: item) {
                    haptics.tapSelection()
                    InteractionLogger.shared.logTap(objectType: .listRow, label: "History: \(item.title)")
                    selectedLesson = item
                }
                .padding(.horizontal, horizontalPadding)
            }
        }
    }
    
    // MARK: - All Files (CHANGED: now in tab instead of bottom bar)
    private var allFilesContent: some View {
        let allFilesById = (lessonStore.downloaded + teacherFiles).reduce(into: [String: LessonIndexItem]()) { acc, item in
            acc[item.id] = acc[item.id] ?? item
        }
        let allFiles = allFilesById.values.sorted { $0.createdAt > $1.createdAt }

        return VStack(alignment: .leading, spacing: 12) {
            Text("All Files")
                .font(.custom("Arial", size: 18).weight(.bold))
                .foregroundColor(Color(hex: "#0D141C"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)

            if allFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "#989CA6"))
                        .accessibilityHidden(true)
                    Text("No files yet")
                        .font(.custom("Arial", size: 17))
                        .foregroundColor(Color(hex: "#61758A"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                VStack(spacing: 8) {
                    ForEach(allFiles) { item in
                        Flow3UploadedCard(item: item) {
                            haptics.tapSelection()
                            InteractionLogger.shared.logTap(objectType: .fileCard, label: "All Files: \(item.title)")
                            selectedLesson = item
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Original Flow 3 Card Components (unchanged)

private struct Flow3TeacherFileCard: View {
    let item: LessonIndexItem
    let onTap: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var cardHeight: CGFloat {
        horizontalSizeClass == .regular ? 220 : 200
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#DEECF8"))
                        .frame(height: cardHeight - 80)
                    
                    VStack(spacing: 8) {
                        Image("pdf-icon-blue")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                        
                        Text("PDF")
                            .font(.custom("Arial", size: 12).weight(.medium))
                            .foregroundColor(Color(hex: "#61758A"))
                    }
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.custom("Inter", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "#0D141C"))
                        .lineLimit(2)
                    
                    if let teacher = item.teacher {
                        Text("Uploaded by \(teacher)")
                            .font(.custom("Inter", size: 13))
                            .foregroundColor(Color(hex: "#4D7399"))
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), uploaded by \(item.teacher ?? "teacher")")
        .accessibilityHint("Double tap to open")
        .accessibilityAddTraits(.isButton)
    }
}

private struct Flow3ProcessingCard: View {
    let processingFile: ProcessingFile
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#FEDFDE"))
                    .frame(width: 48, height: 48)
                Image("pdf-icon-red").resizable().scaledToFit().frame(width: 24, height: 24)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Processing...")
                    .font(.custom("Arial", size: 13)).foregroundColor(Color(hex: "#8B919C"))
                Text(processingFile.item.title)
                    .font(.custom("Arial", size: 16)).foregroundColor(Color(hex: "#0D141C"))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color(hex: "#E5E8EB")).frame(height: 4)
                        Rectangle().fill(ColorTokens.primary)
                            .frame(width: geo.size.width * processingFile.progress, height: 4)
                    }.cornerRadius(2)
                }.frame(height: 4)
                Text("\(Int(processingFile.progress * 100))% Complete")
                    .font(.custom("Arial", size: 11)).foregroundColor(Color(hex: "#8B919C"))
            }
            Spacer()
            ProgressView().scaleEffect(0.8).accessibilityHidden(true)
        }
        .padding(12).background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing \(processingFile.item.title), \(Int(processingFile.progress * 100)) percent")
    }
}

private struct Flow3UploadedCard: View {
    let item: LessonIndexItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#FEDFDE")).frame(width: 48, height: 48)
                    Image("pdf-icon-red").resizable().scaledToFit().frame(width: 24, height: 24)
                }.accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.custom("Arial", size: 16)).foregroundColor(Color(hex: "#0D141C"))
                    Text(formatMeta(item)).font(.custom("Arial", size: 13)).foregroundColor(Color(hex: "#8B919C"))
                }
                Spacer()
                Image("tick-mark").resizable().scaledToFit().frame(width: 24, height: 24).accessibilityHidden(true)
            }
            .padding(12).background(ColorTokens.uploadedFileCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), completed")
        .accessibilityHint("Double tap to open")
        .accessibilityAddTraits(.isButton)
    }
    
    private func formatMeta(_ item: LessonIndexItem) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "\(formatter.localizedString(for: item.createdAt, relativeTo: Date())), 1.5MB"
    }
}

private struct Flow3HistoryRow: View {
    let item: LessonIndexItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#FEDFDE")).frame(width: 48, height: 48)
                    Image("pdf-icon-red").resizable().scaledToFit().frame(width: 24, height: 24)
                }.accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Inter", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "#0D141C"))
                    let f = DateFormatter()
                    let _ = f.dateFormat = "yyyy-MM-dd"
                    Text(f.string(from: item.createdAt))
                        .font(.custom("Inter", size: 14))
                        .foregroundColor(Color(hex: "#4D7399"))
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(height: 72)
            .background(Color(hex: "#F7FAFC"))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityHint("Double tap to open")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Reader Container (unchanged)
private struct Flow3ReaderContainer: View {
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @Environment(\.dismiss) private var dismiss
    let item: LessonIndexItem
    
    var body: some View {
        let pages = WorksheetLoader.loadPages(lessonStore: lessonStore, filenames: item.localFiles)
        
        Group {
            if !pages.isEmpty {
                WorksheetView(title: item.title, pages: pages)
                    .environmentObject(speech)
                    .environmentObject(haptics)
                    .environmentObject(mathSpeech)
            } else {
                DocumentRendererView(title: item.title, nodes: lessonStore.loadNodes(forFilenames: item.localFiles))
                    .environmentObject(speech)
                    .environmentObject(haptics)
                    .environmentObject(mathSpeech)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
