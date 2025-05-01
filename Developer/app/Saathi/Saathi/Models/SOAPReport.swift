import Foundation

struct SOAPReport: Codable, Identifiable {
    let id: UUID
    let date: Date
    let subjective: String
    let objective: String
    let assessment: String
    let plan: String
    let triageLevel: TriageLevel
    
    init(subjective: String, objective: String, assessment: String, plan: String, triageLevel: TriageLevel = .nonUrgent) {
        self.id = UUID()
        self.date = Date()
        self.subjective = subjective
        self.objective = objective
        self.assessment = assessment
        self.plan = plan
        self.triageLevel = triageLevel
    }
    
    enum CodingKeys: String, CodingKey {
        case subjective, objective, assessment, plan, triageLevel
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.date = Date()
        self.subjective = try container.decode(String.self, forKey: .subjective)
        self.objective = try container.decode(String.self, forKey: .objective)
        self.assessment = try container.decode(String.self, forKey: .assessment)
        self.plan = try container.decode(String.self, forKey: .plan)
        self.triageLevel = try container.decode(TriageLevel.self, forKey: .triageLevel)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(subjective, forKey: .subjective)
        try container.encode(objective, forKey: .objective)
        try container.encode(assessment, forKey: .assessment)
        try container.encode(plan, forKey: .plan)
        try container.encode(triageLevel, forKey: .triageLevel)
    }
} 