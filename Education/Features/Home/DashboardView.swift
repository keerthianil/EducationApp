//
//  DashboardView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var lessonStore: LessonStore
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var mathSpeech: MathSpeechService

    @State private var showUpload = false
    @State private var openLesson: LessonIndexItem?

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.large) {

                        // UC1 banner
                        if let first = lessonStore.recent.first {
                            NotificationBannerView(
                                title: "New document from \(first.teacher ?? "your teacher")",
                                subtitle: first.title
                            ) {
                                haptics.success()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    openLesson = first
                                }
                            }
                            .accessibilityAddTraits(.isButton)
                            .padding(.top, Spacing.large)
                        }

                        // Upload card
                        VStack(spacing: Spacing.small) {
                            Image(systemName: "icloud.and.arrow.up.fill")
                                .font(.largeTitle)
                                .foregroundColor(ColorTokens.primary)

                            Text("Upload Your Files").font(Typography.heading2)
                            Text("Browse files or scan")
                                .font(Typography.subheadline)
                                .foregroundColor(ColorTokens.textSecondary)

                            Button("Browse files") { showUpload = true }
                                .buttonStyle(PrimaryButtonStyle())

                            Button("Scan files") {}    // stubbed
                                .buttonStyle(SecondaryButtonStyle())
                                .disabled(true)
                                .accessibilityHint("Not available in demo")
                        }
                        .padding()
                        .background(ColorTokens.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))

                        // Uploaded by Teacher (visual card)
                        if let first = lessonStore.recent.first {
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("Uploaded by Teacher").font(Typography.heading3)
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(first.title).font(Typography.bodyBold)
                                        Text("Teacher: \(first.teacher ?? "")")
                                            .font(Typography.caption1)
                                            .foregroundColor(ColorTokens.textSecondary)
                                    }
                                    Spacer()
                                    Button("Open") { openLesson = first }
                                        .buttonStyle(PrimaryButtonStyle())
                                        .frame(width: 120)
                                }
                                .padding()
                                .background(ColorTokens.surface1)
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
                            }
                        }

                        // Downloaded (from Upload flow)
                        if !lessonStore.downloaded.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("Downloaded").font(Typography.heading3)
                                ForEach(lessonStore.downloaded) { item in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(item.title).font(Typography.bodyBold)
                                            Text("Ready to open")
                                                .font(Typography.caption1)
                                                .foregroundColor(ColorTokens.textSecondary)
                                        }
                                        Spacer()
                                        Button("Open") { openLesson = item }
                                            .buttonStyle(PrimaryButtonStyle())
                                            .frame(width: 120)
                                    }
                                    .padding(Spacing.small)
                                    .background(ColorTokens.surface1)
                                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
                                }
                            }
                        }

                        // Recent Activity (static demo)
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Text("Recent Activity").font(Typography.heading3)
                            RecentActivityRow(filename: "Calculus Homework.pdf", when: "Opened 3h ago")
                            RecentActivityRow(filename: "Lab_Results_Scan.jpg", when: "Opened yesterday")
                            RecentActivityRow(filename: "Spanish_Lecture_03.mp3", when: "Opened 4 days ago")
                        }
                    }
                    .padding(Spacing.screenPadding)
                }
            }
            .sheet(isPresented: $showUpload) { UploadSheetView() }
            .navigationDestination(item: $openLesson) { item in
                let nodes = lessonStore.loadNodes(forFilenames: item.localFiles)
                DocumentRendererView(title: item.title, nodes: nodes)
            }
            .navigationTitle("Home")
        }
    }
}
