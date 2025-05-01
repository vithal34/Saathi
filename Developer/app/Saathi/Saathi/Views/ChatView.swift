import SwiftUI
import Speech

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.colorScheme) var colorScheme
    @State private var showingExportSheet = false
    @State private var showingCategoryPicker = false
    @State private var showingReactionPicker = false
    @State private var showingLanguageSelector = false
    @State private var showingSOAPReport = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Saathi")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Language and SOAP Report Button
                HStack {
                    Picker("Language", selection: $viewModel.selectedLanguage) {
                        ForEach(Language.allCases, id: \.self) { language in
                            Text(language.rawValue).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    
                    Spacer()
                    
                    Button(action: {
                        showingSOAPReport = true
                        viewModel.generateSOAPReport()
                    }) {
                        Label("Generate Report", systemImage: "doc.text")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    .disabled(viewModel.isProcessing)
                }
                .padding(.horizontal)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search messages...", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Favorites", isOn: $viewModel.showFavoritesOnly)
                        .labelsHidden()
                }
                .padding(.horizontal)
                
                // Category Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(MessageCategory.allCases, id: \.self) { category in
                            Button(action: {
                                viewModel.selectedCategory = viewModel.selectedCategory == category ? nil : category
                            }) {
                                Text(category.rawValue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        viewModel.selectedCategory == category
                                        ? Color.accentColor
                                        : Color(.systemGray5)
                                    )
                                    .foregroundColor(
                                        viewModel.selectedCategory == category
                                        ? .white
                                        : .primary
                                    )
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredMessages) { message in
                            MessageBubble(message: message, viewModel: viewModel)
                                .id(message.id)
                                .onTapGesture {
                                    viewModel.selectedMessage = message
                                    viewModel.showMessageActions = true
                                }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.filteredMessages.count) { oldValue, newValue in
                    if let lastMessage = viewModel.filteredMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input Area
            VStack(spacing: 8) {
                if viewModel.isProcessing {
                    ProgressView()
                        .padding()
                }
                
                HStack(spacing: 12) {
                    TextField("Type your symptoms...", text: $viewModel.currentInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(viewModel.isRecording)
                        .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            viewModel.startRecording()
                        }
                    }) {
                        Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title)
                            .foregroundColor(viewModel.isRecording ? .red : .blue)
                    }
                    .disabled(viewModel.isProcessing)
                    
                    Button(action: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    .disabled(viewModel.currentInput.isEmpty || viewModel.isProcessing || viewModel.isRecording)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(.separator)),
                alignment: .top
            )
            .ignoresSafeArea(.keyboard, edges: .bottom)
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
        .sheet(isPresented: $showingExportSheet) {
            ShareSheet(activityItems: [viewModel.exportMessages()])
        }
        .confirmationDialog("Message Actions", isPresented: $viewModel.showMessageActions) {
            if let message = viewModel.selectedMessage {
                Button("Add to Favorites") {
                    viewModel.toggleFavorite(message)
                }
                
                Button("Categorize") {
                    showingCategoryPicker = true
                }
                
                Button("Add Reaction") {
                    showingReactionPicker = true
                }
                
                Button("Export Chat", role: .none) {
                    showingExportSheet = true
                }
                
                Button("Cancel", role: .cancel) {}
            }
        }
        .sheet(isPresented: $showingCategoryPicker) {
            if let message = viewModel.selectedMessage {
                CategoryPickerView(selectedCategory: message.category) { category in
                    viewModel.categorizeMessage(message, category: category)
                }
            }
        }
        .sheet(isPresented: $showingReactionPicker) {
            if let message = viewModel.selectedMessage {
                ReactionPickerView(message: message, viewModel: viewModel)
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                HStack {
                    if message.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                    
                    Text(message.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(12)
                }
                
                Text(message.text)
                    .padding()
                    .background(message.isUser ? Color.accentColor : Color(.systemGray5))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
                
                if !message.isUser {
                    HStack {
                        Button(action: {
                            viewModel.speakText(message.text)
                        }) {
                            Image(systemName: viewModel.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .foregroundColor(.accentColor)
                        }
                        
                        if let reaction = message.reaction {
                            Text(reaction)
                        }
                        
                        Text(message.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct CategoryPickerView: View {
    @Environment(\.dismiss) var dismiss
    let selectedCategory: MessageCategory?
    let onSelect: (MessageCategory) -> Void
    
    var body: some View {
        NavigationView {
            List(MessageCategory.allCases, id: \.self) { category in
                Button(action: {
                    onSelect(category)
                    dismiss()
                }) {
                    HStack {
                        Text(category.rawValue)
                        Spacer()
                        if selectedCategory == category {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct ReactionPickerView: View {
    @Environment(\.dismiss) var dismiss
    let message: ChatMessage
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        NavigationView {
            List(MessageReaction.allCases, id: \.self) { reaction in
                Button(action: {
                    if message.reaction == reaction.rawValue {
                        viewModel.removeReaction(reaction, from: message)
                    } else {
                        viewModel.addReaction(reaction, to: message)
                    }
                    dismiss()
                }) {
                    HStack {
                        Text(reaction.rawValue)
                        Spacer()
                        if message.reaction == reaction.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Add Reaction")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatView()
        }
    }
} 
