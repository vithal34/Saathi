import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingLanguageSelector = false
    @State private var selectedLanguage: Language = .english
    
    enum Language: String, CaseIterable {
        case english = "English"
        case hindi = "हिंदी"
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .tag(0)
            
            HealthReportView()
                .tabItem {
                    Label("Reports", systemImage: "doc.text.fill")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .navigationTitle("Saathi")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingLanguageSelector = true
                }) {
                    Image(systemName: "globe")
                }
            }
        }
        .sheet(isPresented: $showingLanguageSelector) {
            LanguageSelectorView(selectedLanguage: $selectedLanguage)
        }
    }
}

struct LanguageSelectorView: View {
    @Binding var selectedLanguage: ContentView.Language
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(ContentView.Language.allCases, id: \.self) { language in
                Button(action: {
                    selectedLanguage = language
                    dismiss()
                }) {
                    HStack {
                        Text(language.rawValue)
                        Spacer()
                        if language == selectedLanguage {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 15 Pro")
            .previewDisplayName("iPhone 15 Pro")
    }
} 