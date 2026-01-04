//
//  DashboardFlow3View.swift
//  Education
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
        case recent = "Recent"
    }
    
    enum Flow3BottomTab { case home, files }
    
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 32 : 16
    }
    
    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 800 : .infinity
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
                        case .recent:
                            recentTabContent
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
            
            if showHamburgerMenu {
                HamburgerMenuView(isShowing: $showHamburgerMenu)
                    .environmentObject(haptics)
                    .transition(.move(edge: .trailing))
                    .zIndex(100)
            }
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
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button {
                haptics.tapSelection()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "#0D141C"))
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Back")
            
            Spacer()
            
            Text("Dashboard")
                .font(.custom("Arial", size: 18).weight(.bold))
                .foregroundColor(Color(hex: "#0D141C"))
            
            Spacer()
            
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(Color(hex: "#F7FAFC"))
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Flow3Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 0) {
                        Text(tab.rawValue)
                            .font(.custom("Arial", size: tab == .uploadedByTeacher ? 13 : 15).weight(.bold))
                            .foregroundColor(selectedTab == tab ? ColorTokens.primary : Color(hex: "#8B919C"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.top, 16)
                            .padding(.bottom, 13)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? ColorTokens.primary : Color(hex: "#E5E8EB"))
                            .frame(height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
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
    }
    
    // MARK: - Upload Tab Content
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
                    Text("Drag and drop files here")
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
                
                // "Upload from Cloud" and cloud buttons - hidden from VoiceOver
                Text("Upload from Cloud")
                    .font(.custom("Arial", size: 16).weight(.medium))
                    .foregroundColor(Color(hex: "#6F6F6F"))
                    .padding(.top, 8)
                    .accessibilityHidden(true)
                
                HStack(spacing: 12) {
                    // Google Drive - using asset
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
                    
                    // Dropbox - using asset
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
    
    // MARK: - Uploaded by Teacher Tab (Using subject assets)
    private var uploadedByTeacherTabContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                filterChip(title: "Subject")
                filterChip(title: "Date")
                filterChip(title: "Teacher")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                subjectCard(title: "Maths", teacher: "Ms. Rivera", imageName: "subject-maths", sampleId: "sample1")
                subjectCard(title: "Physics", teacher: "Ms. Rivera", imageName: "subject-physics", sampleId: "sample2")
                subjectCard(title: "Chemistry", teacher: "Ms. Rivera", imageName: "subject-chemistry", sampleId: "sample3")
                subjectCard(title: "Biology", teacher: "Ms. Rivera", imageName: "subject-biology", sampleId: "sample1")
                subjectCard(title: "History", teacher: "Ms. Rivera", imageName: "subject-history", sampleId: "sample2")
                subjectCard(title: "Geography", teacher: "Ms. Rivera", imageName: "subject-geography", sampleId: "sample3")
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
    
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
    
    private func subjectCard(title: String, teacher: String, imageName: String, sampleId: String) -> some View {
        Button {
            if let item = lessonStore.recent.first(where: { $0.id.contains(sampleId) }) ?? lessonStore.recent.first {
                haptics.tapSelection()
                selectedLesson = item
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Subject image from assets
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 173)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(title)
                    .font(.custom("Inter", size: 16).weight(.medium))
                    .foregroundColor(Color(hex: "#0D141C"))
                
                Text("Uploaded by \(teacher)")
                    .font(.custom("Inter", size: 14))
                    .foregroundColor(Color(hex: "#4D7399"))
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), uploaded by \(teacher)")
        .accessibilityHint("Double tap to open")
    }
    
    // MARK: - Recent Tab
    private var recentTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            recentSection(title: "Today", items: recentItemsForPeriod(.today))
            recentSection(title: "Last 3 Days", items: recentItemsForPeriod(.last3Days))
            recentSection(title: "Earlier", items: recentItemsForPeriod(.earlier))
        }
        .padding(.top, 16)
    }
    
    @ViewBuilder
    private func recentSection(title: String, items: [LessonIndexItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.custom("Inter", size: 18).weight(.bold))
                    .foregroundColor(Color(hex: "#0D141C"))
                    .padding(.horizontal, horizontalPadding)
                    .accessibilityAddTraits(.isHeader)
                
                ForEach(items) { item in
                    Flow3RecentFileRow(item: item) {
                        haptics.tapSelection()
                        selectedLesson = item
                    }
                    .padding(.horizontal, horizontalPadding)
                }
            }
        }
    }
    
    private enum TimePeriod { case today, last3Days, earlier }
    
    private func recentItemsForPeriod(_ period: TimePeriod) -> [LessonIndexItem] {
        let now = Date()
        let calendar = Calendar.current
        
        return lessonStore.recent.filter { item in
            let daysDiff = calendar.dateComponents([.day], from: item.createdAt, to: now).day ?? 0
            switch period {
            case .today: return daysDiff == 0
            case .last3Days: return daysDiff > 0 && daysDiff <= 3
            case .earlier: return daysDiff > 3
            }
        }
    }
    
    // MARK: - Bottom Tab Bar
    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            bottomTabButton(tab: .home, icon: "house", title: "Home")
            bottomTabButton(tab: .files, icon: "doc.on.doc", title: "Files")
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
    }
    
    private func bottomTabButton(tab: Flow3BottomTab, icon: String, title: String) -> some View {
        Button {
            selectedBottomTab = tab
            if tab == .home {
                selectedTab = .upload
            } else {
                selectedTab = .recent
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selectedBottomTab == tab ? "\(icon).fill" : icon)
                    .font(.system(size: 24))
                    .foregroundColor(selectedBottomTab == tab ? ColorTokens.primary : Color(hex: "#61758A"))
                
                Text(title)
                    .font(.custom("Arial", size: 12))
                    .foregroundColor(selectedBottomTab == tab ? ColorTokens.primary : Color(hex: "#61758A"))
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(selectedBottomTab == tab ? .isSelected : [])
    }
}

