import SwiftUI

/// A single onboarding slide: logo in a rounded card + title + description.
struct DSOnboardingSlide: View {
    let imageName: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Big rounded image card
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.black.opacity(0.7), lineWidth: 1)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color(.systemGray6))
                )
                .overlay(
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(30)
                        .accessibilityHidden(true)
                )
                .frame(height: 260)
                .padding(.horizontal, 32)
            
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DSOnboardingSlide(
        imageName: "appicon",
        title: "Lorem ipsum dolor sit amet",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit..."
    )
}
