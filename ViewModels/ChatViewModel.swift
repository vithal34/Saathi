import Foundation
import SwiftUI
import Speech
import AVFoundation

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentInput = ""
    @Published var selectedLanguage: Language = .hindi
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var isSpeaking = false
    @Published var searchText = ""
    @Published var selectedCategory: MessageCategory?
    @Published var showFavoritesOnly = false
    @Published var selectedMessage: ChatMessage?
    @Published var showMessageActions = false
    
    private let aiServices: [AITriageService]
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private let userDefaults = UserDefaults.standard
    private let messagesKey = "savedMessages"
    private let favoritesKey = "favoriteMessages"
    private let categoriesKey = "messageCategories"
    
    var filteredMessages: [ChatMessage] {
        var filtered = messages
        
        if showFavoritesOnly {
            filtered = filtered.filter { $0.isFavorite }
        }
        
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filtered
    }
    
    init(aiServices: [AITriageService]) {
        self.aiServices = aiServices
        setupSpeechRecognition()
        loadMessages()
        loadFavorites()
    }
    
    private func setupSpeechRecognition() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    self.errorMessage = "Speech recognition permission denied"
                case .restricted:
                    self.errorMessage = "Speech recognition not available on this device"
                case .notDetermined:
                    self.errorMessage = "Speech recognition not yet authorized"
                @unknown default:
                    self.errorMessage = "Unknown speech recognition status"
                }
            }
        }
    }
    
    private func loadMessages() {
        if let data = userDefaults.data(forKey: messagesKey),
           let decodedMessages = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = decodedMessages
        }
    }
    
    private func saveMessages() {
        if let encodedData = try? JSONEncoder().encode(messages) {
            userDefaults.set(encodedData, forKey: messagesKey)
        }
    }
    
    private func loadFavorites() {
        if let data = userDefaults.data(forKey: favoritesKey),
           let favorites = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            for (index, message) in messages.enumerated() {
                if favorites.contains(message.id) {
                    messages[index].isFavorite = true
                }
            }
        }
    }
    
    private func saveFavorites() {
        let favorites = Set(messages.filter { $0.isFavorite }.map { $0.id })
        if let encodedData = try? JSONEncoder().encode(favorites) {
            userDefaults.set(encodedData, forKey: favoritesKey)
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.contextualStrings = MedicalTerms.getTerms(for: selectedLanguage)
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    self.currentInput = result.bestTranscription.formattedString
                }
                
                if error != nil || result?.isFinal == true {
                    self.stopRecording()
                }
            }
            
            isRecording = true
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }
    
    func speakText(_ text: String) {
        guard !isSpeaking else {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            return
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: selectedLanguage.voiceCode)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    func sendMessage() {
        guard !currentInput.isEmpty else { return }
        
        let userMessage = ChatMessage(
            text: currentInput,
            isUser: true,
            language: selectedLanguage
        )
        messages.append(userMessage)
        saveMessages()
        
        isProcessing = true
        currentInput = ""
        
        Task {
            do {
                // Get responses from all AI services
                let responses = try await withThrowingTaskGroup(of: (String, String).self) { group in
                    for service in aiServices {
                        group.addTask {
                            let response = try await service.analyzeSymptoms(
                                userMessage.text,
                                language: self.selectedLanguage
                            )
                            return (service.provider.rawValue, response.assessment)
                        }
                    }
                    
                    var results: [(String, String)] = []
                    for try await result in group {
                        results.append(result)
                    }
                    return results
                }
                
                // Format the combined response
                let combinedResponse = formatAIResponses(responses)
                
                let aiMessage = ChatMessage(
                    text: combinedResponse,
                    isUser: false,
                    language: selectedLanguage
                )
                
                await MainActor.run {
                    messages.append(aiMessage)
                    saveMessages()
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to get AI response: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    private func formatAIResponses(_ responses: [(String, String)]) -> String {
        var formattedResponse = "Here are the responses from our AI models:\n\n"
        
        for (provider, response) in responses {
            formattedResponse += "\(provider):\n\(response)\n\n"
        }
        
        return formattedResponse
    }
    
    func toggleFavorite(_ message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].isFavorite.toggle()
            saveFavorites()
        }
    }
    
    func addReaction(_ reaction: MessageReaction, to message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].reactions.append(reaction)
            saveMessages()
        }
    }
    
    func removeReaction(_ reaction: MessageReaction, from message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].reactions.removeAll { $0 == reaction }
            saveMessages()
        }
    }
    
    func exportMessages() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var exportText = "Saathi Chat Export - \(dateFormatter.string(from: Date()))\n\n"
        
        for message in messages {
            let dateString = dateFormatter.string(from: message.timestamp)
            let sender = message.isUser ? "You" : "AI"
            let category = message.category?.rawValue ?? "Uncategorized"
            let favorite = message.isFavorite ? "⭐️ " : ""
            
            exportText += """
            \(dateString) - \(sender) (\(category))
            \(favorite)\(message.text)
            
            """
            
            if !message.reactions.isEmpty {
                exportText += "Reactions: \(message.reactions.map { $0.rawValue }.joined(separator: ", "))\n"
            }
            
            exportText += "\n"
        }
        
        return exportText
    }
    
    func categorizeMessage(_ message: ChatMessage, category: MessageCategory) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].category = category
            saveMessages()
        }
    }
    
    func clearFilters() {
        selectedCategory = nil
        showFavoritesOnly = false
        searchText = ""
    }
}

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let language: Language
    let timestamp = Date()
    var isFavorite = false
    var category: MessageCategory?
    var reactions: [MessageReaction] = []
}

enum MessageCategory: String, Codable, CaseIterable {
    case symptoms = "Symptoms"
    case diagnosis = "Diagnosis"
    case treatment = "Treatment"
    case general = "General"
    case emergency = "Emergency"
}

enum MessageReaction: String, Codable, CaseIterable {
    case helpful = "👍"
    case informative = "💡"
    case urgent = "⚠️"
    case followUp = "🔍"
    case thanks = "🙏"
} 