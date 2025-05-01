import Foundation

enum AIProvider {
    case chatGPT
    case claude
    case gemini
}

class AIService: ObservableObject {
    private let apiKey: String
    private let provider: AIProvider
    
    init(apiKey: String, provider: AIProvider) {
        self.apiKey = apiKey
        self.provider = provider
    }
    
    func generateResponse(prompt: String, language: String) async throws -> String {
        let formattedPrompt = formatPrompt(prompt: prompt, language: language)
        // TODO: Implement actual API calls based on provider
        return "AI response for: \(prompt) in \(language)"
    }
    
    func generateSOAPReport(symptoms: String, language: String) async throws -> SOAPReport {
        let prompt = formatSOAPPrompt(symptoms: symptoms, language: language)
        
        // TODO: Implement actual API calls based on provider
        // This is a placeholder implementation
        let response = try await generateResponse(prompt: prompt, language: language)
        
        // Parse the AI response into SOAP components
        return parseSOAPResponse(response)
    }
    
    private func formatPrompt(prompt: String, language: String) -> String {
        let languagePrefix = language == "Hindi" ? "हिंदी में उत्तर दें: " : "Respond in English: "
        return languagePrefix + prompt
    }
    
    private func formatSOAPPrompt(symptoms: String, language: String) -> String {
        let languagePrefix = language == "Hindi" ? "हिंदी में SOAP रिपोर्ट बनाएं: " : "Generate a SOAP report in English: "
        
        return """
        \(languagePrefix)
        
        Patient Symptoms:
        \(symptoms)
        
        Please provide a detailed SOAP report with the following sections:
        1. Subjective: Patient's reported symptoms and history
        2. Objective: Clinical observations and findings
        3. Assessment: Diagnosis and analysis
        4. Plan: Recommended treatment and follow-up
        
        Format your response with clear section headers.
        """
    }
    
    private func parseSOAPResponse(_ response: String) -> SOAPReport {
        // Split the response into sections
        let sections = response.components(separatedBy: "\n\n")
        
        var subjective = ""
        var objective = ""
        var assessment = ""
        var plan = ""
        
        for section in sections {
            if section.contains("Subjective:") {
                subjective = section.replacingOccurrences(of: "Subjective:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if section.contains("Objective:") {
                objective = section.replacingOccurrences(of: "Objective:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if section.contains("Assessment:") {
                assessment = section.replacingOccurrences(of: "Assessment:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            } else if section.contains("Plan:") {
                plan = section.replacingOccurrences(of: "Plan:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return SOAPReport(
            subjective: subjective,
            objective: objective,
            assessment: assessment,
            plan: plan
        )
    }
}

struct SOAPReport: Codable {
    let subjective: String
    let objective: String
    let assessment: String
    let plan: String
} 