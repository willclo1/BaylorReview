import SwiftUI
import FirebaseAuth
import FirebaseFirestore

private let CURRENT_TERMS_VERSION = 1 // bump when you change terms text

struct TermsGateView: View {
    let onAccepted: () -> Void
    let termsURL: URL?    // optional external Terms URL
    let privacyURL: URL?  // optional external Privacy URL

    @State private var agreed = false
    @State private var saving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(Color(hex: "#F5B800"))
                    Text("Community Guidelines & Terms")
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "#004C26"))
                    Text("BU Review is a student community. There is zero tolerance for hate, harassment, threats, doxxing, or illegal content.")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#004C26").opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Scrollable summary
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No-Tolerance Highlights")
                            .font(.headline)
                            .foregroundColor(Color(hex: "#004C26"))

                        bullet("No harassment, hate speech, discrimination, or threats.")
                        bullet("No posting private or personal data (doxxing).")
                        bullet("No sexual content, illegal content, plagiarism, or IP violations.")
                        bullet("Follow campus rules and applicable law.")
                        bullet("Use report and block tools to keep the community healthy.")

                        Divider().padding(.vertical, 4)

                        Text("Full Terms of Use")
                            .font(.headline)
                            .foregroundColor(Color(hex: "#004C26"))

                        Text("""
By using BU Review, you agree to our Terms of Use and acknowledge our no-tolerance policy for objectionable content and abusive users. We may remove content, restrict features, or suspend accounts that violate these rules. We respond promptly to valid reports and may cooperate with campus officials or law enforcement where required.
""")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#0E3A1E"))
                    }
                    .padding(.horizontal)
                }

                // Links to full docs
                HStack(spacing: 16) {
                    if let termsURL {
                        Link("View Terms", destination: termsURL)
                    }
                    if let privacyURL {
                        Link("Privacy Policy", destination: privacyURL)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color(hex: "#2E5930"))

                // Agree row
                Toggle(isOn: $agreed) {
                    Text("I agree to the Terms of Use and no-tolerance policy.")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#004C26"))
                }
                .toggleStyle(.switch)
                .padding(.horizontal)

                // Actions
                Button {
                    Task { await accept() }
                } label: {
                    if saving { ProgressView() }
                    else { Text("Accept & Continue").bold() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#2E5930"))
                .disabled(!agreed || saving)
                .padding(.bottom, 8)

                if let errorText {
                    Text(errorText).font(.footnote).foregroundColor(.red)
                }
            }
            .padding(.vertical)
            .background(
                LinearGradient(
                    colors: [ Color(hex: "#FFF5E1"), Color(hex: "#F5F0DC") ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()
            )
            .navigationTitle("Terms of Use")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Color(hex: "#2E5930"))
            Text(text).foregroundColor(Color(hex: "#0E3A1E")).font(.subheadline)
        }
    }

    private func accept() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorText = "Please sign in again."
            return
        }
        do {
            saving = true
            let db = Firestore.firestore()
            try await db.collection("users").document(uid)
                .collection("legal").document("terms")
                .setData([
                    "acceptedTermsVersion": CURRENT_TERMS_VERSION,
                    "acceptedAt": FieldValue.serverTimestamp()
                ], merge: true)
            saving = false
            onAccepted()
        } catch {
            saving = false
            errorText = error.localizedDescription
        }
    }
}
