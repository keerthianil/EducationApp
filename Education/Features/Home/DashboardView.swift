//
//  DashboardView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var mathSpeech: MathSpeechService

    @State private var showUpload = false
    @State private var selectedLesson: LessonIndexItem?
    @State private var selectedTab: HomeTab = .home
    @StateObject private var notificationDelegate = NotificationDelegate.shared
    @StateObject private var uploadManager = UploadManager()

    enum HomeTab {
        case accessibility, home, allFiles
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection()
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    
                    if selectedTab == .home {
                        bannerSection()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        
                        uploadSection()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        
                        uploadedSection()
                            .padding(.bottom, 12)
                        
                        uploadedByTeacherSection()
                            .padding(.bottom, 12)
                        
                        recentsSection()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    } else if selectedTab == .allFiles {
                        allFilesSection()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    }
                }
                .padding(.bottom, 95) // Space for tab bar (95px per Figma)
            }
            .background(Color(hex: "#F6F7F8"))

            HomeTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showUpload) {
            UploadSheetView(uploadManager: uploadManager)
                .environmentObject(lessonStore)
                .environmentObject(haptics)
        }
        .onAppear {
            // Connect uploadManager to lessonStore
            uploadManager.lessonStore = lessonStore
        }
        .fullScreenCover(item: $selectedLesson) { lesson in
            NavigationStack {
                ReaderContainer(item: lesson)
            }
        }
        .onChange(of: notificationDelegate.selectedLessonId) { oldLessonId, newLessonId in
            // Handle notification tap - open the lesson
            if let lessonId = newLessonId,
               let lesson = lessonStore.recent.first(where: { $0.id == lessonId }) {
                selectedLesson = lesson
                notificationDelegate.selectedLessonId = nil // Reset
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header Section (Top Bar per Figma)
    private func headerSection() -> some View {
        HStack {
            Text("Logo")
                .font(.custom("Arial", size: 22.3))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#47494F"))

            Spacer()

            // Vertical three dots menu in circle
            Button {
                haptics.tapSelection()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#47494F"))
                    .rotationEffect(.degrees(90)) // Makes it vertical
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color(hex: "#F5F5F5"))
                    )
            }
            .accessibilityLabel("More options")
        }
    }

    // MARK: - Banner Section
    @ViewBuilder
    private func bannerSection() -> some View {
        if let item = (lessonStore.banner ?? lessonStore.recent.first) {
            NotificationBannerView(
                title: bannerTitle(for: item),
                subtitle: item.title
            ) {
                haptics.success()
                selectedLesson = item
            }
        }
    }

    // MARK: - Upload Section (Per Figma specs)
    private func uploadSection() -> some View {
        VStack(spacing: 18) {
            // Upload icon - larger, centered, correct tone
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 48, weight: .regular))
                .foregroundColor(ColorTokens.primary)

            VStack(spacing: 4) {
                Text("Upload Your Files")
                    .font(.custom("Arial", size: 20.3))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#4E5055"))

                // Subhead per Figma - "Browse files or scan"
                Text("Browse files or scan")
                    .font(.custom("Arial", size: 15.9))
                    .foregroundColor(Color(hex: "#989CA6"))
            }

            VStack(spacing: 12) {
                // Primary Button - Browse files
                Button("Browse files") {
                    haptics.tapSelection()
                    showUpload = true
                }
                .buttonStyle(PrimaryButtonStyle())

                // Secondary Button - Scan files (per Figma: lighter bg, border)
                Button("Scan files") {
                    // not implemented in demo
                }
                .buttonStyle(TertiaryButtonStyle())
                .disabled(true)
                .accessibilityHint("Not available in this demo")
            }

            Text("or upload from")
                .font(.custom("Arial", size: 15.9))
                .foregroundColor(Color(hex: "#989CA6"))

            // Google Drive & Dropbox chips - HIDDEN from VoiceOver
            HStack(spacing: 8) {
                // Google Drive chip
                HStack(spacing: 8) {
                    Image("GoogleDrive")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)

                    Text("Google Drive")
                        .font(.custom("Arial", size: 16.7))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "#FEFEFE"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true) // Hidden from VoiceOver

                // Dropbox chip
                HStack(spacing: 8) {
                    Image("Dropbox")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)

                    Text("Dropbox")
                        .font(.custom("Arial", size: 16.7))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "#FEFEFE"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true) // Hidden from VoiceOver
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 25)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 1, y: 1)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Uploaded Section (Processing/Recently Completed files)
    @ViewBuilder
    private func uploadedSection() -> some View {
        let processingFiles = lessonStore.processing
        // Only show files completed in the last 24 hours in "Uploaded" section
        let recentCompletedFiles = lessonStore.downloaded.filter { item in
            !processingFiles.contains { $0.item.id == item.id } &&
            item.createdAt > Date().addingTimeInterval(-24 * 60 * 60) // Last 24 hours
        }
        
        if !processingFiles.isEmpty || !recentCompletedFiles.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Uploaded")
                    .font(.custom("Arial", size: 22))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#121417"))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                
                VStack(spacing: 8) {
                    // Processing files (with progress bar)
                    ForEach(processingFiles) { processingFile in
                        ProcessingFileCard(processingFile: processingFile)
                    }
                    
                    // Recently completed files (with checkmark)
                    ForEach(recentCompletedFiles) { item in
                        CompletedFileCard(item: item) {
                            haptics.tapSelection()
                            selectedLesson = item
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - All Files Section
    @ViewBuilder
    private func allFilesSection() -> some View {
        let allUploadedFiles = lessonStore.downloaded.sorted { $0.createdAt > $1.createdAt }
        
        VStack(alignment: .leading, spacing: 0) {
            Text("All Files")
                .font(.custom("Arial", size: 22))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#121417"))
                .padding(.top, 20)
                .padding(.bottom, 12)
            
            if allUploadedFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "#989CA6"))
                    
                    Text("No files yet")
                        .font(.custom("Arial", size: 17))
                        .foregroundColor(Color(hex: "#61758A"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(allUploadedFiles) { item in
                        CompletedFileCard(item: item) {
                            haptics.tapSelection()
                            selectedLesson = item
                        }
                    }
                }
            }
        }
    }

    // MARK: - Uploaded by Teacher Section
    @ViewBuilder
    private func uploadedByTeacherSection() -> some View {
        let teacherItems = teacherLessons

        if !teacherItems.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Uploaded by Teacher")
                    .font(.custom("Arial", size: 22))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#121417"))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(teacherItems) { item in
                            TeacherLessonCard(item: item) {
                                haptics.tapSelection()
                                selectedLesson = item
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
        }
    }

    private var teacherLessons: [LessonIndexItem] {
        lessonStore.recent.filter { $0.teacher != nil }
    }

    // MARK: - Recents Section
    private func recentsSection() -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Recent Activity")
                .font(.custom("Arial", size: 22))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#121417"))
                .padding(.top, 20)

            VStack(spacing: 11) {
                ForEach(lessonStore.recent) { item in
                    Button {
                        haptics.tapSelection()
                        selectedLesson = item
                    } label: {
                        RecentRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func bannerTitle(for item: LessonIndexItem) -> String {
        if let t = item.teacher, !t.isEmpty {
            return "New document from \(t)"
        } else {
            return "Your converted file is ready"
        }
    }
}

// MARK: - Tertiary Button Style (for Scan files)
public struct TertiaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Arial", size: 17).weight(.bold))
            .foregroundColor(ColorTokens.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .accessibilityAddTraits(.isButton)
            .contentShape(Rectangle())
    }
}

// MARK: - Teacher lesson card (Updated per Figma)
private struct TeacherLessonCard: View {
    let item: LessonIndexItem
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Document icon with rounded soft style
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ColorTokens.secondaryPurple)
                    .frame(width: 56, height: 56)
                    .background(ColorTokens.secondaryPurpleLight3)
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 4) {
                    // Timestamp
                    Text(item.createdAt, style: .relative)
                        .font(.custom("Arial", size: 13.5))
                        .foregroundColor(Color(hex: "#91949B"))
                    
                    // Title
                    Text(item.title)
                        .font(.custom("Arial", size: 18.6))
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .lineLimit(2)

                    // Teacher name
                    if let teacher = item.teacher {
                        Text("Teacher : \(teacher)")
                            .font(.custom("Arial", size: 14))
                            .foregroundColor(Color(hex: "#61758A"))
                    }
                }
            }

            Button("Open") {
                onOpen()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(16)
        .frame(width: 301, height: 133)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(hex: "#332177").opacity(0.15), radius: 4, x: 1, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to open lesson")
    }
}

