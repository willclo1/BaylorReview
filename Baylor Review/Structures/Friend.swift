import Foundation

struct Friend: Identifiable {
  let id: String        // Firestore doc ID (uid)
  let fullName: String
  let year: String
  let major: String
}