// MARK: - Flow 3 Processing Card (Using pdf-icon-red)
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

// MARK: - Flow 3 Uploaded Card (Using pdf-icon-red and tick-mark)
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
                
                // Tick mark from assets
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
    }
    
    private func formatMeta(_ item: LessonIndexItem) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let timeAgo = formatter.localizedString(for: item.createdAt, relativeTo: Date())
        return "\(timeAgo), 1.5MB"
    }
}

// MARK: - Flow 3 History Row (Using pdf-icon-red)
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
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Flow 3 Recent File Row (Using pdf-icon-red)
private struct Flow3RecentFileRow: View {
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
                        .lineLimit(1)
                    
                    Text(formatTimeAndSize(item))
                        .font(.custom("Inter", size: 14))
                        .foregroundColor(Color(hex: "#4D7399"))
                }
                
                Spacer()
            }
            .padding(16)
            .frame(height: 72)
            .background(Color(hex: "#F7FAFC"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityHint("Double tap to open")
    }
    
    private func formatTimeAndSize(_ item: LessonIndexItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let time = formatter.string(from: item.createdAt)
        return "\(time), \(item.localFiles.count * 150)KB"
    }
}

// MARK: - Reader Container
private struct Flow3ReaderContainer: View {
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var speech: SpeechService
    @Environment(\.dismiss) private var dismiss
    let item: LessonIndexItem
    
    var body: some View {
        let pages = WorksheetLoader.loadPages(lessonStore: lessonStore, filenames: item.localFiles)
        
        Group {
            if !pages.isEmpty {
                WorksheetView(title: item.title, pages: pages)
            } else {
                DocumentRendererView(title: item.title, nodes: lessonStore.loadNodes(forFilenames: item.localFiles))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    speech.stop(immediate: true)
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                }
                .accessibilityLabel("Back")
            }
        }
    }
}
