import SwiftUI
import Speech

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentInput: String = ""
    @Published var isLoading: Bool = false
    @Published var selectedLanguage: Language = .english
    @Published var isRecording: Bool = false
    @Published var errorMessage: String? = nil
    
    private var aiService: AITriageService
    
    init(aiService: AITriageService) {
        self.aiService = aiService
    }
    
    func sendMessage() {
        guard !currentInput.isEmpty else { return }
        
        let userMessage = Message(text: currentInput, isUser: true)
        messages.append(userMessage)
        
        isLoading = true
        currentInput = ""
        
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
                errorMessage = "An error occurred. Please try again later."
            }
            
            isLoading = false
        }
    }
    
    func startRecording() {
        // Implementation of startRecording
    }
    
    func stopRecording() {
        // Implementation of stopRecording
    }
}

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.colorScheme) var colorScheme
    
    init(aiService: AITriageService) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(aiService: aiService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Language selector
            languageSelector
            
            // Chat messages
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
            
            // Input area
            inputArea
        }
        .navigationTitle("SaathiCare")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private var languageSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Language.allCases) { language in
                    Button(action: {
                        viewModel.selectedLanguage = language
                    }) {
                        Text(language.rawValue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedLanguage == language
                                ? Color.blue
                                : Color.gray.opacity(0.2)
                            )
                            .foregroundColor(
                                viewModel.selectedLanguage == language
                                ? .white
                                : .primary
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding()
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Voice input button
                Button(action: {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                }) {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(viewModel.isRecording ? .red : .blue)
                }
                
                // Text input
                TextField(
                    viewModel.selectedLanguage == .english
                    ? "Describe your symptoms..."
                    : "अपने लक्षणों का वर्णन करें...",
                    text: $viewModel.currentInput
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(viewModel.isLoading)
                
                // Send button
                Button(action: {
                    viewModel.sendMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
                .disabled(viewModel.currentInput.isEmpty || viewModel.isLoading)
            }
            .padding()
            .background(colorScheme == .dark ? Color.black : Color.white)
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
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding()
                    .background(
                        message.isUser
                        ? Color.blue
                        : Color.gray.opacity(0.2)
                    )
                    .foregroundColor(
                        message.isUser
                        ? .white
                        : .primary
                    )
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatView(aiService: AITriageService(apiKey: "YOUR_API_KEY", provider: .chatGPT))
        }
    }
} 