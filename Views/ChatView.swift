import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentInput: String = ""
    @Published var isLoading: Bool = false
    
    func sendMessage() {
        guard !currentInput.isEmpty else { return }
        
        let userMessage = Message(content: currentInput, isUser: true, timestamp: Date())
        messages.append(userMessage)
        
        isLoading = true
        currentInput = ""
        
        // TODO: Integrate with AI API (ChatGPT/Claude/Gemini)
        // This is a placeholder response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let aiResponse = Message(
                content: "I'm analyzing your symptoms. Could you please provide more details about your condition?",
                isUser: false,
                timestamp: Date()
            )
            self.messages.append(aiResponse)
            self.isLoading = false
        }
    }
}

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            HStack {
                TextField("Type your message...", text: $viewModel.currentInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: {
                    viewModel.sendMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .padding(.trailing)
                .disabled(viewModel.isLoading)
            }
            .padding(.vertical)
            .background(colorScheme == .dark ? Color.black : Color.white)
            .shadow(radius: 1)
        }
        .navigationTitle("AI Assistant")
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.content)
                .padding()
                .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(15)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

#Preview {
    ChatView()
} 