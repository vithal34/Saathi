import Foundation
import SwiftUI

enum TriageLevel: String, CaseIterable, Identifiable, Codable {
    case emergency = "Emergency"
    case urgent = "Urgent"
    case semiUrgent = "Semi-Urgent"
    case nonUrgent = "Non-Urgent"
    
    var id: String { self.rawValue }
    
    var color: Color {
        switch self {
        case .emergency: return .red
        case .urgent: return .orange
        case .semiUrgent: return .yellow
        case .nonUrgent: return .green
        }
    }
    
    var priority: Int {
        switch self {
        case .emergency: return 1
        case .urgent: return 2
        case .semiUrgent: return 3
        case .nonUrgent: return 4
        }
    }
    
    var notificationDelay: TimeInterval {
        switch self {
        case .emergency: return 0 // Immediate
        case .urgent: return 300 // 5 minutes
        case .semiUrgent: return 1800 // 30 minutes
        case .nonUrgent: return 3600 // 1 hour
        }
    }
} 