// MARK: - Recent row (Per Figma specs)
private struct RecentRow: View {
    let item: LessonIndexItem

    var body: some View {
        HStack(spacing: 12) {
            // Icon with background
            Image(systemName: "doc.text.fill")
                .font(.system(size: 24))
                .foregroundColor(ColorTokens.primary)
                .frame(width: 56, height: 56)
                .background(Color(hex: "#DEECF8"))
                .clipShape(RoundedRectangle(cornerRadius: 13.75))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.createdAt, style: .relative)
                    .font(.custom("Arial", size: 13.7))
                    .foregroundColor(Color(hex: "#91949B"))
                
                Text(item.title)
                    .font(.custom("Arial", size: 18.6))
                    .foregroundColor(.black)
                    .lineLimit(1)
            }

            Spacer()

            // Three dots menu
            Button {
                // Menu action
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundColor(ColorTokens.textSecondaryAdaptive)
            }
            .accessibilityHidden(true)
        }
        .padding(16)
        .frame(height: 95)
        .background(Color(hex: "#FEFEFE"))
        .overlay(
            RoundedRectangle(cornerRadius: 21)
                .stroke(Color(hex: "#F3F3F4"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 21))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to open document")
    }
}

// MARK: - Bottom Tab Bar (95px height per Figma)
private struct HomeTabBar: View {
    @Binding var selectedTab: DashboardView.HomeTab

