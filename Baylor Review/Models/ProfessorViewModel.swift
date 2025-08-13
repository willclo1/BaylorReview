import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore



class ProfessorViewModel: ObservableObject {
    @Published var items: [ProfessorItem] = []
    @Published var professors: [Professor] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }



    func fetchProfessors() {
        isLoading = true
        listener?.remove()

        listener = db.collection("professors")
            .order(by: "dateCreated", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        print("Error fetching professors: \(error)")
                        self.items = []
                        self.professors = []
                        return
                    }

                    guard let docs = snapshot?.documents else {
                        self.items = []
                        self.professors = []
                        return
                    }

                    let mapped: [ProfessorItem] = docs.compactMap { doc in
                        do {
                            let prof = try doc.data(as: Professor.self)
                            return ProfessorItem(id: doc.documentID, professor: prof)
                        } catch {
                            print("Decode error for \(doc.documentID): \(error)")
                            return nil
                        }
                    }

                    self.items = mapped
                    self.professors = mapped.map { $0.professor }
                }
            }
    }

    // MARK: Add Review

    func addReview(_ professor: Professor) {
        do {
            // If you prefer server time, consider merging dateCreated with FieldValue.serverTimestamp()
            _ = try db.collection("professors").addDocument(from: professor)
        } catch {
            print("Error adding review: \(error)")
        }
    }




    func reportReview(
        for item: ProfessorItem,
        reason: ReportReason,
        details: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        reportReview(
            reviewID: item.id,
            professor: item.professor,
            reason: reason,
            details: details,
            completion: completion
        )
    }

    /// Core report implementation
    private func reportReview(
        reviewID: String,
        professor: Professor,
        reason: ReportReason,
        details: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let uid = Auth.auth().currentUser?.uid ?? "anonymous"
        let reviewRef = db.collection("professors").document(reviewID)
        let reportsRef = reviewRef.collection("reports")

  
        reportsRef.whereField("reporterUid", isEqualTo: uid)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                if let existing = snapshot, !existing.documents.isEmpty {
                    completion(.failure(DuplicateReportError()))
                    return
                }

                // Build report payload
                let payload = ReviewReport(
                    reviewId: reviewID,
                    reporterUid: uid,
                    professorName: professor.name,
                    course: professor.course,
                    rating: professor.rating,
                    excerpt: String(professor.review.prefix(200)),
                    reason: reason.rawValue,
                    details: details,
                    status: "pending",
                    createdAt: Date()
                )

                do {
                    _ = try reportsRef.addDocument(from: payload) { err in
                        if let err = err {
                            completion(.failure(err))
                        } else {
                            completion(.success(()))
                        }
                    }
                } catch {
                    completion(.failure(error))
                }
            }
    }
}

// MARK: - Models used for reporting

struct ReviewReport: Codable {
    let reviewId: String
    let reporterUid: String
    let professorName: String
    let course: String
    let rating: Double
    let excerpt: String
    let reason: String
    let details: String?
    let status: String            // e.g. pending/handled
    let createdAt: Date
}

// Used to signal a duplicate report from the same user.
struct DuplicateReportError: LocalizedError {
    var errorDescription: String? {
        "You’ve already reported this review."
    }
}
