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
    @State private var reports: [SOAPReport] = []
    @State private var showingNewReport = false
    @State private var selectedReport: SOAPReport?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(reports.indices, id: \.self) { index in
                    ReportCard(report: reports[index])
                        .onTapGesture {
                            selectedReport = reports[index]
                        }
                }
            }
            .navigationTitle("Health Reports")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewReport = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewReport) {
                NewReportView(reports: $reports)
            }
            .sheet(item: $selectedReport) { report in
                ReportDetailView(report: report)
            }
        }
    }
}

struct ReportCard: View {
    let report: SOAPReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Health Assessment")
                .font(.headline)
            
            Text(report.assessment)
                .font(.subheadline)
                .lineLimit(2)
            
            HStack {
                Text("Plan")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("View Details")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct NewReportView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var reports: [SOAPReport]
    @State private var symptoms = ""
    @State private var selectedLanguage = "English"
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let aiService = AIService(apiKey: "YOUR_API_KEY", provider: .chatGPT)
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Language")) {
                    Picker("Language", selection: $selectedLanguage) {
                        Text("English").tag("English")
                        Text("हिंदी").tag("Hindi")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Symptoms")) {
                    TextEditor(text: $symptoms)
                        .frame(height: 100)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Report")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Generate") {
                    generateReport()
                }
                .disabled(symptoms.isEmpty || isLoading)
            )
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
        }
    }
    
    private func generateReport() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let report = try await aiService.generateSOAPReport(
                    symptoms: symptoms,
                    language: selectedLanguage
                )
                
                await MainActor.run {
                    reports.append(report)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate report. Please try again."
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct ReportDetailView: View {
    let report: SOAPReport
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Subjective")) {
                    Text(report.subjective)
                }
                
                Section(header: Text("Objective")) {
                    Text(report.objective)
                }
                
                Section(header: Text("Assessment")) {
                    Text(report.assessment)
                }
                
                Section(header: Text("Plan")) {
                    Text(report.plan)
                }
            }
            .navigationTitle("Report Details")
        }
    }
}

struct HealthReportView_Previews: PreviewProvider {
    static var previews: some View {
        HealthReportView()
    }
} 