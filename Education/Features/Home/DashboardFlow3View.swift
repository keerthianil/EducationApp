//
//  DashboardFlow3View.swift
//  Education
//
//

import SwiftUI
import UIKit

struct DashboardFlow3View: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var mathSpeech: MathSpeechService
    
    @State private var selectedTab: Flow3Tab = .upload
    @State private var selectedBottomTab: Flow3BottomTab = .home
    @State private var showHamburgerMenu = false
    @State private var selectedLesson: LessonIndexItem?
    @State private var showUpload = false
    @StateObject private var uploadManager = UploadManager()
    @StateObject private var notificationDelegate = NotificationDelegate.shared
    
    @State private var previousProcessingCount = 0
    @State private var previousCompletedCount = 0
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    enum Flow3Tab: String, CaseIterable {
        case upload = "Upload"
        case uploadedByTeacher = "Uploaded by Teacher"
        
        static var allCases: [Flow3Tab] {
            return [.upload, .uploadedByTeacher]
        }
    }
    
    enum Flow3BottomTab: CaseIterable {
        case home, allFiles
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .allFiles: return "All files"
            }
        }
        
        var icon: String {
            switch self {
            case .home: return "house"
            case .allFiles: return "doc.on.doc"
            }
        }
    }
    
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 32 : 16
    }
    
    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 800 : .infinity
    }
    
    // Get teacher-uploaded files
    private var teacherFiles: [LessonIndexItem] {
        lessonStore.recent.filter { $0.teacher != nil }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                tabBar
                
                ScrollView {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .upload:
                            uploadTabContent
                        case .uploadedByTeacher:
                            uploadedByTeacherTabContent
                        }
                    }
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 100)
                }
                .background(Color(hex: "#F7FAFC"))
                
                Spacer(minLength: 0)
                
                bottomTabBar
            }
            
            // Hamburger menu - temporarily disabled for user testing
            /*
            if showHamburgerMenu {
                HamburgerMenuView(isShowing: $showHamburgerMenu)
                    .environmentObject(haptics)
                    .transition(.move(edge: .trailing))
                    .zIndex(100)
            }
            */
        }
        .onAppear {
            uploadManager.lessonStore = lessonStore
            previousProcessingCount = lessonStore.processing.count
            previousCompletedCount = lessonStore.downloaded.count
        }
        .sheet(isPresented: $showUpload) {
            UploadSheetView(uploadManager: uploadManager)
                .environmentObject(lessonStore)
                .environmentObject(haptics)
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
        .toolbar(.hidden, for: .navigationBar)
    }
    
    // MARK: - Top Bar (Removed back button - this is dashboard screen)
    private var topBar: some View {
        HStack {
            // Back button removed - dashboard is the main screen
            Spacer()
                .frame(width: 48)
            
            Spacer()
            
            // Hamburger menu - temporarily hidden for user testing
            /*
            Button {
                haptics.tapSelection()
                withAnimation(.easeInOut(duration: 0.3)) {
                    showHamburgerMenu = true
                }
            } label: {
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(hex: "#121417"))
                            .frame(width: 18, height: 2)
                    }
                }
                .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Menu")
            */
            
            Spacer()
                .frame(width: 48)
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
        .background(Color(hex: "#F7FAFC"))
    }
    
    // MARK: - Tab Bar (VoiceOver: Label → Value → Traits → Hint)
    private var tabBar: some View {
        let allTabs = Flow3Tab.allCases
        let tabCount = allTabs.count
        
        return HStack(spacing: 0) {
            ForEach(Array(allTabs.enumerated()), id: \.element) { index, tab in
                let isSelected = (selectedTab == tab)
                
                Button {
                    haptics.tapSelection()
                    selectedTab = tab
                } label: {
                    VStack(spacing: 0) {
                        Text(tab.rawValue)
                            .font(.custom("Arial", size: tab == .uploadedByTeacher ? 13 : 15).weight(.bold))
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
                // VoiceOver announces: Label → Value → Traits → Hint
                // Result: "Upload, selected, button, Tab 1 of 2"
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tab.rawValue)
                .accessibilityValue(isSelected ? "selected" : "")
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
                .accessibilityHint("Tab \(index + 1) of \(tabCount)")
            }
        }
        .padding(.horizontal, 8)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "#CFDBE8"))
                .frame(height: 1),
            alignment: .bottom
        )
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Upload Tab Content (Changed "Drag and drop" to "Upload your files")
    private var uploadTabContent: some View {
        VStack(spacing: 16) {
            Text("Upload from Device")
                .font(.custom("Arial", size: 18).weight(.bold))
                .foregroundColor(Color(hex: "#0D141C"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 10) {
                VStack(spacing: 8) {
                    // Changed from "Drag and drop files here" to "Upload your files"
                    Text("Upload your files")
                        .font(.custom("Arial", size: 18).weight(.bold))
                        .foregroundColor(Color(hex: "#0D141C"))
                    
                    Text("Or")
                        .font(.custom("Arial", size: 14))
                        .foregroundColor(Color(hex: "#0D141C"))
                    
                    Button("Browse Files") {
                        haptics.tapSelection()
                        showUpload = true
                    }
                    .font(.custom("Arial", size: 14).weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 210, height: 48)
                    .background(ColorTokens.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Browse Files")
                }
                .frame(maxWidth: 480)
                .padding(.vertical, 56)
                .padding(.horizontal, 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#ACD7DF"), style: StrokeStyle(lineWidth: 2, dash: [5]))
                )
                
                // "Upload from Cloud" text and cloud buttons - temporarily commented out for user testing
                /*
                Text("Upload from Cloud")
                    .font(.custom("Arial", size: 16).weight(.medium))
                    .foregroundColor(Color(hex: "#6F6F6F"))
                    .padding(.top, 8)
                    .accessibilityHidden(true)
                
                HStack(spacing: 12) {
                    Button { } label: {
                        HStack(spacing: 4) {
                            Image("GoogleDrive")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            
                            Text("Google Drive")
                                .font(.custom("Arial", size: 14).weight(.bold))
                                .foregroundColor(Color(hex: "#0D141C"))
                        }
                        .frame(width: 149, height: 48)
                        .background(Color(hex: "#E8EDF2"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Button { } label: {
                        HStack(spacing: 4) {
                            Image("Dropbox")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            
                            Text("Dropbox")
                                .font(.custom("Arial", size: 14).weight(.bold))
                                .foregroundColor(Color(hex: "#0D141C"))
                        }
                        .frame(width: 149, height: 48)
                        .background(Color(hex: "#E8EDF2"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .accessibilityHidden(true)
                */
            }
            .padding(16)
            
            if !lessonStore.processing.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(lessonStore.processing) { file in
                        Flow3ProcessingCard(processingFile: file)
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
            
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
                            selectedLesson = item
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                }
            }
            
            recentUploadHistorySection
        }
    }
    
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
                    selectedLesson = item
                }
                .padding(.horizontal, horizontalPadding)
            }
        }
    }
    
    // MARK: - Uploaded by Teacher Tab (UPDATED: Shows actual teacher files as cards)
    private var uploadedByTeacherTabContent: some View {
        VStack(spacing: 16) {
            // Filter chips - temporarily commented out for user testing
            /*
            HStack(spacing: 12) {
                filterChip(title: "Subject")
                filterChip(title: "Date")
                filterChip(title: "Teacher")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            */
            
            if teacherFiles.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "#989CA6"))
                        .accessibilityHidden(true)
                    
                    Text("No files from teacher yet")
                        .font(.custom("Arial", size: 17))
                        .foregroundColor(Color(hex: "#61758A"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Teacher file cards - similar to Flow 1/2
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(teacherFiles) { item in
                        Flow3TeacherFileCard(item: item) {
                            haptics.tapSelection()
                            selectedLesson = item
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 16)
            }
        }
    }
    
    // Filter chip - temporarily commented out for user testing
    /*
    private func filterChip(title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.custom("Inter", size: 14).weight(.medium))
                .foregroundColor(Color(hex: "#0D141C"))
            
            Image(systemName: "chevron.down")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#0D141C"))
        }
        .frame(width: 114, height: 40)
        .background(Color(hex: "#E8EDF2"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("\(title) filter")
    }
    */
    
    // MARK: - Bottom Tab Bar (VoiceOver: Label → Value → Traits → Hint)
    private var bottomTabBar: some View {
        let allTabs = Flow3BottomTab.allCases
        let tabCount = allTabs.count
        
        return HStack(spacing: 0) {
            ForEach(Array(allTabs.enumerated()), id: \.element) { index, tab in
                let isSelected = (selectedBottomTab == tab)
                
                Button {
                    haptics.tapSelection()
                    selectedBottomTab = tab
                    if tab == .home {
                        selectedTab = .upload
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isSelected ? "\(tab.icon).fill" : tab.icon)
                            .font(.system(size: 24))
                            .foregroundColor(isSelected ? ColorTokens.primary : Color(hex: "#61758A"))
                        
                        Text(tab.title)
                            .font(.custom("Arial", size: 12))
                            .foregroundColor(isSelected ? ColorTokens.primary : Color(hex: "#61758A"))
                    }
                    .frame(maxWidth: .infinity)
                }
                // VoiceOver announces: Label → Value → Traits → Hint
                // Result: "Home, selected, button, Tab 1 of 2"
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tab.title)
                .accessibilityValue(isSelected ? "selected" : "")
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
                .accessibilityHint("Tab \(index + 1) of \(tabCount)")
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "#E5E8EB"))
                .frame(height: 1),
            alignment: .top
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Flow 3 Teacher File Card (NEW - replaces subject cards)
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
                // File preview/thumbnail area
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
                
                // File info
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

