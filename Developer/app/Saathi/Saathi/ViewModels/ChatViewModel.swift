import Foundation
import SwiftUI
import Speech
import AVFoundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    var isFavorite: Bool
    var category: MessageCategory
    var reaction: String?
    
    init(text: String, isUser: Bool, category: MessageCategory = .general) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
        self.isFavorite = false
        self.category = category
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, isUser, timestamp, isFavorite, category, reaction
    }
}

class ChatViewModel: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var messages: [ChatMessage] = []
    @Published var currentInput: String = ""
    @Published var isLoading: Bool = false
    @Published var selectedLanguage: String = "English"
    @Published var showLanguagePicker: Bool = false
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var isSpeaking = false
    @Published var searchText = ""
    @Published var selectedCategory: MessageCategory?
    @Published var showFavoritesOnly = false
    @Published var selectedMessage: ChatMessage?
    @Published var showMessageActions = false
    
    private let aiService: AIService
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
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
    
    override init() {
        self.aiService = AIService()
        super.init()
        setupSpeechRecognition()
        loadMessages()
        loadFavorites()
    }
    
    private func setupSpeechRecognition() {
        guard let speechRecognizer = speechRecognizer else {
            print("Speech recognition not available for the specified locale")
            return
        }
        
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    self.handleSpeechRecognitionError("Speech recognition permission denied")
                case .restricted:
                    self.handleSpeechRecognitionError("Speech recognition restricted on this device")
                case .notDetermined:
                    self.handleSpeechRecognitionError("Speech recognition not yet authorized")
                @unknown default:
                    self.handleSpeechRecognitionError("Speech recognition status unknown")
                }
            }
        }
    }
    
    private func handleSpeechRecognitionError(_ message: String) {
        print("Speech Recognition Error: \(message)")
        isRecording = false
        // Show error to user
        currentInput = "Error: \(message)"
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
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            handleSpeechRecognitionError("Speech recognition unavailable")
            return
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            handleSpeechRecognitionError("Failed to configure audio session: \(error.localizedDescription)")
            return
        }
        
        // Create and configure recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            handleSpeechRecognitionError("Failed to create recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.handleSpeechRecognitionError("Recognition error: \(error.localizedDescription)")
                return
            }
            
            if let result = result {
                self.currentInput = result.bestTranscription.formattedString
            }
            
            if result?.isFinal == true {
                self.stopRecording()
            }
        }
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            handleSpeechRecognitionError("Failed to start audio engine: \(error.localizedDescription)")
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
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    func speakText(_ text: String) {
        guard !isSpeaking else {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            return
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: selectedLanguage)
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
            category: .general
        )
        messages.append(userMessage)
        saveMessages()
        
        isProcessing = true
        currentInput = ""
        
        Task {
            do {
                let response = try await aiService.generateResponse(
                    prompt: userMessage.text,
                    language: selectedLanguage
                )
                
                let aiMessage = ChatMessage(
                    text: response,
                    isUser: false,
                    category: .general
                )
                
                await MainActor.run {
                    messages.append(aiMessage)
                    saveMessages()
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    func generateSOAPReport() {
        guard let lastUserMessage = messages.last(where: { $0.isUser }) else { return }
        
        isProcessing = true
        
        Task {
            do {
                let soapReport = try await aiService.generateSOAPReport(
                    symptoms: lastUserMessage.text,
                    language: selectedLanguage
                )
                
                let reportText = """
                Subjective: \(soapReport.subjective)
                
                Objective: \(soapReport.objective)
                
                Assessment: \(soapReport.assessment)
                
                Plan: \(soapReport.plan)
                
                Triage Level: \(soapReport.triageLevel.rawValue)
                """
                
                let aiMessage = ChatMessage(
                    text: reportText,
                    isUser: false,
                    category: .medicalReport
                )
                
                await MainActor.run {
                    messages.append(aiMessage)
                    saveMessages()
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error generating SOAP report: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    func toggleFavorite(_ message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].isFavorite.toggle()
            saveFavorites()
        }
    }
    
    func addReaction(_ reaction: MessageReaction, to message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].reaction = reaction.rawValue
            saveMessages()
        }
    }
    
    func removeReaction(_ reaction: MessageReaction, from message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index].reaction = nil
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
            let category = message.category.rawValue
            let favorite = message.isFavorite ? "⭐️ " : ""
            
            exportText += """
            \(dateString) - \(sender) (\(category))
            \(favorite)\(message.text)
            
            """
            
            if let reaction = message.reaction {
                exportText += "Reaction: \(reaction)\n"
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

enum MessageCategory: String, Codable, CaseIterable {
    case symptoms = "Symptoms"
    case diagnosis = "Diagnosis"
    case treatment = "Treatment"
    case general = "General"
    case emergency = "Emergency"
    case medicalReport = "Medical Report"
}

enum MessageReaction: String, Codable, CaseIterable {
    case helpful = "👍"
    case informative = "💡"
    case urgent = "⚠️"
    case followUp = "🔍"
    case thanks = "🙏"
} 