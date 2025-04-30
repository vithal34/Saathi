import Foundation

enum Language: String, CaseIterable, Identifiable {
    case hindi = "हिंदी"
    case bengali = "বাংলা"
    case tamil = "தமிழ்"
    case marathi = "मराठी"
    case telugu = "తెలుగు"
    case english = "English"
    
    var id: String { self.rawValue }
    
    var code: String {
        switch self {
        case .hindi: return "hi"
        case .bengali: return "bn"
        case .tamil: return "ta"
        case .marathi: return "mr"
        case .telugu: return "te"
        case .english: return "en"
        }
    }
    
    var voiceCode: String {
        switch self {
        case .hindi: return "hi-IN"
        case .bengali: return "bn-IN"
        case .tamil: return "ta-IN"
        case .marathi: return "mr-IN"
        case .telugu: return "te-IN"
        case .english: return "en-IN"
        }
    }
    
    var isRTL: Bool {
        // Add RTL languages if needed
        false
    }
} 