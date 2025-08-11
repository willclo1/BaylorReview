import SwiftUI
import FirebaseAuth

struct AddReviewView: View {
    let manager: ProfessorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var professorName = ""
    @State private var course = ""
    @State private var rating = 3.0
    @State private var review = ""

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#FFF5E1"), Color(hex: "#F5F0DC")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
              
                        VStack(spacing: 16) {
                            TextField(
                                "",
                                text: $professorName,
                                prompt: Text("Professor Name")
                                    .foregroundColor(Color(hex: "#004C26"))
                            )
                            .textFieldStyle(CustomFieldStyle())

                            TextField(
                                "",
                                text: $course,
                                prompt: Text("Course (e.g., CS 1321)")
                                    .foregroundColor(Color(hex: "#004C26"))
                            )
                            .textFieldStyle(CustomFieldStyle())
                        }

                  
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rating")
                                .font(.headline)
                                .foregroundColor(Color(hex: "#004C26"))

                            HStack {
                                ForEach(1...5, id: \.self) { star in
                                    Button {
                                        rating = Double(star)
                                    } label: {
                                        Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                            .font(.title2)
                                            .foregroundColor(Color(hex: "#F5B800"))
                                    }
                                }
                                Spacer()
                                Text("\(Int(rating))/5")
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(hex: "#004C26"))
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                        }

                       
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Review")
                                .font(.headline)
                                .foregroundColor(Color(hex: "#004C26"))

                            TextEditor(text: $review)
                                .foregroundColor(Color(hex: "#004C26"))
                                .scrollContentBackground(.hidden)  
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(8)
                                .frame(minHeight: 100)
                        }

                        // Submit Button
                        Button("Submit Review") {
                            submitReview()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(canSubmit ? Color(hex: "#004C26") : Color.gray)
                        )
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .disabled(!canSubmit)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#004C26"))
                }
            }
        }
    }

    private var canSubmit: Bool {
        !professorName.isEmpty && !course.isEmpty && !review.isEmpty
    }

    private func submitReview() {
        guard let user = Auth.auth().currentUser else { return }
        let professor = Professor(
            name: professorName.trimmingCharacters(in: .whitespacesAndNewlines),
            course: course.trimmingCharacters(in: .whitespacesAndNewlines),
            rating: rating,
            review: review.trimmingCharacters(in: .whitespacesAndNewlines),
            reviewerName: user.displayName ?? "Anonymous"
        )
        manager.addReview(professor)
        dismiss()
    }
}

struct CustomFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(Color(hex: "#004C26"))
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
    }
}
