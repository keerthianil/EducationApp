import SwiftUI
import UIKit

struct AgeQuestionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGroup: AgeGroup? = nil
    @State private var errorMessage: String? = nil
    @State private var showIntroOnboarding = false
    @State private var didAnnounceAgeScreen: Bool = false
    @AccessibilityFocusState private var firstOptionFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white
                .ignoresSafeArea()
            
            // Hidden navigation to IntroOnboardingView
            NavigationLink(
                destination: IntroOnboardingView(),
                isActive: $showIntroOnboarding
            ) {
                EmptyView()
            }
            .hidden()
            
            VStack(alignment: .leading, spacing: 24) {
                
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .accessibilityLabel("Back")
                    .accessibilityHint("Go back to the name question")
                    
                    DSOnboardingProgress(
                        totalSteps: 2,
                        currentStep: 2,
                        activeColor: ColorTokens.primary
                    )
                    .accessibilityLabel("Step 2 of 2")
                    .accessibilitySortPriority(2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer().frame(height: 32)
                
                Text("Q. What’s your age?")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel("What is your age?")
                
                VStack(spacing: 16) {
                    ForEach(AgeGroup.allCases, id: \.self) { group in
                        if group == AgeGroup.allCases.first {
                            DSSelectableOptionRow(
                                title: group.displayText,
                                isSelected: selectedGroup == group
                            )
                            .onTapGesture {
                                selectedGroup = group
                                errorMessage = nil
                            }
                            // Focus the first option for VoiceOver users when screen appears
                            .accessibilityFocused($firstOptionFocused)
                        } else {
                            DSSelectableOptionRow(
                                title: group.displayText,
                                isSelected: selectedGroup == group
                            )
                            .onTapGesture {
                                selectedGroup = group
                                errorMessage = nil
                            }
                        }
                    }
                    if let msg = errorMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                            .accessibilityLabel(msg)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                            Text("Prev")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ColorTokens.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(ColorTokens.primary, lineWidth: 1)
                        )
                    }
                    .accessibilityLabel("Previous")
                    .accessibilityHint("Go back to the name question")
                    
                    Spacer()
                    
                    Button {
                        validateAndContinue()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(ColorTokens.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .accessibilityLabel("Next")
                    .accessibilityHint("Continue to the introduction screen")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard !didAnnounceAgeScreen else { return }
            didAnnounceAgeScreen = true

            // Announce progress first, then the question so VO users know which step they're on.
            UIAccessibility.post(notification: .announcement, argument: "Step 2 of 2. What is your age? You can select an age group or skip this step")

            // Slightly longer delay so the announcement is heard before focus changes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                firstOptionFocused = true
            }
        }
    }
    
    private func validateAndContinue() {
        // Age selection is optional for now — proceed regardless.
        errorMessage = nil
        showIntroOnboarding = true
    }
}

// MARK: - AgeGroup model

enum AgeGroup: CaseIterable, Identifiable {
    case middleSchool    // 8–12
    case highSchool      // 12–18
    case adult           // 18–45
    case veteran         // 45+
    
    var id: Self { self }
    
    var displayText: String {
        switch self {
        case .middleSchool: return "( 8–12 Yrs )  Middle School"
        case .highSchool:   return "( 12–18 Yrs )  High School"
        case .adult:        return "( 18–45 Yrs )  Adult"
        case .veteran:      return "( 45+ Yrs )  Veteran"
        }
    }
    
    var title: String {
        switch self {
        case .middleSchool: return "Middle School"
        case .highSchool:   return "High School"
        case .adult:        return "Adult"
        case .veteran:      return "Veteran"
        }
    }
}

#Preview {
    NavigationStack {
        AgeQuestionView()
    }
}