//
//  DashboardView.swift
//  Education
//

import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var mathSpeech: MathSpeechService

    @State private var showUpload = false
    @State private var selectedLesson: LessonIndexItem?
    @State private var selectedTab: HomeTab = .home
    @State private var selectedSidebarItem: SidebarItem = .home
    @StateObject private var notificationDelegate = NotificationDelegate.shared
    @StateObject private var uploadManager = UploadManager()
    
    @State private var previousProcessingCount = 0
    @State private var previousCompletedCount = 0
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    enum HomeTab {
        case accessibility, home, allFiles
    }
    
    enum SidebarItem: String, CaseIterable {
        case home = "Home"
        case uploads = "Uploads"
        case teacherFiles = "Teacher Files"
        case recent = "Recent"
        case accessibility = "Accessibility"
        case allFiles = "All Files"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .uploads: return "icloud.and.arrow.up"
            case .teacherFiles: return "folder"
            case .recent: return "clock"
            case .accessibility: return "accessibility"
            case .allFiles: return "doc.on.doc"
            case .settings: return "gearshape"
            }
        }
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? .infinity : .infinity
    }
    
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }
    
    private var teacherCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 280 : 301
    }

    var body: some View {
        Group {
            if isIPad {
                iPadLayout
            } else {
                iPhoneLayout
            }
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
                ReaderContainer(item: lesson)
            }
        }
        .onChange(of: notificationDelegate.selectedLessonId) { oldLessonId, newLessonId in
            if let lessonId = newLessonId,
               let lesson = lessonStore.recent.first(where: { $0.id == lessonId }) {
                selectedLesson = lesson
                notificationDelegate.selectedLessonId = nil
            }
        }
        .onChange(of: lessonStore.processing.count) { oldCount, newCount in
            previousProcessingCount = newCount
        }
        .onChange(of: lessonStore.downloaded.count) { oldCount, newCount in
            previousCompletedCount = newCount
        }
        .toolbar(.hidden, for: .navigationBar)
    }
    
    // MARK: - iPad Layout
    
    private var iPadLayout: some View {
        HStack(spacing: 0) {
            iPadSidebar
            
            iPadMainContent
            
            iPadRecentActivityPanel
        }
        .background(Color(hex: "#F6F7F8"))
    }
    
    // MARK: - iPad Sidebar
    
    private var iPadSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("STEMA11Y")
                .font(.custom("Arial", size: 22).weight(.bold))
                .foregroundColor(Color(hex: "#121417"))
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            
            VStack(spacing: 4) {
                ForEach([SidebarItem.home, .uploads, .teacherFiles, .recent], id: \.self) { item in
                    sidebarButton(item: item)
                }
                
                Divider()
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                
                sidebarButton(item: .accessibility, isExpandable: true)
                sidebarButton(item: .allFiles, isExpandable: true)
            }
            .padding(.horizontal, 8)
            
            Spacer()
            
            sidebarButton(item: .settings)
                .padding(.horizontal, 8)
                .padding(.bottom, 24)
        }
        .frame(width: 240)
        .background(Color.white)
    }
    
    private func sidebarButton(item: SidebarItem, isExpandable: Bool = false) -> some View {
        Button {
            haptics.tapSelection()
            selectedSidebarItem = item
            switch item {
            case .home:
                selectedTab = .home
            case .allFiles:
                selectedTab = .allFiles
            case .accessibility:
                selectedTab = .accessibility
            default:
                selectedTab = .home
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .foregroundColor(selectedSidebarItem == item ? .white : Color(hex: "#121417"))
                    .frame(width: 24)
                
                Text(item.rawValue)
                    .font(.custom("Arial", size: 16))
                    .foregroundColor(selectedSidebarItem == item ? .white : Color(hex: "#121417"))
                
                Spacer()
                
                if isExpandable {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(selectedSidebarItem == item ? .white : Color(hex: "#61758A"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedSidebarItem == item ? ColorTokens.primary : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.rawValue)
        .accessibilityAddTraits(selectedSidebarItem == item ? .isSelected : [])
    }
    
    // MARK: - iPad Main Content
    
    private var iPadMainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Dashboard")
                    .font(.custom("Arial", size: 28).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                
                if selectedTab == .home {
                    iPadBannerSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    
                    iPadUploadPanel
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    
                    iPadUploadedSection
                        .padding(.bottom, 12)
                    
                    iPadUploadedByTeacherSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                } else if selectedTab == .allFiles {
                    iPadAllFilesSection
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(hex: "#F6F7F8"))
    }
    
    // MARK: - iPad Banner Section
    
    @ViewBuilder
    private var iPadBannerSection: some View {
        if let item = (lessonStore.banner ?? lessonStore.recent.first) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ColorTokens.primaryLight3)
                        .frame(width: 56, height: 56)
                    
                    Image("pdf-icon-blue")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Important Update")
                        .font(.custom("Arial", size: 14))
                        .foregroundColor(ColorTokens.primary)
                    
                    Text(item.title)
                        .font(.custom("Arial", size: 18).weight(.semibold))
                        .foregroundColor(Color(hex: "#121417"))
                    
                    Text("Uploaded \(item.createdAt, style: .relative)")
                        .font(.custom("Arial", size: 13))
                        .foregroundColor(Color(hex: "#61758A"))
                }
                
                Spacer()
                
                Button("View") {
                    haptics.tapSelection()
                    selectedLesson = item
                }
                .font(.custom("Arial", size: 14).weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ColorTokens.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(16)
            .background(Color(hex: "#F4F1FE"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - iPad Upload Panel
    
    private var iPadUploadPanel: some View {
        HStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Upload Panel")
                    .font(.custom("Arial", size: 18).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
                
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 40))
                    .foregroundColor(ColorTokens.primary.opacity(0.6))
                    .accessibilityHidden(true)
                
                HStack(spacing: 12) {
                    Button("Browse Files") {
                        haptics.tapSelection()
                        showUpload = true
                    }
                    .font(.custom("Arial", size: 14).weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(ColorTokens.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Button("Scan Files") { }
                        .font(.custom("Arial", size: 14).weight(.bold))
                        .foregroundColor(Color(hex: "#121417"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .disabled(true)
                        .opacity(0.5)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Or upload from")
                    .font(.custom("Arial", size: 16).weight(.medium))
                    .foregroundColor(Color(hex: "#61758A"))
                    .accessibilityHidden(true)
                
                Button { } label: {
                    HStack {
                        Image("GoogleDrive")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Drive")
                            .font(.custom("Arial", size: 14))
                            .foregroundColor(Color(hex: "#121417"))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityHidden(true)
                
                Button { } label: {
                    HStack {
                        Image("Dropbox")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Dropbox")
                            .font(.custom("Arial", size: 14))
                            .foregroundColor(Color(hex: "#121417"))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityHidden(true)
            }
            .frame(width: 200)
            .padding(.vertical, 24)
        }
        .padding(.horizontal, 24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
        )
    }
    
    // MARK: - iPad Uploaded Section
    
    @ViewBuilder
    private var iPadUploadedSection: some View {
        let processingFiles = lessonStore.processing
        let recentCompletedFiles = lessonStore.downloaded.filter { item in
            !processingFiles.contains { $0.item.id == item.id } &&
            item.createdAt > Date().addingTimeInterval(-24 * 60 * 60)
        }
        
        if !processingFiles.isEmpty || !recentCompletedFiles.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Uploaded")
                    .font(.custom("Arial", size: 20).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
                    .padding(.horizontal, 24)
                    .accessibilityAddTraits(.isHeader)
                
                VStack(spacing: 8) {
                    ForEach(processingFiles) { processingFile in
                        ProcessingFileCard(processingFile: processingFile)
                    }
                    
                    ForEach(recentCompletedFiles) { item in
                        CompletedFileCard(item: item) {
                            haptics.tapSelection()
                            selectedLesson = item
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - iPad Uploaded by Teacher Section
    
    @ViewBuilder
    private var iPadUploadedByTeacherSection: some View {
        let teacherItems = lessonStore.recent.filter { $0.teacher != nil }
        
        if !teacherItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Uploaded by Teacher")
                        .font(.custom("Arial", size: 20).weight(.bold))
                        .foregroundColor(Color(hex: "#121417"))
                    
                    Spacer()
                    
                    Button("See all") {
                        haptics.tapSelection()
                    }
                    .font(.custom("Arial", size: 14))
                    .foregroundColor(ColorTokens.primary)
                }
                .accessibilityAddTraits(.isHeader)
                
                HStack(spacing: 16) {
                    ForEach(teacherItems.prefix(3)) { item in
                        iPadTeacherCard(item: item)
                    }
                }
            }
        }
    }
    
    private func iPadTeacherCard(item: LessonIndexItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "#E8F5E9"))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "doc.text")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "#4CAF50"))
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Arial", size: 16).weight(.medium))
                        .foregroundColor(Color(hex: "#121417"))
                        .lineLimit(1)
                    
                    if let teacher = item.teacher {
                        Text("\(teacher) • \(item.createdAt, style: .relative)")
                            .font(.custom("Arial", size: 12))
                            .foregroundColor(Color(hex: "#61758A"))
                    }
                }
                
                Spacer()
                
                Text("PDF")
                    .font(.custom("Arial", size: 11).weight(.medium))
                    .foregroundColor(Color(hex: "#61758A"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#F5F5F5"))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            Button("Open") {
                haptics.tapSelection()
                selectedLesson = item
            }
            .font(.custom("Arial", size: 14).weight(.medium))
            .foregroundColor(Color(hex: "#121417"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(hex: "#F5F5F5"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .frame(width: 260)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), from \(item.teacher ?? "teacher")")
        .accessibilityHint("Double tap to open")
    }
    
    // MARK: - iPad All Files Section
    
    @ViewBuilder
    private var iPadAllFilesSection: some View {
        let allUploadedFiles = lessonStore.downloaded.sorted { $0.createdAt > $1.createdAt }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("All Files")
                .font(.custom("Arial", size: 20).weight(.bold))
                .foregroundColor(Color(hex: "#121417"))
                .padding(.top, 20)
                .accessibilityAddTraits(.isHeader)
            
            if allUploadedFiles.isEmpty {
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
    
    // MARK: - iPad Recent Activity Panel
    
    private var iPadRecentActivityPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Activity")
                .font(.custom("Arial", size: 20).weight(.bold))
                .foregroundColor(Color(hex: "#121417"))
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(lessonStore.recent.prefix(10)) { item in
                        iPadRecentActivityRow(item: item)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .frame(width: 280)
        .background(Color.white)
    }
    
    private func iPadRecentActivityRow(item: LessonIndexItem) -> some View {
        Button {
            haptics.tapSelection()
            selectedLesson = item
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "#DEECF8"))
                        .frame(width: 40, height: 40)
                    
                    Image("pdf-icon-blue")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.custom("Arial", size: 14).weight(.medium))
                        .foregroundColor(Color(hex: "#121417"))
                        .lineLimit(1)
                    
                    Text("Opened \(item.createdAt, style: .relative)")
                        .font(.custom("Arial", size: 12))
                        .foregroundColor(Color(hex: "#61758A"))
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityHint("Double tap to open")
    }
    
    // MARK: - iPhone Layout
    
    private var iPhoneLayout: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection()
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    
                    if selectedTab == .home {
                        bannerSection()
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 16)
                        
                        uploadSection()
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 20)
                        
                        uploadedSection()
                            .padding(.bottom, 12)
                        
                        uploadedByTeacherSection()
                            .padding(.bottom, 12)
                        
                        recentsSection()
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 20)
                    } else if selectedTab == .allFiles {
                        allFilesSection()
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 20)
                    }
                }
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 95)
            }
            .background(Color(hex: "#F6F7F8"))

            HomeTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Header Section
    private func headerSection() -> some View {
        HStack {
            Text("Logo")
                .font(.custom("Arial", size: 22.3))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#47494F"))
                .accessibilityLabel("Education App")

            Spacer()

            Button {
                haptics.tapSelection()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#47494F"))
                    .rotationEffect(.degrees(90))
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

    // MARK: - Upload Section
    private func uploadSection() -> some View {
        VStack(spacing: 18) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 48, weight: .regular))
                .foregroundColor(ColorTokens.primary)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Upload Your Files")
                    .font(.custom("Arial", size: 20.3))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#4E5055"))

                Text("Browse files or scan")
                    .font(.custom("Arial", size: 15.9))
                    .foregroundColor(Color(hex: "#989CA6"))
            }

            VStack(spacing: 12) {
                Button("Browse files") {
                    haptics.tapSelection()
                    showUpload = true
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Scan files") { }
                    .buttonStyle(TertiaryButtonStyle(isDisabled: true))
                    .disabled(true)
                    .accessibilityHidden(true)
            }

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
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 25)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 1, y: 1)
    }

    // MARK: - Uploaded Section
    @ViewBuilder
    private func uploadedSection() -> some View {
        let processingFiles = lessonStore.processing
        let recentCompletedFiles = lessonStore.downloaded.filter { item in
            !processingFiles.contains { $0.item.id == item.id } &&
            item.createdAt > Date().addingTimeInterval(-24 * 60 * 60)
        }
        
        if !processingFiles.isEmpty || !recentCompletedFiles.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Uploaded")
                    .font(.custom("Arial", size: 22))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#121417"))
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    .accessibilityAddTraits(.isHeader)
                
                VStack(spacing: 8) {
                    ForEach(processingFiles) { processingFile in
                        ProcessingFileCard(processingFile: processingFile)
                    }
                    
                    ForEach(recentCompletedFiles) { item in
                        CompletedFileCard(item: item) {
                            haptics.tapSelection()
                            selectedLesson = item
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
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
                .accessibilityAddTraits(.isHeader)
            
            if allUploadedFiles.isEmpty {
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
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    .accessibilityAddTraits(.isHeader)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(teacherItems) { item in
                            TeacherLessonCard(item: item, cardWidth: teacherCardWidth) {
                                haptics.tapSelection()
                                selectedLesson = item
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 20)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Uploaded by Teacher, \(teacherItems.count) file\(teacherItems.count == 1 ? "" : "s")")
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
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 11) {
                ForEach(lessonStore.recent) { item in
                    RecentRow(item: item) {
                        haptics.tapSelection()
                        selectedLesson = item
                    }
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

// MARK: - Tertiary Button Style
public struct TertiaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    
    public init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Arial", size: 17).weight(.bold))
            .foregroundColor(isDisabled ? ColorTokens.textTertiary : ColorTokens.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isDisabled ? ColorTokens.primaryLight3 : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDisabled ? ColorTokens.primaryLight2 : Color(hex: "#DADDE2"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .contentShape(Rectangle())
    }
}

// MARK: - Teacher Lesson Card
private struct TeacherLessonCard: View {
    let item: LessonIndexItem
    let cardWidth: CGFloat
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "#FEDFDE"))
                            .frame(width: 44, height: 44)
                        
                        Image("pdf-icon-red")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.createdAt, style: .relative)
                            .font(.custom("Arial", size: 13.5))
                            .foregroundColor(Color(hex: "#91949B"))
                        
                        Text(item.title)
                            .font(.custom("Arial", size: 18.6))
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .lineLimit(2)

                        if let teacher = item.teacher {
                            Text("Teacher : \(teacher)")
                                .font(.custom("Arial", size: 14))
                                .foregroundColor(Color(hex: "#61758A"))
                        }
                    }
                }

                Text("Open")
                    .font(.custom("Arial", size: 17).weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(ColorTokens.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(16)
            .frame(width: cardWidth, height: 133)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color(hex: "#332177").opacity(0.15), radius: 4, x: 1, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), from \(item.teacher ?? "teacher")")
        .accessibilityHint("Double tap to open")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Recent Row
private struct RecentRow: View {
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
                    Text(item.createdAt, style: .relative)
                        .font(.custom("Arial", size: 13.7))
                        .foregroundColor(Color(hex: "#91949B"))
                    
                    Text(item.title)
                        .font(.custom("Arial", size: 18.6))
                        .foregroundColor(.black)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundColor(ColorTokens.textSecondaryAdaptive)
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
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title)")
        .accessibilityHint("Double tap to open")
    }
}

// MARK: - Bottom Tab Bar
private struct HomeTabBar: View {
    @Binding var selectedTab: DashboardView.HomeTab
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var tabBarHeight: CGFloat {
        horizontalSizeClass == .regular ? 105 : 95
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: "#F0F2F5"))
                .frame(height: 1)
            
            HStack(spacing: 8) {
                tabButton(tab: .accessibility, icon: "accessibility", label: "Accessibility")
                tabButton(tab: .home, icon: "house.fill", label: "Home")
                tabButton(tab: .allFiles, icon: "doc.on.doc", label: "All files")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Rectangle()
                .fill(Color.white)
                .frame(height: 20)
        }
        .frame(height: tabBarHeight)
        .background(Color.white)
    }

    private func tabButton(tab: DashboardView.HomeTab, icon: String, label: String) -> some View {
        let isSelected = (tab == selectedTab)

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(hex: "#01343C") : Color(hex: "#61758A"))

                Text(label)
                    .font(.custom("Arial", size: 12).weight(isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? Color(hex: "#01343C") : Color(hex: "#61758A"))
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color(hex: "#E8F2F2") : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 27))
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Reader Container
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
            }
        }
    }
}

