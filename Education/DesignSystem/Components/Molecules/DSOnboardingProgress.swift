import SwiftUI

/// Segmented progress bar for onboarding / question flows.
/// Example: DSOnboardingProgress(totalSteps: 2, currentStep: 1)
struct DSOnboardingProgress: View {
    let totalSteps: Int
    let currentStep: Int
    
    var activeColor: Color = ColorTokens.primary
    var inactiveColor: Color = Color.gray.opacity(0.35)
    var height: CGFloat = 6
    var spacing: CGFloat = 8
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<totalSteps, id: \.self) { index in
                let isActive = index < currentStep
                
                Capsule()
                    .frame(height: height)
                    .foregroundColor(isActive ? activeColor : .clear)
                    .overlay(
                        Capsule()
                            .stroke(
                                isActive ? Color.clear : inactiveColor,
                                lineWidth: 1
                            )
                    )
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        DSOnboardingProgress(totalSteps: 2, currentStep: 1)
        DSOnboardingProgress(totalSteps: 4, currentStep: 3)
    }
    .padding()
}
