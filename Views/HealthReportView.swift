import SwiftUI

struct SOAPReport: Identifiable {
    let id = UUID()
    let date: Date
    let subjective: String
    let objective: String
    let assessment: String
    let plan: String
    let triageLevel: TriageLevel
}

enum TriageLevel: String {
    case emergency = "Emergency"
    case urgent = "Urgent"
    case semiUrgent = "Semi-Urgent"
    case nonUrgent = "Non-Urgent"
    
    var color: Color {
        switch self {
        case .emergency: return .red
        case .urgent: return .orange
        case .semiUrgent: return .yellow
        case .nonUrgent: return .green
        }
    }
}

struct HealthReportView: View {
    @State private var reports: [SOAPReport] = [
        // Sample data
        SOAPReport(
            date: Date(),
            subjective: "Patient reports fever and cough for 3 days",
            objective: "Temperature: 38.5°C, Pulse: 90 bpm",
            assessment: "Possible viral infection",
            plan: "Rest, hydration, monitor symptoms",
            triageLevel: .semiUrgent
        )
    ]
    
    var body: some View {
        List {
            ForEach(reports) { report in
                ReportCard(report: report)
            }
        }
        .navigationTitle("Health Reports")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // TODO: Add new report
                }) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct ReportCard: View {
    let report: SOAPReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(report.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(report.triageLevel.rawValue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(report.triageLevel.color.opacity(0.2))
                    .foregroundColor(report.triageLevel.color)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ReportSection(title: "Subjective", content: report.subjective)
                ReportSection(title: "Objective", content: report.objective)
                ReportSection(title: "Assessment", content: report.assessment)
                ReportSection(title: "Plan", content: report.plan)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct ReportSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)
            Text(content)
                .font(.body)
        }
    }
}

#Preview {
    NavigationView {
        HealthReportView()
    }
} 