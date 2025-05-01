import Foundation

public enum AIProvider: String, RawRepresentable {
    case chatGPT = "ChatGPT"
    case claude = "Claude"
    case gemini = "Gemini"
}

class AIService: NSObject, ObservableObject {
    private var apiKey: String
    private let provider: AIProvider
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    private let rateLimitWindow: TimeInterval = 60.0 // 1 minute window
    private let maxRequestsPerWindow = 60 // Rate limit
    private var requestTimestamps: [Date] = []
    private let requestQueue = DispatchQueue(label: "com.saathi.aiService")
    
    // API Configuration
    private let baseURL = "https://generativelanguage.googleapis.com/v1"
    private let model = "gemini-pro"
    private let maxTokens = 1000
    private let temperature = 0.7
    
    static let shared = AIService()
    
    override init() {
        self.apiKey = "AIzaSyDCcstYaWmIa7SdmSY3TRuklTfCqWwsBA8"
        self.provider = .gemini
        super.init()
    }
    
    init(apiKey: String, provider: AIProvider) {
        self.apiKey = apiKey
        self.provider = provider
        super.init()
    }
    
    func setAPIKey(_ key: String) {
        // Store in UserDefaults for persistence
        UserDefaults.standard.set(key, forKey: "GeminiAPIKey")
        // Update the instance variable
        self.apiKey = key
    }
    
    private func waitForRateLimit() async throws {
        let now = Date()
        requestQueue.sync {
            // Remove timestamps older than the rate limit window
            requestTimestamps = requestTimestamps.filter { now.timeIntervalSince($0) < rateLimitWindow }
            
            // If we've hit the rate limit, wait until the oldest request expires
            if requestTimestamps.count >= maxRequestsPerWindow {
                let oldestRequest = requestTimestamps.first!
                let waitTime = rateLimitWindow - now.timeIntervalSince(oldestRequest)
                if waitTime > 0 {
                    Thread.sleep(forTimeInterval: waitTime)
                }
            }
            
            // Add current request timestamp
            requestTimestamps.append(now)
        }
    }
    
    private func makeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var retryCount = 0
        var lastError: Error?
        var lastRetryAfter: TimeInterval = retryDelay
        