    var body: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(Color(hex: "#F0F2F5"))
                .frame(height: 1)
            
            HStack(spacing: 8) {
                tabButton(tab: .accessibility,
                          icon: "accessibility",
                          label: "Accessibility")

                tabButton(tab: .home,
                          icon: "house.fill",
                          label: "Home")

                tabButton(tab: .allFiles,
                          icon: "doc.on.doc",
                          label: "All files")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Safe area spacer
            Rectangle()
                .fill(Color.white)
                .frame(height: 20)
        }
        .frame(height: 95)
        .background(Color.white)
    }

    private func tabButton(
        tab: DashboardView.HomeTab,
        icon: String,
        label: String
    ) -> some View {
        let isSelected = (tab == selectedTab)

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(
                        isSelected ? Color(hex: "#01343C") : Color(hex: "#61758A")
                    )

                Text(label)
                    .font(.custom("Arial", size: 12).weight(isSelected ? .semibold : .medium))
                    .foregroundColor(
                        isSelected ? Color(hex: "#01343C") : Color(hex: "#61758A")
                    )
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                isSelected
                ? Color(hex: "#E8F2F2")
                : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 27))
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Reader container
private struct ReaderContainer: View {
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var speech: SpeechService
    @Environment(\.dismiss) private var dismiss
    let item: LessonIndexItem

    var body: some View {
        let pages = WorksheetLoader.loadPages(
            lessonStore: lessonStore,
            filenames: item.localFiles
        )

        Group {
            if !pages.isEmpty {
                WorksheetView(title: item.title, pages: pages)
            } else {
                let nodes = lessonStore.loadNodes(forFilenames: item.localFiles)
                DocumentRendererView(title: item.title, nodes: nodes)
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
                .accessibilityHint("Close worksheet and return to home")
            }
        }
    }
}

// MARK: - Processing File Card (with progress bar)

private struct ProcessingFileCard: View {
    let processingFile: ProcessingFile
    
    var body: some View {
        HStack(spacing: 12) {
            // PDF icon
            Image(systemName: "doc.fill")
                .font(.system(size: 24))
                .foregroundColor(Color(hex: "#B31111"))
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Processing...")
                    .font(.custom("Arial", size: 13.5))
                    .foregroundColor(Color(hex: "#91949B"))
                
                Text(processingFile.item.title)
                    .font(.custom("Arial", size: 18.6))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color(hex: "#E8F2F2"))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        // Progress
                        Rectangle()
                            .fill(ColorTokens.primary)
                            .frame(width: geometry.size.width * processingFile.progress, height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
                
                // Progress percentage
                Text("\(Int(processingFile.progress * 100))% Complete")
                    .font(.custom("Arial", size: 12))
                    .foregroundColor(Color(hex: "#61758A"))
            }
            
            Spacer()
            
            // Loading spinner
            ProgressView()
                .scaleEffect(0.8)
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Processing \(processingFile.item.title), \(Int(processingFile.progress * 100)) percent complete")
    }
}

// MARK: - Completed File Card (with checkmark)

private struct CompletedFileCard: View {
    let item: LessonIndexItem
    var onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // PDF icon
                Image(systemName: "doc.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#B31111"))
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Arial", size: 18.6))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    Text(formatFileMetadata(for: item))
                        .font(.custom("Arial", size: 13.5))
                        .foregroundColor(Color(hex: "#91949B"))
                }
                
                Spacer()
                
                // Checkmark icon
                Image("tick-mark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            .padding(16)
            .background(ColorTokens.uploadedFileCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ColorTokens.uploadedFileCardBackground, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), completed")
        .accessibilityHint("Double tap to open")
    }
    
    private func formatFileMetadata(for item: LessonIndexItem) -> String {
        let timeAgo = formatTimeAgo(from: item.createdAt)
        let fileSize = estimateFileSize(pages: item.localFiles.count)
        return "\(timeAgo), \(fileSize)"
    }
    
    private func formatTimeAgo(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes) min ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    private func estimateFileSize(pages: Int) -> String {
        // Rough estimate: ~150KB per page
        let sizeInKB = pages * 150
        if sizeInKB < 1024 {
            return "\(sizeInKB)KB"
        } else {
            let sizeInMB = Double(sizeInKB) / 1024.0
            return String(format: "%.1fMB", sizeInMB)
        }
    }
}