// MARK: - Processing File Card
private struct ProcessingFileCard: View {
    let processingFile: ProcessingFile
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Processing...")
                    .font(.custom("Arial", size: 13.5))
                    .foregroundColor(Color(hex: "#91949B"))
                
                Text(processingFile.item.title)
                    .font(.custom("Arial", size: horizontalSizeClass == .regular ? 20 : 18.6))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(hex: "#E8F2F2"))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(ColorTokens.primary)
                            .frame(width: geometry.size.width * processingFile.progress, height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
                
                Text("\(Int(processingFile.progress * 100))% Complete")
                    .font(.custom("Arial", size: 12))
                    .foregroundColor(Color(hex: "#61758A"))
            }
            
            Spacer()
            
            ProgressView()
                .scaleEffect(0.8)
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing \(processingFile.item.title), \(Int(processingFile.progress * 100)) percent")
    }
}

// MARK: - Completed File Card
private struct CompletedFileCard: View {
    let item: LessonIndexItem
    var onTap: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
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
                        .font(.custom("Arial", size: horizontalSizeClass == .regular ? 20 : 18.6))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    Text(formatFileMetadata(for: item))
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
        let sizeInKB = pages * 150
        if sizeInKB < 1024 {
            return "\(sizeInKB)KB"
        } else {
            let sizeInMB = Double(sizeInKB) / 1024.0
            return String(format: "%.1fMB", sizeInMB)
        }
    }
}
