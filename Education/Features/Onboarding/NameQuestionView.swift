import SwiftUI
import UIKit

struct NameQuestionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var errorMessage: String? = nil
    @State private var goToAgeScreen: Bool = false
    @State private var didAnnounceNameScreen: Bool = false
    @AccessibilityFocusState private var nameFieldFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white
                .ignoresSafeArea()
            
            // Hidden navigation to AgeQuestionView
            NavigationLink(
                destination: AgeQuestionView(),
                isActive: $goToAgeScreen
            ) {
                EmptyView()
            }
            .hidden()
            
            VStack(alignment: .leading, spacing: 32) {
                
                // Top bar: back + progress
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .accessibilityLabel("Back")
                    .accessibilityHint("Go back to authentication")
                    
                    DSOnboardingProgress(
                        totalSteps: 2,
                        currentStep: 1,
                        activeColor: ColorTokens.primary
                    )
                    .accessibilityLabel("Step 1 of 2")
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer().frame(height: 40)
                
                Text("Q. What’s your name?")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel("What is your name?")

                
                VStack(spacing: 6) {
                    TextField("Your name", text: $name)
                        .font(.system(size: 16))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 24)
                        .accessibilityLabel("Name")
                        .accessibilityHint("Enter your name. Optional — double tap Next to skip")
                        .accessibilityFocused($nameFieldFocused)
                    
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 1)
                        .padding(.horizontal, 60)
                        .accessibilityHidden(true)
                    
                    if let msg = errorMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityLabel(msg)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
                
                Spacer()
            }
            
            Button(action: validateAndProceed) {
                HStack(spacing: 6) {
                    Text("Next")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(ColorTokens.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.trailing, 24)
            .padding(.bottom, 32)
            .accessibilityLabel("Next")
            .accessibilityHint("Continue to the age question")
            .accessibilitySortPriority(1)
        }
        .navigationBarBackButtonHidden(true)
        .onThreeFingerSwipeBack { dismiss() }
        .onAppear {
            guard !didAnnounceNameScreen else { return }
            didAnnounceNameScreen = true

            // Brief announcement and focus name field for quick input; name is optional
            UIAccessibility.post(notification: .announcement, argument: "What is your name?")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                nameFieldFocused = true
            }
        }
    }
    
    private func validateAndProceed() {
        // Name is optional for now — proceed regardless.
        errorMessage = nil
        goToAgeScreen = true
    }
}

#Preview {
    NavigationStack {
        NameQuestionView()
    }
}