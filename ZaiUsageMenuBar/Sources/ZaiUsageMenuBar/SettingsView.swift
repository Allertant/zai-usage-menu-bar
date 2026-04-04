import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("anthropicAuthToken") private var authToken: String = ""
    @AppStorage("preferredLanguage") private var preferredLanguage: String = "system"
    
    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section(L10n.localized("language")) {
                    Picker(L10n.localized("language"), selection: $preferredLanguage) {
                        Text(L10n.localized("system_default")).tag("system")
                        Text("English").tag("en")
                        Text("简体中文").tag("zh-Hans")
                    }
                }
                
                Section(L10n.localized("api_config")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.localized("base_url"))
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("https://open.bigmodel.cn/api/anthropic")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.localized("auth_token"))
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        SecureField(L10n.localized("auth_token_placeholder"), text: $authToken)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            
            HStack {
                Spacer()
                
                Button(L10n.localized("done")) {
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}
