import SwiftUI

struct AISettingsView: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var baseURL: String = AINetworkClient.shared.baseURL?.absoluteString ?? ""
    @State private var bearerToken: String = AINetworkClient.shared.bearerToken ?? ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI Endpoint")) {
                    TextField("https://api.example.com", text: $baseURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                Section(header: Text("Bearer Token")) {
                    SecureField("Bearer token (optional)", text: $bearerToken)
                }

                Section {
                    Button(action: save) {
                        HStack {
                            Spacer()
                            Text("Save")
                            Spacer()
                        }
                    }

                    Button(role: .destructive, action: clear) {
                        HStack {
                            Spacer()
                            Text("Clear stored values")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("AI Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    private func save() {
        let urlString = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        AINetworkClient.shared.configure(baseURLString: urlString.isEmpty ? nil : urlString,
                                         bearerToken: token.isEmpty ? nil : token)
        presentationMode.wrappedValue.dismiss()
    }

    private func clear() {
        baseURL = ""
        bearerToken = ""
        AINetworkClient.shared.configure(baseURLString: nil, bearerToken: nil)
        presentationMode.wrappedValue.dismiss()
    }
}

struct AISettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AISettingsView()
    }
}