// MARK: - Flow 3 Processing Card
private struct Flow3ProcessingCard: View {
    let processingFile: ProcessingFile
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#FEDFDE"))
                    .frame(width: 48, height: 48)
                
                Image("pdf-icon-red")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Processing...")
                    .font(.custom("Arial", size: 13))
                    .foregroundColor(Color(hex: "#8B919C"))
                
                Text(processingFile.item.title)
                    .font(.custom("Arial", size: 16))
                    .foregroundColor(Color(hex: "#0D141C"))
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color(hex: "#E5E8EB")).frame(height: 4)
                        Rectangle().fill(ColorTokens.primary)
                            .frame(width: geo.size.width * processingFile.progress, height: 4)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 4)
                
                Text("\(Int(processingFile.progress * 100))% Complete")
                    .font(.custom("Arial", size: 11))
                    .foregroundColor(Color(hex: "#8B919C"))
            }
            
            Spacer()
            
            ProgressView().scaleEffect(0.8).accessibilityHidden(true)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing \(processingFile.item.title), \(Int(processingFile.progress * 100)) percent")
    }
}

// MARK: - Flow 3 Uploaded Card
private struct Flow3UploadedCard: View {
    let item: LessonIndexItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#FEDFDE"))
                        .frame(width: 48, height: 48)
                    
