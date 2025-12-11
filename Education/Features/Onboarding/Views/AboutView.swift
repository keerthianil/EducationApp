import SwiftUI
import UIKit

struct AboutView: View {
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // MARK: - Computed Properties
    
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }
    
    // MARK: - Body
    @State private var didAnnounceWelcome: Bool = false
    @AccessibilityFocusState private var getStartedFocused: Bool

    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                VStack(spacing: 0) {
                    logoSection
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    illustrationSection
                    
                    Spacer()
                    
                    getStartedButton
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Announce welcome once, then move VoiceOver focus to the primary button
            guard !didAnnounceWelcome else { return }
            didAnnounceWelcome = true

            UIAccessibility.post(notification: .announcement, argument: "Welcome to STEMA11Y")

            // Small delay so welcome finishes and VO doesn't overlap, then set focus to the button.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                getStartedFocused = true
            }
        }
    }
    
    
    
    // MARK: - Logo Section
    
    private var logoSection: some View {
        VStack(spacing: 8) {
            Text("STEMA11Y")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(ColorTokens.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("STEMA11Y")
                .accessibilityHint("Welcome")
        }
    }
    
    // MARK: - Illustration Section
    
    private var illustrationSection: some View {
        VStack(spacing: 0) {
            // Decorative artwork — hide from VoiceOver to avoid noisy announcements
            Image("speech-bubble-outline")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: bubbleMaxWidth)
                .accessibilityHidden(true)
            
            // Illustration provides meaningful context — give a short, concise label for VO
            Image("onboarding-illustration")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: illustrationMaxWidth, maxHeight: illustrationMaxHeight)
                .offset(y: illustrationOffset)
                .accessibilityLabel("Illustration: student using a laptop")
                .accessibilityHint("Decorative illustration")
        }
    }
    
    // MARK: - Get Started Button
    
    private var getStartedButton: some View {
        NavigationLink {
            AuthenticationView()
        } label: {
            Text("Get Started")
                .font(.headline)
                .foregroundStyle(ColorTokens.textLight)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(ColorTokens.primary)
                )
        }
        .padding(.horizontal, buttonHorizontalPadding)
        .padding(.bottom, 32)
        .padding(.top, 16)
        // Make the button the primary actionable element for VO users
        .accessibilityLabel("Get Started")
        .accessibilityHint("Opens sign in screen")
        .accessibilitySortPriority(1)
    }
    
    // MARK: - Responsive Sizing
    
    private var bubbleMaxWidth: CGFloat {
        if horizontalSizeClass == .regular {
            return 500
        } else {
            return UIScreen.main.bounds.width * 0.85
        }
    }
    
    private var illustrationMaxWidth: CGFloat {
        if horizontalSizeClass == .regular {
            return 350
        } else {
            return UIScreen.main.bounds.width * 0.6
        }
    }
    
    private var illustrationMaxHeight: CGFloat {
        if horizontalSizeClass == .regular {
            return 350
        } else {
            return 250
        }
    }
    
    private var illustrationOffset: CGFloat {
        if horizontalSizeClass == .regular {
            return -40
        } else if UIScreen.main.bounds.height < 700 {
            return -20
        } else {
            return -30
        }
    }
    
    private var buttonHorizontalPadding: CGFloat {
        if horizontalSizeClass == .regular {
            return 64
        } else {
            return 32
        }
    }
}

// MARK: - Previews

#Preview("iPhone 15 Pro") {
    NavigationStack {
        AboutView()
    }
}

#Preview("iPhone SE") {
    NavigationStack {
        AboutView()
    }
    .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("iPad Pro") {
    NavigationStack {
        AboutView()
    }
    .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
}
