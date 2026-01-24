//
//  DashboardFlow2View.swift
//  Education
//
//

import SwiftUI
import UIKit

struct DashboardFlow2View: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var mathSpeech: MathSpeechService
    
    @State private var showUpload = false
    @State private var selectedLesson: LessonIndexItem?
    @State private var selectedTab: Flow2Tab = .home
    @StateObject private var notificationDelegate = NotificationDelegate.shared
    @StateObject private var uploadManager = UploadManager()
    
    @State private var previousProcessingCount = 0
    @State private var previousCompletedCount = 0
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    enum Flow2Tab: CaseIterable {
        case home, allFiles
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .allFiles: return "All files"
            }
        }
    }
    
    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 800 : .infinity
    }
    
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 32 : 16
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                flow2Header
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                
                flow2TopTabs
                    .padding(.bottom, 16)
                
                if selectedTab == .home {
                    uploadSection
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 20)
                    
                    processingSection
                        .padding(.bottom, 12)
                    
                    uploadedByTeacherSection
                        .padding(.bottom, 12)
                    
                    recentActivitySection
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 20)
                } else {
                    allFilesSection
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
        .background(Color(hex: "#F6F7F8"))
        .safeAreaInset(edge: .top) {
            Spacer()
                .frame(height: 44)
        }
        .sheet(isPresented: $showUpload) {
            UploadSheetView(uploadManager: uploadManager)
                .environmentObject(lessonStore)
                .environmentObject(haptics)
        }
        .onAppear {
            uploadManager.lessonStore = lessonStore
            previousProcessingCount = lessonStore.processing.count
            previousCompletedCount = lessonStore.downloaded.count
        }
        .fullScreenCover(item: $selectedLesson) { lesson in
            NavigationStack {
                Flow2ReaderContainer(item: lesson)
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
    
    // MARK: - Header
    private var flow2Header: some View {
        HStack {
            Spacer()
            
            // Hamburger menu - temporarily hidden for user testing
            /*
            Button {
                haptics.tapSelection()
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
        }
        .overlay(
            Text("StemAlly")
                .font(.custom("Arial", size: 18).weight(.bold))
                .foregroundColor(Color(hex: "#121417"))
                .accessibilityAddTraits(.isHeader),
            alignment: .center
        )
    }
    
    // MARK: - Top Tabs (FIXED: Proper VoiceOver tab announcement)
    private var flow2TopTabs: some View {
        let allTabs = Flow2Tab.allCases
        let tabCount = allTabs.count
        
        return HStack(spacing: 0) {
            ForEach(Array(allTabs.enumerated()), id: \.element) { index, tab in
                let isSelected = (selectedTab == tab)
                
                Button {
                    haptics.tapSelection()
                    selectedTab = tab
                } label: {
                    VStack(spacing: 0) {
                        Spacer()
                        Text(tab.title)
                            .font(.custom("Arial", size: 15.9).weight(.semibold))
                            .foregroundColor(isSelected ? ColorTokens.primary : Color(hex: "#8B919C"))
                        Spacer()
                        Rectangle()
                            .fill(isSelected ? ColorTokens.primary : Color.clear)
                            .frame(height: 4)
                    }
                    .frame(height: 75)
                }
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.white : Color.clear)
                // FIXED: Proper VoiceOver tab announcement format
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tab.title)
                .accessibilityValue(isSelected ? "selected" : "")
                .accessibilityHint("Tab \(index + 1) of \(tabCount)")
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color(hex: "#F2F3F4"))
                .frame(height: 2),
            alignment: .bottom
        )
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Upload Section
    private var uploadSection: some View {
        VStack(spacing: 18) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 48))
                .foregroundColor(ColorTokens.primary)
                .accessibilityHidden(true)
            
            Text("Upload Your Files")
                .font(.custom("Arial", size: 20.3).weight(.bold))
                .foregroundColor(Color(hex: "#4E5055"))
            
            VStack(spacing: 12) {
                Button("Browse files") {
                    haptics.tapSelection()
                    showUpload = true
                }
                .buttonStyle(PrimaryButtonStyle())
                
                // Scan files button - temporarily commented out for user testing
                /*
                Button("Scan files") {}
                    .buttonStyle(TertiaryButtonStyle(isDisabled: true))
                    .disabled(true)
                    .accessibilityHidden(true)
                */
            }
            
            // "or upload from" text and cloud buttons - temporarily commented out for user testing
            /*
            Text("or upload from")
                .font(.custom("Arial", size: 15.9))
                .foregroundColor(Color(hex: "#989CA6"))
                .accessibilityHidden(true)
            
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image("GoogleDrive")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    
                    Text("Google Drive")
                        .font(.custom("Arial", size: 16.7).weight(.bold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "#FEFEFE"))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#DADDE2"), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                HStack(spacing: 8) {
                    Image("Dropbox")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    
                    Text("Dropbox")
                        .font(.custom("Arial", size: 16.7).weight(.bold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "#FEFEFE"))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#DADDE2"), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityHidden(true)
            */
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 25)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 1, y: 1)
    }
    
    // MARK: - Processing Section
    @ViewBuilder
    private var processingSection: some View {
        if !lessonStore.processing.isEmpty {
            VStack(spacing: 8) {
                ForEach(lessonStore.processing) { file in
                    Flow2ProcessingCard(processingFile: file)
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
    
    // MARK: - Uploaded by Teacher Section
    @ViewBuilder
    private var uploadedByTeacherSection: some View {
        let teacherItems = lessonStore.recent.filter { $0.teacher != nil }
        
        if !teacherItems.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Uploaded by teacher")
                    .font(.custom("Arial", size: 22).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    .accessibilityAddTraits(.isHeader)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(teacherItems) { item in
                            Flow2TeacherCard(item: item) {
                                haptics.tapSelection()
                                selectedLesson = item
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 16)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Uploaded by teacher, \(teacherItems.count) file\(teacherItems.count == 1 ? "" : "s")")
            }
        }
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Recent Activity")
                .font(.custom("Arial", size: 22).weight(.bold))
                .foregroundColor(Color(hex: "#121417"))
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 11) {
                ForEach(lessonStore.recent) { item in
                    Flow2RecentRow(item: item) {
                        haptics.tapSelection()
                        selectedLesson = item
                    }
                }
            }
        }
    }
    
    // MARK: - All Files Section
    private var allFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Files")
                .font(.custom("Arial", size: 22).weight(.bold))
                .foregroundColor(Color(hex: "#121417"))
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)
            
            let allFiles = lessonStore.downloaded.sorted { $0.createdAt > $1.createdAt }
            
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
                .padding(.vertical, 40)
            } else {
                ForEach(allFiles) { item in
                    Flow2FileRow(item: item) {
                        haptics.tapSelection()
                        selectedLesson = item
                    }
                }
            }
        }
    }
}

