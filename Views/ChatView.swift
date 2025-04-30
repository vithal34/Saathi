import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentInput: String = ""
    @Published var isLoading: Bool = false
    
    func sendMessage() {
        guard !currentInput.isEmpty else { return }
        
        let userMessage = Message(text: currentInput, isUser: true)
        messages.append(userMessage)
        
        isLoading = true
        currentInput = ""
        
        // TODO: Integrate with AI API (ChatGPT/Claude/Gemini)
        // This is a placeholder response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let aiResponse = Message(
                text: "I'm analyzing your symptoms. Could you please provide more details about your condition?",
                isUser: false
            )
            self.messages.append(aiResponse)
            self.isLoading = false
        }
    }
}

struct ChatView: View {
    @StateObject private var aiService = AIService(apiKey: "YOUR_API_KEY", provider: .chatGPT)
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var selectedLanguage = "English"
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            // Language selector
            Picker("Language", selection: $selectedLanguage) {
                Text("English").tag("English")
                Text("हिंदी").tag("Hindi")
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Chat messages
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
            }
            
            // Input area
            HStack {
                TextField(selectedLanguage == "English" ? "Type your message..." : "अपना संदेश टाइप करें...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                .disabled(newMessage.isEmpty || isLoading)
            }
            .padding()
        }
        .navigationTitle("Saathi Health Assistant")
    }
    
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        
        let userMessage = Message(text: newMessage, isUser: true)
        messages.append(userMessage)
        
        isLoading = true
        newMessage = ""
        
        Task {
            do {
                let response = try await aiService.generateResponse(
                    prompt: userMessage.text,
                    language: selectedLanguage
                )
                
                let aiMessage = Message(text: response, isUser: false)
                messages.append(aiMessage)
            } catch {
                // Handle error
                print("Error: \(error)")
            }
            
            isLoading = false
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.text)
                .padding()
                .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(16)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatView()
        }
    }
} 