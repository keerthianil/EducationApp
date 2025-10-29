//
//  LoginView.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//
import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var vm = LoginViewModel()
    @State private var rememberMe = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ScreenHeader(title: vm.mode == .login ? "Welcome back" : "Create account")

                Segmented(selection: $vm.mode, options: AuthMode.allCases)

                VStack(spacing: Theme.Spacing.md) {
                    TextField("Email", text: $vm.email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .submitLabel(.next)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).stroke(.secondary))
                        .accessibilityLabel("Email address")

                    SecureField("Password", text: $vm.password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).stroke(.secondary))
                        .accessibilityLabel("Password")

                    Toggle(isOn: $rememberMe) { Text("Remember me") }.toggleStyle(.switch)
                }

                Button(vm.mode == .login ? "Login" : "Create Account") {
                    app.route = .profileName
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!vm.isFormValid)
                .accessibilityHint("Proceeds to profile setup")

                HStack {
                    Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                    Text("OR").foregroundColor(.secondary)
                    Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                }
                .accessibilityHidden(true)

                Button {
                    app.route = .profileName // Placeholder for Google
                } label: {
                    Label("Continue with Google", systemImage: "g.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityHint("Uses Google to sign in")
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    app.route = .about
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .accessibilityLabel("Back")
                .accessibilityHint("Goes to About")
            }
        }
    }
}
