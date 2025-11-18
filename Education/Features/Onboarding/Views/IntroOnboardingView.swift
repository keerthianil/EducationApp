import SwiftUI
import UIKit

struct IntroOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Fake slides for now – you can customize titles/images later
    private let slides: [OnboardingSlide] = [
        .init(image: "appicon", title: "Welcome to STEMA11Y", desc: dummyText),
        .init(image: "appicon", title: "Learn Anything Easily", desc: dummyText),
        .init(image: "appicon", title: "Your Learning Companion", desc: dummyText)
    ]
    
    @State private var currentIndex = 0
    @State private var goToDashboard = false
    @State private var didAnnounceOnboarding: Bool = false
    @AccessibilityFocusState private var slideFocused: Bool
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            // Nav to Dashboard
            NavigationLink(
                destination: DashboardView(),
                isActive: $goToDashboard
            ) {
                EmptyView()
            }
            .hidden()
            
            VStack(spacing: 24) {
                
                HStack(alignment: .center) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .accessibilityLabel("Back")
                    .accessibilityHint("Go back to the age question")
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image("appicon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .accessibilityHidden(true)
                        
                        Text("STEMA11Y")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    Spacer().frame(width: 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                DSOnboardingSlide(
                    imageName: slides[currentIndex].image,
                    title: slides[currentIndex].title,
                    description: slides[currentIndex].desc
                )
                .accessibilityFocused($slideFocused)
                .accessibilityLabel(slides[currentIndex].title)
                .accessibilityHint("Double tap to hear more or swipe for description")
                
                DSPageIndicator(
                    totalPages: slides.count,
                    currentPage: currentIndex,
                    activeColor: .black,
                    inactiveColor: Color.gray.opacity(0.4)
                )
                .padding(.top, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(currentIndex + 1) of \(slides.count)")
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button {
                        handleNext()
                    } label: {
                        Text("Next")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(ColorTokens.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel(
                        currentIndex == slides.count - 1
                        ? "Finish onboarding and go to dashboard"
                        : "Next slide"
                    )
                    .accessibilitySortPriority(1)
                    
                    Button {
                        goToDashboard = true
                    } label: {
                        Text("Skip")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ColorTokens.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ColorTokens.primary, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Skip onboarding and go to dashboard")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Announce first slide once and move focus to the slide title
            guard !didAnnounceOnboarding else { return }
            didAnnounceOnboarding = true

            UIAccessibility.post(notification: .announcement, argument: slides[currentIndex].title)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                slideFocused = true
            }
        }
        .onChange(of: currentIndex) { newIndex in
            // Announce the new slide title and focus it
            UIAccessibility.post(notification: .announcement, argument: slides[newIndex].title)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                slideFocused = true
            }
        }
    }
    
    private func handleNext() {
        if currentIndex < slides.count - 1 {
            currentIndex += 1
        } else {
            goToDashboard = true
        }
    }
}

private struct OnboardingSlide {
    let image: String
    let title: String
    let desc: String
}

private let dummyText =
"""
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim. Dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
"""

#Preview {
    NavigationStack {
        IntroOnboardingView()
    }
}
