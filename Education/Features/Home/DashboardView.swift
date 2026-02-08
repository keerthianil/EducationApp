//
//  DashboardView.swift
//  Education
//
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
    @State private var navigateToFlowSelection = false
    @StateObject private var notificationDelegate = NotificationDelegate.shared
    @StateObject private var uploadManager = UploadManager()
    
    @State private var previousProcessingCount = 0
    @State private var previousCompletedCount = 0
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    // Removed accessibility tab for user testing
    enum HomeTab {
        case home, allFiles
        // case accessibility - temporarily removed for user testing
    }
    
    enum SidebarItem: String, CaseIterable {
        case home = "Home"
        case uploads = "Uploads"
        case teacherFiles = "Teacher Files"
        case recent = "Recent"
        // case accessibility = "Accessibility" - temporarily removed for user testing
        case allFiles = "All Files"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .uploads: return "icloud.and.arrow.up"
            case .teacherFiles: return "folder"
            case .recent: return "clock"
            // case .accessibility: return "accessibility"
            case .allFiles: return "doc.on.doc"
            case .settings: return "gearshape"
            }
        }
    }
    
    var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? .infinity : .infinity
    }
    
    var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }
    
    var teacherCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 280 : 301
    }

    // MARK: - Body (Split to fix compiler type-check error)

    var body: some View {
        coreView
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
            .onChange(of: selectedTab) { oldTab, newTab in
                InteractionLogger.shared.log(
                    event: .tabChange,
                    objectType: .tab,
                    label: newTab == .home ? "Home" : "All Files",
                    location: .zero,
                    additionalInfo: "Tab changed from \(oldTab)"
                )
            }
    }
    
    // Second half of modifiers, separated from body
    private var coreView: some View {
        mainLayout
            .sheet(isPresented: $showUpload) {
                UploadSheetView(uploadManager: uploadManager)
                    .environmentObject(lessonStore)
                    .environmentObject(haptics)
            }
            .onAppear {
                uploadManager.lessonStore = lessonStore
                previousProcessingCount = lessonStore.processing.count
                previousCompletedCount = lessonStore.downloaded.count
                InteractionLogger.shared.setCurrentScreen("DashboardView_Flow1")
            }
            .fullScreenCover(item: $selectedLesson) { lesson in
                NavigationStack {
                    ReaderContainer(item: lesson)
                        .environmentObject(lessonStore)
                        .environmentObject(speech)
                        .environmentObject(haptics)
                        .environmentObject(mathSpeech)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(
                NavigationLink(destination: ChooseFlowView().navigationBarBackButtonHidden(true), isActive: $navigateToFlowSelection) {
                    EmptyView()
                }
                .hidden()
            )
    }
    
    // The actual layout switch
    private var mainLayout: some View {
        Group {
            if isIPad {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
    }
    
    // MARK: - iPad Layout
    
    var iPadLayout: some View {
        HStack(spacing: 0) {
            iPadSidebar
            iPadMainContentArea
            iPadRecentActivityPanel
        }
        .background(Color(hex: "#F6F7F8"))
    }
    
    var iPadMainContentArea: some View {
        ScrollView {
            iPadMainContentVStack
        }
        .background(Color(hex: "#F6F7F8"))
    }
       
    private var iPadMainContentVStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            iPadMainTitle
            
            if selectedTab == .home {
                iPadHomeContent
            } else if selectedTab == .allFiles {
                iPadAllFilesSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .padding(.bottom, 40)
    }
       
    private var iPadMainTitle: some View {
        Text("StemAlly")
            .font(.custom("Arial", size: 28).weight(.bold))
            .foregroundColor(Color(hex: "#121417"))
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
    }
       
    private var iPadHomeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        }
    }

    
    // MARK: - iPad Sidebar
       
    var iPadSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            iPadSidebarHeader
            iPadSidebarContent
            Spacer()
            iPadSidebarFooter
        }
        .frame(width: 240)
        .background(Color.white)
    }
       
    private var iPadSidebarHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back to Flow Selection button
            Button {
                haptics.tapSelection()
                InteractionLogger.shared.log(
                    event: .tap,
                    objectType: .button,
                    label: "Back to Flow Selection",
                    location: .zero
                )
                InteractionLogger.shared.endSession()
                navigateToFlowSelection = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Flows")
                        .font(.custom("Arial", size: 14))
                }
                .foregroundColor(ColorTokens.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .accessibilityLabel("Back to flow selection")
            .padding(.top, 12)
            
            Text("StemAlly")
                .font(.custom("Arial", size: 22).weight(.bold))
                .foregroundColor(Color(hex: "#121417"))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
    }
       
    private var iPadSidebarContent: some View {
        VStack(spacing: 4) {
            sidebarButton(item: .home)
            sidebarButton(item: .uploads)
            sidebarButton(item: .teacherFiles)
            sidebarButton(item: .recent)
            
            Divider()
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            
            sidebarButton(item: .allFiles, isExpandable: true)
        }
        .padding(.horizontal, 8)
    }
       
    private var iPadSidebarFooter: some View {
        sidebarButton(item: .settings)
            .padding(.horizontal, 8)
            .padding(.bottom, 24)
    }
    
    // MARK: - Sidebar Button
    
    func sidebarButton(item: SidebarItem, isExpandable: Bool = false) -> some View {
        Button {
            haptics.tapSelection()
            selectedSidebarItem = item
            
            switch item {
            case .home:
                selectedTab = .home
            case .allFiles:
                selectedTab = .allFiles
            default:
                break
            }
            
            InteractionLogger.shared.logTap(
                objectType: .button,
                label: "Sidebar: \(item.rawValue)"
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundColor(selectedSidebarItem == item ? ColorTokens.primary : Color(hex: "#61758A"))
                    .frame(width: 24)
                
                Text(item.rawValue)
                    .font(.custom("Arial", size: 15).weight(selectedSidebarItem == item ? .semibold : .regular))
                    .foregroundColor(selectedSidebarItem == item ? ColorTokens.primary : Color(hex: "#121417"))
                
                Spacer()
                
                if isExpandable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#91949B"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selectedSidebarItem == item ? ColorTokens.primaryLight3 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.rawValue)
        .accessibilityAddTraits(selectedSidebarItem == item ? [.isSelected, .isButton] : [.isButton])
    }
    
    // MARK: - iPad Banner Section
    
    @ViewBuilder
    var iPadBannerSection: some View {
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
                    InteractionLogger.shared.logTap(
                        objectType: .banner,
                        label: "Banner View: \(item.title)"
                    )
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
    
    var iPadUploadPanel: some View {
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
                        InteractionLogger.shared.logTap(
                            objectType: .button,
                            label: "Browse Files"
                        )
                        showUpload = true
                    }
                    .font(.custom("Arial", size: 14).weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(ColorTokens.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Scan Files button - temporarily commented out for user testing
                    /*
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
                    */
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            
            // "Or upload from" text and cloud buttons - temporarily commented out for user testing
            /*
            VStack(alignment: .leading, spacing: 16) {
                Text("Or upload from")
                    .font(.custom("Arial", size: 16).weight(.medium))
                    .foregroundColor(Color(hex: "#6F6F6F"))
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
            */
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
    var iPadUploadedSection: some View {
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
                            InteractionLogger.shared.logTap(
                                objectType: .fileCard,
                                label: "Completed: \(item.title)"
                            )
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
    var iPadUploadedByTeacherSection: some View {
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
                        InteractionLogger.shared.logTap(
                            objectType: .button,
                            label: "See All Teacher Files"
                        )
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
    
    func iPadTeacherCard(item: LessonIndexItem) -> some View {
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
                InteractionLogger.shared.logTap(
                    objectType: .card,
                    label: "Teacher Card: \(item.title)"
                )
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
    var iPadAllFilesSection: some View {
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
                            InteractionLogger.shared.logTap(
                                objectType: .fileCard,
                                label: "All Files: \(item.title)"
                            )
                            selectedLesson = item
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - iPad Recent Activity Panel
    
    var iPadRecentActivityPanel: some View {
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
    
    func iPadRecentActivityRow(item: LessonIndexItem) -> some View {
        Button {
            haptics.tapSelection()
            InteractionLogger.shared.logTap(
                objectType: .listRow,
                label: "Recent: \(item.title)"
            )
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
            iPhoneScrollContent
            
            HomeTabBar(selectedTab: $selectedTab, onBackToFlows: {
                InteractionLogger.shared.endSession()
                navigateToFlowSelection = true
            })
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var iPhoneScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection()
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                
                if selectedTab == .home {
                    iPhoneHomeTabContent
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
    }
    
    private var iPhoneHomeTabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        }
    }

    // MARK: - Header Section
    private func headerSection() -> some View {
        HStack {
            // Back to Flows button
            Button {
                haptics.tapSelection()
                InteractionLogger.shared.log(
                    event: .tap,
                    objectType: .button,
                    label: "Back to Flows",
                    location: .zero
                )
                InteractionLogger.shared.endSession()
                navigateToFlowSelection = true
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ColorTokens.primary)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Back to flow selection")
            
            Spacer()
            
            // Three dot menu - temporarily hidden for user testing
            /*
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
            */
            
            Spacer()
                .frame(width: 40)
        }
        .overlay(
            Text("StemAlly")
                .font(.custom("Arial", size: 22.3))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#47494F"))
                .accessibilityLabel("StemAlly"),
            alignment: .center
        )
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
                InteractionLogger.shared.logTap(
                    objectType: .banner,
                    label: "Banner: \(item.title)"
                )
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

            Text("Upload Your Files")
                .font(.custom("Arial", size: 20.3))
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#4E5055"))

            // "Browse files or scan" text - temporarily commented out for user testing
            /*
            Text("Browse files or scan")
                .font(.custom("Arial", size: 15.9))
                .foregroundColor(Color(hex: "#989CA6"))
            */

            VStack(spacing: 12) {
                Button("Browse files") {
                    haptics.tapSelection()
                    InteractionLogger.shared.logTap(
                        objectType: .button,
                        label: "Browse Files"
                    )
                    showUpload = true
                }
                .buttonStyle(PrimaryButtonStyle())

                // Scan files button - temporarily commented out for user testing
                /*
                Button("Scan files") { }
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
            */
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
                            InteractionLogger.shared.logTap(
                                objectType: .fileCard,
                                label: "Completed: \(item.title)"
                            )
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
                            InteractionLogger.shared.logTap(
                                objectType: .fileCard,
                                label: "All Files: \(item.title)"
                            )
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
                                InteractionLogger.shared.logTap(
                                    objectType: .card,
                                    label: "Teacher: \(item.title)"
                                )
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

    var teacherLessons: [LessonIndexItem] {
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
                        InteractionLogger.shared.logTap(
                            objectType: .listRow,
                            label: "Recent: \(item.title)"
                        )
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
    var onBackToFlows: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var tabBarHeight: CGFloat {
        horizontalSizeClass == .regular ? 105 : 95
    }
    
    private var tabs: [(tab: DashboardView.HomeTab, icon: String, label: String)] {
        [
            (.home, "house.fill", "Home"),
            (.allFiles, "doc.on.doc", "All files")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: "#F0F2F5"))
                .frame(height: 1)
            
            HStack(spacing: 8) {
                ForEach(Array(tabs.enumerated()), id: \.element.tab) { index, item in
                    tabButton(
                        tab: item.tab,
                        icon: item.icon,
                        label: item.label,
                        index: index + 1,
                        total: tabs.count
                    )
                }
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
        .accessibilityElement(children: .contain)
    }

    private func tabButton(tab: DashboardView.HomeTab, icon: String, label: String, index: Int, total: Int) -> some View {
        let isSelected = (tab == selectedTab)

        return Button {
            InteractionLogger.shared.log(
                event: .tabChange,
                objectType: .tab,
                label: label,
                location: .zero
            )
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "selected" : "")
        .accessibilityHint("Tab \(index) of \(total)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}

// MARK: - Reader Container
private struct ReaderContainer: View {
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
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
                    .environmentObject(speech)
                    .environmentObject(haptics)
                    .environmentObject(mathSpeech)
            } else {
                let nodes = lessonStore.loadNodes(forFilenames: item.localFiles)
                DocumentRendererView(title: item.title, nodes: nodes)
                    .environmentObject(speech)
                    .environmentObject(haptics)
                    .environmentObject(mathSpeech)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            InteractionLogger.shared.setCurrentScreen("ReaderView: \(item.title)")
        }
    }
}

// MARK: - Processing File Card
struct ProcessingFileCard: View {
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
struct CompletedFileCard: View {
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