                    Image("pdf-icon-red")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Arial", size: 16))
                        .foregroundColor(Color(hex: "#0D141C"))
                    
                    Text(formatMeta(item))
                        .font(.custom("Arial", size: 13))
                        .foregroundColor(Color(hex: "#8B919C"))
                }
                
                Spacer()
                
                Image("tick-mark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(ColorTokens.uploadedFileCardBackground)
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
        let timeAgo = formatter.localizedString(for: item.createdAt, relativeTo: Date())
        return "\(timeAgo), 1.5MB"
    }
}

// MARK: - Flow 3 History Row
private struct Flow3HistoryRow: View {
    let item: LessonIndexItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#FEDFDE"))
                        .frame(width: 48, height: 48)
                    
                    Image("pdf-icon-red")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Inter", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "#0D141C"))
                    
                    Text(formatDate(item.createdAt))
                        .font(.custom("Inter", size: 14))
                        .foregroundColor(Color(hex: "#4D7399"))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(height: 72)
            .background(Color(hex: "#F7FAFC"))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityHint("Double tap to open")
        .accessibilityAddTraits(.isButton)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Reader Container (FIXED: Proper Environment Object Passing + Escape Gesture)
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
        // FIXED: Support escape gesture (two-finger scrub / 3-finger swipe right) to go back
        .accessibilityAction(.escape) {
            speech.stop(immediate: true)
            dismiss()
        }
    }
}
