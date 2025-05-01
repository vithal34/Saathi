import SwiftUI

struct APIKeyView: View {
    @State private var apiKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("OpenAI API Key"), footer: Text("Your API key is stored securely on your device.")) {
                    SecureField("Enter your OpenAI API key", text: $apiKey)
                }
                
                Section {
                    Button("Save API Key") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
            .navigationTitle("API Settings")
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
            .alert("API Key", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("successfully") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                // Load existing API key if available
                if let existingKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey") {
                    apiKey = existingKey
                }
            }
        }
    }
    
    private func saveAPIKey() {
        // Validate the API key format
        guard apiKey.starts(with: "sk-") else {
            alertMessage = "Invalid API key format. OpenAI API keys start with 'sk-'"
            showingAlert = true
            return
        }
        
        // Save the API key
        AIService.shared.setAPIKey(apiKey)
        alertMessage = "API key saved successfully"
        showingAlert = true
    }
}

struct APIKeyView_Previews: PreviewProvider {
    static var previews: some View {
        APIKeyView()
    }
} 