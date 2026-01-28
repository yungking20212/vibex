//
//  AuthView.swift
//  vibex
//
//  Created by Kendall Gipson on 1/23/26.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var mode: Mode = .signIn

    enum Mode { case signIn, signUp }

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo/Title
                VStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                    
                    Text("VibeX")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Share Your Vibe")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Auth Form
                VStack(spacing: 20) {
                    // Mode Picker
                    Picker("", selection: $mode) {
                        Text("Sign In").tag(Mode.signIn)
                        Text("Sign Up").tag(Mode.signUp)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Input Fields
                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textFieldStyle(CustomTextFieldStyle())
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(CustomTextFieldStyle())
                        
                        if mode == .signUp {
                            TextField("Username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let err = auth.authError {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .padding(.horizontal)
                    }
                    
                    // Submit Button
                    Button {
                        Task {
                            if mode == .signIn {
                                await auth.signIn(email: email, password: password)
                            } else {
                                await auth.signUp(email: email, password: password, username: username)
                            }
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .frame(height: 56)
                            
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text(mode == .signIn ? "Sign In" : "Create Account")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .disabled(auth.isLoading || email.isEmpty || password.isEmpty || (mode == .signUp && username.isEmpty))
                    .padding(.horizontal)
                }
                .padding(.vertical, 32)
                .background(Color.black.opacity(0.3))
                .cornerRadius(24)
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.9))
            .cornerRadius(12)
            .foregroundColor(.black)
    }
}

// MARK: - Preview

#Preview {
    AuthView()
        .environmentObject(AuthManager.shared)
}
