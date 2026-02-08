//
//  AuthenticationView.swift
//  Education
//

import SwiftUI
import UIKit

struct AuthenticationView: View {
    @State private var isLoginMode = true
    @State private var email = "test@example.com"
    @State private var password = "password123"
    @State private var confirmPassword = "password123"
    @State private var rememberMe = false
    @State private var showPassword = false
    @State private var errorMessage: String?
    @State private var didAnnounceAuth: Bool = false
    @AccessibilityFocusState private var emailFieldFocused: Bool
    
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

            NavigationLink(
                destination: NameQuestionView(),
                isActive: $goToNameScreen
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationBarBackButtonHidden(true)
        .onThreeFingerSwipeBack { dismiss() }
        .onAppear {
            guard !didAnnounceAuth else { return }
            didAnnounceAuth = true

            UIAccessibility.post(notification: .announcement, argument: isLoginMode ? "Sign in" : "Register")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                emailFieldFocused = true
            }
        }
    }

    private var headerImageSection: some View {
        ZStack(alignment: .topLeading) {
            Image("login-header")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .clipped()
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
                        .font(.custom("Arial", size: 14))
                }
                .accessibilityLabel("Login")
                .accessibilityAddTraits(isLoginMode ? .isSelected : [])

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
                        .font(.custom("Arial", size: 14))
                }
                .accessibilityLabel("Register")
                .accessibilityAddTraits(!isLoginMode ? .isSelected : [])
            }
        }
        .frame(height: 48)
    }

    private var emailField: some View {
        TextField("Email", text: $email)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .font(.custom("Arial", size: 14))
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
            .font(.custom("Arial", size: 14))

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
    }

    private var confirmPasswordField: some View {
        SecureField("Confirm Password", text: $confirmPassword)
            .font(.custom("Arial", size: 14))
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(ColorTokens.authCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ColorTokens.authFieldBorder, lineWidth: 1)
            )
    }

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
                        .font(.custom("Arial", size: 14).weight(.medium))
                        .foregroundStyle(ColorTokens.textPrimary)
                }
            }
            .accessibilityValue(rememberMe ? "Checked" : "Unchecked")

            Spacer()

            Button {
                // Forgot password
            } label: {
                Text("Forgot Password?")
                    .font(.custom("Arial", size: 14).weight(.medium))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
        }
    }

    private var submitButton: some View {
        Button {
            handleAuthentication()
        } label: {
            Text(isLoginMode ? "Login" : "Register")
                .font(.custom("Arial", size: 14).weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(ColorTokens.primary)
                .cornerRadius(8)
        }
        .accessibilityLabel(isLoginMode ? "Login" : "Register")
        .accessibilitySortPriority(1)
    }

    private var orDivider: some View {
        HStack {
            Rectangle().fill(ColorTokens.authDivider).frame(height: 1)
            Text("OR")
                .font(.custom("Arial", size: 14))
                .foregroundStyle(ColorTokens.textPrimary)
            Rectangle().fill(ColorTokens.authDivider).frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Google Button (Fixed per design critique)
    private var googleButton: some View {
        Button {
            // Google sign-in
        } label: {
            HStack(spacing: 12) {
                // Official Google "G" icon - centered
                Image("google-g-icon") // Add this asset or use SF Symbol
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                
                Text("Continue with Google")
                    .font(.custom("Arial", size: 14))
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

    private func handleAuthentication() {
        errorMessage = nil
        goToNameScreen = true
    }
}
