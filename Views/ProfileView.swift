import SwiftUI

struct ProfileView: View {
    @State private var name = ""
    @State private var age = ""
    @State private var gender = "Male"
    @State private var bloodGroup = "A+"
    @State private var medicalHistory = ""
    @State private var allergies = ""
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Name", text: $name)
                        .disabled(!isEditing)
                    
                    TextField("Age", text: $age)
                        .keyboardType(.numberPad)
                        .disabled(!isEditing)
                    
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                        Text("Other").tag("Other")
                    }
                    .disabled(!isEditing)
                    
                    Picker("Blood Group", selection: $bloodGroup) {
                        Text("A+").tag("A+")
                        Text("A-").tag("A-")
                        Text("B+").tag("B+")
                        Text("B-").tag("B-")
                        Text("AB+").tag("AB+")
                        Text("AB-").tag("AB-")
                        Text("O+").tag("O+")
                        Text("O-").tag("O-")
                    }
                    .disabled(!isEditing)
                }
                
                Section(header: Text("Medical Information")) {
                    TextEditor(text: $medicalHistory)
                        .frame(height: 100)
                        .disabled(!isEditing)
                    
                    TextEditor(text: $allergies)
                        .frame(height: 100)
                        .disabled(!isEditing)
                }
                
                Section {
                    Button(action: {
                        isEditing.toggle()
                    }) {
                        Text(isEditing ? "Save Changes" : "Edit Profile")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(isEditing ? Color.blue : Color.gray)
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .previewDevice("iPhone 15 Pro")
            .previewDisplayName("Profile View")
    }
} 