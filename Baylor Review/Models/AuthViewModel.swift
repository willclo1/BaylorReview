import Foundation
import FirebaseFirestore
import FirebaseCore
import FirebaseAuth
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var errorMessage: String?

    init() {
        // Firebase persists currentUser across launches
        isSignedIn = (Auth.auth().currentUser != nil)
    }

    // MARK: - Public API

    func signUp(email: String,
                password: String,
                fullName: String,
                year: String,
                major: String) {
        let normalized = normalizedEmail(email)

        // Enforce Baylor-only signups (case-insensitive)
        guard isValidBaylorEmail(normalized) else {
            self.errorMessage = "Please use a valid @baylor.edu email address."
            return
        }

        Auth.auth().createUser(withEmail: normalized, password: password) { [weak self] result, error in
            Task { @MainActor in
                if let err = error {
                    self?.errorMessage = err.localizedDescription
                    return
                }

                guard let uid = result?.user.uid else {
                    self?.errorMessage = "Unable to get user ID"
                    return
                }

                // Build profile document
                let profileData: [String: Any] = [
                    "fullName": fullName,
                    "year": year,
                    "email": normalized,                // store normalized email
                    "major": major,
                    "createdAt": Timestamp(date: Date()) // or FieldValue.serverTimestamp()
                ]

                // Save to Firestore
                let db = Firestore.firestore()
                db.collection("users").document(uid).setData(profileData) { err in
                    if let err = err {
                        self?.errorMessage = "Error saving profile: \(err.localizedDescription)"
                    } else {
                        self?.isSignedIn = true
                    }
                }
            }
        }
    }

    func signIn(email: String, password: String) {
        let normalized = normalizedEmail(email) // always normalize (Firebase treats emails case-insensitively, but this avoids surprises)
        Auth.auth().signIn(withEmail: normalized, password: password) { [weak self] _, error in
            Task { @MainActor in
                if let err = error {
                    self?.errorMessage = err.localizedDescription
                } else {
                    self?.isSignedIn = true
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            isSignedIn = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    private func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isValidBaylorEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        return parts[1] == "baylor.edu"
    }
}
