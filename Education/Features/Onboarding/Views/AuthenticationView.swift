import SwiftUI
import UIKit

struct AuthenticationView: View {
    // MARK: - State
    @State private var isLoginMode = true
    @State private var email = "test@example.com"
    @State private var password = "password123"
    @State private var confirmPassword = "password123"
    @State private var rememberMe = false
    @State private var showPassword = false
    @State private var errorMessage: String?
    @State private var didAnnounceAuth: Bool = false
    @AccessibilityFocusState private var emailFieldFocused: Bool
    
    // Navigation to NameQuestionView
    @State private var goToNameScreen = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ColorTokens.authCardBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerImageSection
                authBottomSheet
                    .padding(.top, -24)
            }

            // Hidden navigation link to NameQuestionView
            NavigationLink(
                destination: NameQuestionView(),
                isActive: $goToNameScreen
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // VoiceOver: announce the screen once and move focus to the email field
            guard !didAnnounceAuth else { return }
            didAnnounceAuth = true

            UIAccessibility.post(notification: .announcement, argument: isLoginMode ? "Sign in" : "Register")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                emailFieldFocused = true
            }
        }
    }

    // MARK: - Header Image + Close Button
    private var headerImageSection: some View {
        ZStack(alignment: .topLeading) {
            Image("login-header")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()
                // Decorative header — hide from VoiceOver to avoid noisy announcements
                .accessibilityHidden(true)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.45))
                    )
            }
            .padding(.top, 16)
            .padding(.leading, 16)
            .accessibilityLabel("Close")
            .accessibilityHint("Dismiss authentication screen")
        }
    }

    // MARK: - Bottom Sheet
    private var authBottomSheet: some View {
        VStack(spacing: 24) {
            modeToggle

            VStack(spacing: 16) {
                emailField
                passwordField
                if !isLoginMode {
                    confirmPasswordField
                }

                if let msg = errorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(ColorTokens.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(msg)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }

            if isLoginMode {
                rememberForgotRow
            }

            submitButton
            orDivider
            googleButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .background(
            ZStack(alignment: .top) {
                ColorTokens.authCardBackground

                Rectangle()
                    .fill(Color.black.opacity(0.10))
                    .frame(height: 18)
                    .blur(radius: 8)
                    .offset(y: -10)
            }
        )
        .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Mode Toggle
    private var modeToggle: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(ColorTokens.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(ColorTokens.authFieldBorder, lineWidth: 1)
                )

            GeometryReader { geometry in
                let width = geometry.size.width / 2
                RoundedRectangle(cornerRadius: 24)
                    .fill(ColorTokens.authCardBackground)
                    .frame(width: width, height: 48)
                    .offset(x: isLoginMode ? 0 : width)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    .animation(.easeInOut(duration: 0.25), value: isLoginMode)
            }
            .frame(height: 48)

            HStack(spacing: 0) {
                Button {
                    withAnimation {
                        isLoginMode = true
                        errorMessage = nil
                    }
                } label: {
                    Text("Login")
                        .foregroundStyle(
                            isLoginMode ? ColorTokens.textPrimary
                                        : ColorTokens.authSecondaryText
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .font(.system(size: 12))
                }
                .accessibilityLabel("Login")
                .accessibilityAddTraits(isLoginMode ? .isSelected : [])
                .accessibilityHint(isLoginMode ? "Currently selected" : "Double tap to switch to Login")

                Button {
                    withAnimation {
                        isLoginMode = false
                        errorMessage = nil
                    }
                } label: {
                    Text("Register")
                        .foregroundStyle(
                            !isLoginMode ? ColorTokens.textPrimary
                                         : ColorTokens.authSecondaryText
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .font(.system(size: 12))
                }
                .accessibilityLabel("Register")
                .accessibilityAddTraits(!isLoginMode ? .isSelected : [])
                .accessibilityHint(!isLoginMode ? "Currently selected" : "Double tap to switch to Register")
            }
        }
        .frame(height: 48)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Authentication mode")
        .accessibilityValue(isLoginMode ? "Login" : "Register")
    }

    // MARK: - Fields
    private var emailField: some View {
        TextField("Email", text: $email)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(ColorTokens.authCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ColorTokens.authFieldBorder, lineWidth: 1)
            )
            .accessibilityLabel("Email")
            .accessibilityHint("Enter your email address")
            .accessibilityFocused($emailFieldFocused)
    }

    private var passwordField: some View {
        HStack {
            Group {
                if showPassword {
                    TextField("Password", text: $password)
                } else {
                    SecureField("Password", text: $password)
                }
            }
            .font(.system(size: 12))

            Button { showPassword.toggle() } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .accessibilityLabel(showPassword ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(ColorTokens.authCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorTokens.authFieldBorder, lineWidth: 1)
        )
        .accessibilityLabel("Password")
        .accessibilityHint("Enter your password")
    }

    private var confirmPasswordField: some View {
        SecureField("Confirm Password", text: $confirmPassword)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(ColorTokens.authCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ColorTokens.authFieldBorder, lineWidth: 1)
            )
            .accessibilityLabel("Confirm password")
            .accessibilityHint("Re-enter your password")
    }

    // MARK: - Remember + Forgot
    private var rememberForgotRow: some View {
        HStack {
            Button { rememberMe.toggle() } label: {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(ColorTokens.authCheckboxBorder, lineWidth: 1)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(ColorTokens.primary)
                                .opacity(rememberMe ? 1 : 0)
                        )

                    Text("Remember me")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                }
            }
            .accessibilityLabel("Remember me")
            .accessibilityHint("Keep me signed in on this device")
            .accessibilityValue(rememberMe ? "Checked" : "Unchecked")

            Spacer()

            Button {
                // TODO: Forgot password flow
            } label: {
                Text("Forgot Password?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            .accessibilityLabel("Forgot password")
        }
    }

    // MARK: - Submit Button
    private var submitButton: some View {
        Button {
            handleAuthentication()
        } label: {
            Text(isLoginMode ? "Login" : "Register")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTokens.textLight)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(ColorTokens.primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorTokens.primary, lineWidth: 1)
                )
                .cornerRadius(8)
        }
        .accessibilityLabel(isLoginMode ? "Login" : "Register")
        .accessibilityHint("Authenticate and continue")
        .accessibilitySortPriority(1)
    }

    // MARK: - OR Divider
    private var orDivider: some View {
        HStack {
            Rectangle().fill(ColorTokens.authDivider).frame(height: 1)
            Text("OR")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textPrimary)
            Rectangle().fill(ColorTokens.authDivider).frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Google Button
    private var googleButton: some View {
        Button {
            // TODO: Google sign-in logic
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "g.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
                Text("Continue with Google")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(ColorTokens.authCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ColorTokens.authFieldBorder, lineWidth: 1)
            )
        }
        .accessibilityLabel("Continue with Google")
    }

    // MARK: - Validation + Auth + Navigation
    private func handleAuthentication() {
        // No validation for now — navigate directly.
        errorMessage = nil
        goToNameScreen = true
    }

    private func setError(_ message: String) {
        errorMessage = message
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
