//
//  DashboardView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.


import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var mathSpeech: MathSpeechService

    @State private var showUpload = false
    @State private var selectedLesson: LessonIndexItem?
    @State private var selectedTab: HomeTab = .home

    enum HomeTab {
        case accessibility, home, allFiles
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.sectionSpacing) {
                        headerSection()
                        bannerSection()
                        uploadSection()
                        uploadedByTeacherSection()
                        recentsSection()
                    }
                    .padding(Spacing.screenPadding)
                    .padding(.bottom, Spacing.xxLarge) // space for tab bar
                }
                .background(ColorTokens.backgroundAdaptive)

                HomeTabBar(selectedTab: $selectedTab)
            }
            .ignoresSafeArea(edges: .bottom)
            .sheet(isPresented: $showUpload) {
                UploadSheetView()
                    .environmentObject(lessonStore)
                    .environmentObject(haptics)
            }
            .navigationDestination(item: $selectedLesson) { item in
                ReaderContainer(item: item)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Sections

    private func headerSection() -> some View {
        HStack {
            Text("Logo")
                .font(Typography.headline)
                .foregroundColor(ColorTokens.textPrimaryAdaptive)

            Spacer()

            Button {
                haptics.tapSelection()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .rotationEffect(.degrees(90))
                    .foregroundColor(ColorTokens.textSecondaryAdaptive)
            }
            .accessibilityLabel("More options")
        }
    }

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
            .padding(.top, Spacing.medium)
        }
    }

    private func uploadSection() -> some View {
        VStack(spacing: Spacing.medium) {
            // Cloud icon
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 40, weight: .regular))
                .foregroundColor(ColorTokens.primary)

            VStack(spacing: 4) {
                Text("Upload Your Files")
                    .font(Typography.heading2)
                    .foregroundColor(ColorTokens.textPrimaryAdaptive)

                Text("Browse files or scan")
                    .font(Typography.subheadline)
                    .foregroundColor(ColorTokens.textSecondaryAdaptive)
            }

            VStack(spacing: Spacing.small) {
                Button("Browse files") {
                    haptics.tapSelection()
                    showUpload = true
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Scan files") {
                    // not implemented in demo
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(true)
                .accessibilityHint("Not available in this demo")
            }

            Text("or upload from")
                .font(Typography.caption1)
                .foregroundColor(ColorTokens.textSecondaryAdaptive)

            HStack(spacing: Spacing.medium) {
                HStack(spacing: 8) {
                    Image("GoogleDrive")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)

                    Text("Google Dr…")
                        .font(Typography.caption1)
                        .foregroundColor(ColorTokens.textPrimaryAdaptive)
                }
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, 8)
                .background(ColorTokens.surfaceAdaptive2)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))

                HStack(spacing: 8) {
                    Image("Dropbox")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)

                    Text("Dropbox")
                        .font(Typography.caption1)
                        .foregroundColor(ColorTokens.textPrimaryAdaptive)
                }
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, 8)
                .background(ColorTokens.surfaceAdaptive2)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
            }
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                .fill(ColorTokens.surfaceAdaptive)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                .stroke(ColorTokens.borderAdaptive, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func uploadedByTeacherSection() -> some View {
        let teacherItems = teacherLessons

        if !teacherItems.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("Uploaded by Teacher")
                    .font(Typography.heading3)
                    .foregroundColor(ColorTokens.textPrimaryAdaptive)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.medium) {
                        ForEach(teacherItems) { item in
                            TeacherLessonCard(item: item) {
                                haptics.tapSelection()
                                selectedLesson = item
                            }
                        }
                    }
                    .padding(.vertical, Spacing.xSmall)
                }
            }
        }
    }

    private var teacherLessons: [LessonIndexItem] {
        var items: [LessonIndexItem] = []
        if let seed = lessonStore.teacherSeed {
            items.append(seed)
        }
        items.append(contentsOf: lessonStore.recent.filter { $0.teacher != nil && $0.id != lessonStore.teacherSeed?.id })
        return items
    }

    private func recentsSection() -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Recent Activity")
                .font(Typography.heading3)
                .foregroundColor(ColorTokens.textPrimaryAdaptive)

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

    private func bannerTitle(for item: LessonIndexItem) -> String {
        if let t = item.teacher, !t.isEmpty {
            return "New document from \(t)"
        } else {
            return "Your converted file is ready"
        }
    }
}

