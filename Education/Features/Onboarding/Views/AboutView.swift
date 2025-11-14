import SwiftUI

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
    
    var body: some View {
        ZStack {
            ColorTokens.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                customNavigationBar
                
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
    }
    
    // MARK: - Custom Navigation Bar
    
    private var customNavigationBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "arrow.left")
                    .font(.title2)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            .accessibilityHint("Returns to previous screen")
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ColorTokens.background)
    }
    
    // MARK: - Logo Section
    
    private var logoSection: some View {
        VStack(spacing: 8) {
            Text("STEMA11Y")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(ColorTokens.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }
    
    // MARK: - Illustration Section
    
    private var illustrationSection: some View {
        VStack(spacing: 0) {
            Image("speech-bubble-outline")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: bubbleMaxWidth)
                .accessibilityLabel("Information bubble")
                .accessibilityHint("Visual decoration")
            
            Image("onboarding-illustration")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: illustrationMaxWidth, maxHeight: illustrationMaxHeight)
                .offset(y: illustrationOffset)
                .accessibilityLabel("Person using laptop")
                .accessibilityHint("Illustration showing accessible learning")
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
        .accessibilityLabel("Get Started")
        .accessibilityHint("Navigate to sign in screen")
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