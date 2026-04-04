import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("anthropicAuthToken") private var authToken: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section("API Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base URL")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("https://open.bigmodel.cn/api/anthropic")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auth Token")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        SecureField("Your authentication token", text: $authToken)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            
            HStack {
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 160)
    }
}
