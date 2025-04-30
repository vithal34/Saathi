import Foundation
import SwiftUI
import Speech

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentInput = ""
    @Published var selectedLanguage: Language = .hindi
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    private let aiService: AITriageService
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    init(aiService: AITriageService) {
        self.aiService = aiService
        setupSpeechRecognition()
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
    
    func startRecording() {
        guard !isRecording else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.contextualStrings = ["fever", "headache", "pain", "cough"] // Add common medical terms
            
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
    
    func sendMessage() {
        guard !currentInput.isEmpty else { return }
        
        let userMessage = ChatMessage(
            text: currentInput,
            isUser: true,
            language: selectedLanguage
        )
        messages.append(userMessage)
        
        isProcessing = true
        currentInput = ""
        
        Task {
            do {
                let result = try await aiService.analyzeSymptoms(
                    userMessage.text,
                    language: selectedLanguage
                )
                
                let aiMessage = ChatMessage(
                    text: formatTriageResponse(result),
                    isUser: false,
                    language: selectedLanguage
                )
                
                await MainActor.run {
                    messages.append(aiMessage)
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
    
    private func formatTriageResponse(_ result: TriageResult) -> String {
        return """
        Assessment: \(result.assessment)
        
        Severity: \(result.level.rawValue)
        
        Next Steps: \(result.nextSteps)
        
        \(result.shouldEscalate ? "⚠️ This case has been escalated to a doctor for review." : "")
        """
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let language: Language
    let timestamp = Date()
} 