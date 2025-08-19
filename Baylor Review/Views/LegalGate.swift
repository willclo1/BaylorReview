import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LegalGate<Content: View>: View {
    @ViewBuilder var content: () -> Content
    let termsURL: URL?
    let privacyURL: URL?

    @State private var needsGate = true

    var body: some View {
        ZStack {
            content()
        }
        .fullScreenCover(isPresented: $needsGate) {
            TermsGateView(onAccepted: { needsGate = false },
                          termsURL: termsURL,
                          privacyURL: privacyURL)
        }
        .task {
            await checkAcceptance()
        }
    }

    private func checkAcceptance() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        do {
            let snap = try await db.collection("users").document(uid)
                .collection("legal").document("terms").getDocument()
            let accepted = (snap.data()?["acceptedTermsVersion"] as? Int) ?? 0

        } catch {
            needsGate = true
        }
    }
}