// MARK: - Teacher lesson card

private struct TeacherLessonCard: View {
    let item: LessonIndexItem
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .top, spacing: Spacing.small) {
                Image(systemName: "doc.richtext")
                    .foregroundColor(ColorTokens.secondaryPink)
                    .padding(8)
                    .background(ColorTokens.secondaryPinkLight3)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(Typography.bodyBold)
                        .foregroundColor(ColorTokens.textPrimaryAdaptive)
                        .lineLimit(2)

                    if let teacher = item.teacher {
                        Text("Teacher \(teacher)")
                            .font(Typography.caption1)
                            .foregroundColor(ColorTokens.textSecondaryAdaptive)
                    }

                    Text(item.createdAt, style: .relative)
                        .font(Typography.caption1)
                        .foregroundColor(ColorTokens.textSecondaryAdaptive)
                }
            }

            Button("Open") {
                onOpen()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Spacing.medium)
        .frame(width: 220)
        .background(ColorTokens.surfaceAdaptive)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge))
        .shadow(radius: 1, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to open lesson")
    }
}

// MARK: - Recent row (list style)

private struct RecentRow: View {
    let item: LessonIndexItem

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "doc.text")
                .foregroundColor(ColorTokens.primary)
                .padding(8)
                .background(ColorTokens.primaryLight3)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Typography.body)
                    .foregroundColor(ColorTokens.textPrimaryAdaptive)
                    .lineLimit(1)

                Text(item.createdAt, style: .relative)
                    .font(Typography.caption1)
                    .foregroundColor(ColorTokens.textSecondaryAdaptive)
            }

            Spacer()

            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .foregroundColor(ColorTokens.textSecondaryAdaptive)
                .accessibilityHidden(true)
        }
        .padding(Spacing.small)
        .background(ColorTokens.surfaceAdaptive2)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to open document")
    }
}

// MARK: - Bottom Tab Bar

private struct HomeTabBar: View {
    @Binding var selectedTab: DashboardView.HomeTab

    var body: some View {
        HStack(spacing: Spacing.xxxLarge) {
            tabButton(tab: .accessibility,
                      icon: "questionmark.circle",
                      label: "Accessibility")

            tabButton(tab: .home,
                      icon: "house.fill",
                      label: "Home")

            tabButton(tab: .allFiles,
                      icon: "doc.on.doc",
                      label: "All files")
        }
        .padding(.horizontal, Spacing.large)
        .padding(.top, Spacing.small)
        .padding(.bottom, Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(ColorTokens.surfaceAdaptive.shadow(radius: 4))
    }

    private func tabButton(tab: DashboardView.HomeTab,
                           icon: String,
                           label: String) -> some View {
        let isSelected = (tab == selectedTab)

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(
                        isSelected ? ColorTokens.primary : ColorTokens.textSecondaryAdaptive
                    )

                Text(label)
                    .font(Typography.navBar)
                    .foregroundColor(
                        isSelected ? ColorTokens.primary : ColorTokens.textSecondaryAdaptive
                    )
            }
            .padding(.vertical, 4)
            .frame(width: 80)
            .background(
                isSelected
                ? ColorTokens.primaryLight3.opacity(0.6)
                : Color.clear
            )
            .clipShape(Capsule())
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}


// MARK: - Reader container

private struct ReaderContainer: View {
    @EnvironmentObject var lessonStore: LessonStore
    let item: LessonIndexItem

    var body: some View {
        // Build worksheet pages (1 JSON file = 1 page)
        let pages = WorksheetLoader.loadPages(
            lessonStore: lessonStore,
            filenames: item.localFiles
        )

        if !pages.isEmpty {
            // Worksheet style (swipe Page 1 / Page 2, etc.)
            WorksheetView(title: item.title, pages: pages)
        } else {
            // Fallback: simple continuous reader
            let nodes = lessonStore.loadNodes(forFilenames: item.localFiles)
            DocumentRendererView(title: item.title, nodes: nodes)
        }
    }
}