        while retryCount < maxRetries {
            do {
                try await waitForRateLimit()
                
                // Validate API key before making request
                guard !apiKey.isEmpty else {
                    print("Error: API key is empty")
                    throw NSError(domain: "AIService", code: -2, userInfo: [
                        NSLocalizedDescriptionKey: "API key is empty"
                    ])
                }
                
                print("Making API request attempt \(retryCount + 1) of \(maxRetries)")
                print("Request URL: \(request.url?.absoluteString ?? "No URL")")
                print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Received HTTP response with status code: \(httpResponse.statusCode)")
                    print("Response Headers: \(httpResponse.allHeaderFields)")
                    
                    switch httpResponse.statusCode {
                    case 200...299:
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("Success response: \(responseString)")
                        }
                        return (data, response)
                    case 401:
                        print("Error: Unauthorized - Invalid API key")
                        if let errorResponse = String(data: data, encoding: .utf8) {
                            print("Error details: \(errorResponse)")
                        }
                        throw NSError(domain: "AIService", code: 401, userInfo: [
                            NSLocalizedDescriptionKey: "Invalid API key or unauthorized access"
                        ])
                    case 429:
                        print("Rate limit hit, waiting to retry")
                        // Get retry-after from header or use exponential backoff
                        if let retryAfterStr = httpResponse.value(forHTTPHeaderField: "Retry-After"),
                           let retryAfter = Double(retryAfterStr) {
                            lastRetryAfter = retryAfter
                            print("Using server-specified retry time: \(retryAfter) seconds")
                        } else {
                            // Exponential backoff with jitter
                            let jitter = Double.random(in: 0.0...0.1)
                            lastRetryAfter = min(lastRetryAfter * 2.0 + jitter, 60.0) // Cap at 60 seconds
                            print("Using exponential backoff: \(lastRetryAfter) seconds")
                        }
                        
                        print("Waiting \(lastRetryAfter) seconds before retry")
                        try await Task.sleep(nanoseconds: UInt64(lastRetryAfter * 1_000_000_000))
                        retryCount += 1
                        continue
                    case 500...599:
                        print("Server error \(httpResponse.statusCode), retrying with backoff")
                        if let errorResponse = String(data: data, encoding: .utf8) {
                            print("Error details: \(errorResponse)")
                        }
                        retryCount += 1
                        if retryCount < maxRetries {
                            let backoffDelay = retryDelay * pow(2.0, Double(retryCount - 1))
                            print("Waiting \(backoffDelay) seconds before retry")
                            try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                            continue
                        }
                    default:
                        if let errorResponse = String(data: data, encoding: .utf8) {
                            print("Error response from API: \(errorResponse)")
                            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [
                                NSLocalizedDescriptionKey: "API request failed: \(errorResponse)"
                            ])
                        } else {
                            print("Error: API request failed with status code \(httpResponse.statusCode)")
                            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [
                                NSLocalizedDescriptionKey: "API request failed with status code: \(httpResponse.statusCode)"
                            ])
                        }
                    }
                }
                
                return (data, response)
            } catch let error as NSError {
                print("Request attempt \(retryCount + 1) failed with error: \(error.localizedDescription)")
                print("Error domain: \(error.domain)")
                print("Error code: \(error.code)")
                print("Error user info: \(error.userInfo)")
                lastError = error
                retryCount += 1
                if retryCount < maxRetries {
                    let backoffDelay = retryDelay * pow(2.0, Double(retryCount - 1))
                    print("Waiting \(backoffDelay) seconds before retry")
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
            } catch {
                print("Request attempt \(retryCount + 1) failed with error: \(error.localizedDescription)")
                lastError = error
                retryCount += 1
                if retryCount < maxRetries {
                    let backoffDelay = retryDelay * pow(2.0, Double(retryCount - 1))
                    print("Waiting \(backoffDelay) seconds before retry")
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
            }
        }
        
        print("All retry attempts failed. Last error: \(lastError?.localizedDescription ?? "Unknown error")")
        if let error = lastError as? NSError {
            print("Last error domain: \(error.domain)")
            print("Last error code: \(error.code)")
            print("Last error user info: \(error.userInfo)")
        }
        throw lastError ?? NSError(domain: "AIService", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Failed after \(maxRetries) retries"
        ])
    }
    
    func generateResponse(prompt: String, language: String) async throws -> String {
        let formattedPrompt = formatPrompt(prompt: prompt, language: language)
        print("Sending request to Gemini with prompt: \(formattedPrompt)")
        
        guard let url = URL(string: "\(baseURL)/models/\(model):generateContent?key=\(apiKey)") else {
            print("Error: Invalid API URL")
            throw NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": formattedPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": maxTokens
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "Unable to convert to string")")
            
            let (data, _) = try await makeRequest(request)
            
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            print("Received JSON response: \(jsonResponse ?? [:])")
            
            guard let candidates = jsonResponse?["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
                print("Error: Failed to parse API response")
                throw NSError(domain: "AIService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse API response"])
            }
            
            print("Successfully received response from Gemini")
            return text
        } catch let error as NSError {
            print("Error during API call: \(error.localizedDescription)")
            print("Error domain: \(error.domain)")
            print("Error code: \(error.code)")
            print("Error user info: \(error.userInfo)")
            throw error
        } catch {
            print("Error during API call: \(error.localizedDescription)")
            throw error
        }
    }
    
    func generateSOAPReport(symptoms: String, language: String) async throws -> SOAPReport {
        let prompt = formatSOAPPrompt(symptoms: symptoms, language: language)
        print("Generating SOAP report with prompt: \(prompt)")
        
        let response = try await generateResponse(prompt: prompt, language: language)
        print("Received SOAP report response: \(response)")
        
        // Parse the AI response into SOAP components
        let soapReport = parseSOAPResponse(response)
        
        // Update triage level based on assessment
        let updatedReport = updateTriageLevel(soapReport)
        return updatedReport
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
            plan: plan,
            triageLevel: .nonUrgent // Default to non-urgent, can be updated based on assessment
        )
    }
    
    private func updateTriageLevel(_ report: SOAPReport) -> SOAPReport {
        let assessment = report.assessment.lowercased()
        
        // Determine triage level based on assessment content
        let triageLevel: TriageLevel
        if assessment.contains("emergency") || assessment.contains("life-threatening") {
            triageLevel = .emergency
        } else if assessment.contains("urgent") || assessment.contains("immediate") {
            triageLevel = .urgent
        } else if assessment.contains("semi-urgent") || assessment.contains("soon") {
            triageLevel = .semiUrgent
        } else {
            triageLevel = .nonUrgent
        }
        
        return SOAPReport(
            subjective: report.subjective,
            objective: report.objective,
            assessment: report.assessment,
            plan: report.plan,
            triageLevel: triageLevel
        )
    }
} 