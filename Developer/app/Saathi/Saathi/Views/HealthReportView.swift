import SwiftUI

struct HealthReportView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var reports: [SOAPReport] = []
    @State private var showingNewReport = false
    @State private var selectedReport: SOAPReport?
    @State private var symptoms: String = ""
    @State private var selectedLanguage: String = "English"
    @State private var isLoading: Bool = false
    @State private var soapReport: SOAPReport?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingAPIKeySettings = false
    
    private let aiService = AIService()
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingAPIKeySettings = true }) {
                        Image(systemName: "key")
                    }
                }
            }
            .sheet(isPresented: $showingNewReport) {
                NewReportView(reports: $reports)
            }
            .sheet(isPresented: $showingAPIKeySettings) {
                APIKeyView()
            }
            .sheet(item: $selectedReport) { report in
                ReportDetailView(report: report)
            }
        }
    }
    
    private func generateReport() async {
        guard !symptoms.isEmpty else { return }
        
        isLoading = true
        do {
            soapReport = try await aiService.generateSOAPReport(
                symptoms: symptoms,
                language: selectedLanguage
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
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
    @State private var showError = false
    
    private let aiService = AIService()
    
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
                    Task {
                        await generateReport()
                    }
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
    
    private func generateReport() async {
        guard !symptoms.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
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
            errorMessage = "Failed to generate report. Please try again."
            showError = true
        }
        
        isLoading = false
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
            .previewDevice("iPhone 15 Pro")
            .previewDisplayName("Health Reports")
    }
}

// Add sample data for previews
extension HealthReportView {
    static var sampleReports: [SOAPReport] {
        [
            SOAPReport(
                subjective: "Patient reports fever and cough for 3 days",
                objective: "Temperature: 38.5°C, Pulse: 90 bpm",
                assessment: "Possible viral infection",
                plan: "Rest, hydration, monitor symptoms"
            ),
            SOAPReport(
                subjective: "Patient reports headache and fatigue",
                objective: "Blood pressure: 120/80, No fever",
                assessment: "Possible stress-related symptoms",
                plan: "Rest, stress management, follow-up in 1 week"
            )
        ]
    }
} 