// MARK: - Flow 2 Processing Card
private struct Flow2ProcessingCard: View {
    let processingFile: ProcessingFile
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#FEDFDE"))
                    .frame(width: 56, height: 56)
                
                Image("pdf-icon-red")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Processing...")
                    .font(.custom("Arial", size: 14))
                    .foregroundColor(Color(hex: "#91949B"))
                
                Text(processingFile.item.title)
                    .font(.custom("Arial", size: 17))
                    .foregroundColor(Color(hex: "#121417"))
                    .lineLimit(1)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color(hex: "#E8F2F2")).frame(height: 4).cornerRadius(2)
                        Rectangle().fill(ColorTokens.primary)
                            .frame(width: geo.size.width * processingFile.progress, height: 4).cornerRadius(2)
                    }
                }
                .frame(height: 4)
                
                Text("\(Int(processingFile.progress * 100))% Complete")
                    .font(.custom("Arial", size: 12))
                    .foregroundColor(Color(hex: "#61758A"))
            }
            
            Spacer()
            
            ProgressView()
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing \(processingFile.item.title), \(Int(processingFile.progress * 100)) percent")
    }
}

// MARK: - Flow 2 Teacher Card
private struct Flow2TeacherCard: View {
    let item: LessonIndexItem
    let onTap: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var cardWidth: CGFloat {
        horizontalSizeClass == .regular ? 180 : 160
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image("worksheet-preview")
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth - 32, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                
                Text(item.title)
                    .font(.custom("Arial", size: 17))
                    .foregroundColor(Color(hex: "#121417"))
                    .lineLimit(1)
                
                if let teacher = item.teacher {
                    Text("Teacher: \(teacher)")
                        .font(.custom("Arial", size: 13))
                        .foregroundColor(Color(hex: "#9FA1A7"))
                }
            }
            .frame(width: cardWidth)
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 1, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), from \(item.teacher ?? "teacher")")
        .accessibilityHint("Double tap to open")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Flow 2 Recent Row
private struct Flow2RecentRow: View {
    let item: LessonIndexItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13.75)
                        .fill(Color(hex: "#DEECF8"))
                        .frame(width: 56, height: 56)
                    
                    Image("pdf-icon-blue")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Arial", size: 18.6))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    Text("Opened \(item.createdAt, style: .relative)")
                        .font(.custom("Arial", size: 13.7))
                        .foregroundColor(Color(hex: "#91949B"))
                }
                
                Spacer()
                
                Image(bookCoverImageName(for: item))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Color(hex: "#FEFEFE"))
            .overlay(RoundedRectangle(cornerRadius: 21).stroke(Color(hex: "#F3F3F4"), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 21))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityHint("Double tap to open")
        .accessibilityAddTraits(.isButton)
    }
    
    private func bookCoverImageName(for item: LessonIndexItem) -> String {
        let title = item.title.lowercased()
        if title.contains("compound") || title.contains("figures") || title.contains("geometry") {
            return "book-cover-geometry"
        } else {
            return "book-cover-algebra"
        }
    }
}

// MARK: - Flow 2 File Row
private struct Flow2FileRow: View {
    let item: LessonIndexItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#FEDFDE"))
                        .frame(width: 40, height: 40)
                    
                    Image("pdf-icon-red")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Arial", size: 17))
                        .foregroundColor(Color(hex: "#121417"))
                        .lineLimit(1)
                    
                    Text(formatDate(item.createdAt))
                        .font(.custom("Arial", size: 13.5))
                        .foregroundColor(Color(hex: "#91949B"))
                }
                
                Spacer()
                
                Image("tick-mark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(ColorTokens.uploadedFileCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), completed")
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
private struct Flow2ReaderContainer: View {
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
