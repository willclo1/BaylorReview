import Foundation
import FirebaseFirestore

class ProfessorViewModel: ObservableObject {
    @Published var professors: [Professor] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    func fetchProfessors() {
        isLoading = true
        db.collection("professors")
            .order(by: "dateCreated", descending: true)
            .addSnapshotListener { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        print("Error: \(error)")
                        return
                    }
                    self.professors = snapshot?.documents.compactMap {
                        try? $0.data(as: Professor.self)
                    } ?? []
                }
            }
    }
    
    func addReview(_ professor: Professor) {
        do {
            try db.collection("professors").addDocument(from: professor)
        } catch {
            print("Error adding review: \(error)")
        }
    }
}
