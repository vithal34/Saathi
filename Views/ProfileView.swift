import SwiftUI

struct ProfileView: View {
    @State private var name: String = "John Doe"
    @State private var age: String = "30"
    @State private var gender: String = "Male"
    @State private var bloodGroup: String = "O+"
    @State private var showingEditProfile = false
    
    var body: some View {
        List {
            Section(header: Text("Personal Information")) {
                ProfileRow(title: "Name", value: name)
                ProfileRow(title: "Age", value: age)
                ProfileRow(title: "Gender", value: gender)
                ProfileRow(title: "Blood Group", value: bloodGroup)
            }
            
            Section(header: Text("Settings")) {
                NavigationLink(destination: Text("Notification Settings")) {
                    Label("Notifications", systemImage: "bell")
                }
                NavigationLink(destination: Text("Privacy Settings")) {
                    Label("Privacy", systemImage: "lock")
                }
                NavigationLink(destination: Text("Language Settings")) {
                    Label("Language", systemImage: "globe")
                }
            }
            
            Section {
                Button(action: {
                    // TODO: Implement logout
                }) {
                    HStack {
                        Spacer()
                        Text("Logout")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingEditProfile = true
                }) {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(
                name: $name,
                age: $age,
                gender: $gender,
                bloodGroup: $bloodGroup
            )
        }
    }
}

struct ProfileRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct EditProfileView: View {
    @Binding var name: String
    @Binding var age: String
    @Binding var gender: String
    @Binding var bloodGroup: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Name", text: $name)
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                    TextField("Gender", text: $gender)
                    TextField("Blood Group", text: $bloodGroup)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    dismiss()
                }
            )
        }
    }
}

#Preview {
    NavigationView {
        ProfileView()
    }
} 