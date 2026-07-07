import Supabase
import SwiftUI

struct AuthView: View {
    private enum Mode: String, CaseIterable {
        case signIn = "Sign in"
        case signUp = "Sign up"
    }

    private enum JoinKind: String, CaseIterable {
        case invite = "I have an invite code"
        case company = "New company"
    }

    @State private var mode: Mode = .signIn
    @State private var joinKind: JoinKind = .invite

    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var inviteCode = ""
    @State private var companyName = ""

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                        Text("Ventline")
                            .font(.largeTitle.bold())
                        Text("Job-site updates without the group-chat chaos.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 12) {
                        if mode == .signUp {
                            field("Your name", text: $fullName, contentType: .name)
                        }
                        field("Email", text: $email, contentType: .emailAddress, keyboard: .emailAddress)
                        SecureField("Password", text: $password)
                            .textContentType(mode == .signUp ? .newPassword : .password)
                            .fieldStyle()

                        if mode == .signUp {
                            Picker("Join", selection: $joinKind) {
                                ForEach(JoinKind.allCases, id: \.self) { kind in
                                    Text(kind.rawValue).tag(kind)
                                }
                            }
                            .pickerStyle(.segmented)

                            switch joinKind {
                            case .invite:
                                field("Invite code", text: $inviteCode)
                                    .textInputAutocapitalization(.characters)
                            case .company:
                                field("Company name", text: $companyName)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        submit()
                    } label: {
                        Group {
                            if isWorking {
                                ProgressView()
                            } else {
                                Text(mode.rawValue)
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking || email.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func field(
        _ placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType? = nil,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text)
            .textContentType(contentType)
            .keyboardType(keyboard)
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            .autocorrectionDisabled()
            .fieldStyle()
    }

    private func submit() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                switch mode {
                case .signIn:
                    _ = try await Supa.client.auth.signIn(email: email, password: password)
                case .signUp:
                    var data: [String: AnyJSON] = [:]
                    if !fullName.isEmpty {
                        data["full_name"] = .string(fullName)
                    }
                    switch joinKind {
                    case .invite:
                        if !inviteCode.isEmpty {
                            data["invite_code"] = .string(inviteCode.uppercased().trimmingCharacters(in: .whitespaces))
                        }
                    case .company:
                        if !companyName.isEmpty {
                            data["company_name"] = .string(companyName)
                        }
                    }
                    _ = try await Supa.client.auth.signUp(email: email, password: password, data: data)
                }
                // AppState's authStateChanges stream takes over from here.
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
