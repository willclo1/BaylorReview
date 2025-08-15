import SwiftUI
import FirebaseFirestore

struct SafetyCenterView: View {
    let service: ChatService

    var body: some View {
        List {
            Section {
                NavigationLink { BlockedUsersView(service: service) } label: {
                    Label("Blocked Users", systemImage: "hand.raised.fill")
                }
                NavigationLink { MutedUsersView(service: service) } label: {
                    Label("Muted Users", systemImage: "bell.slash.fill")
                }
            }

            Section("About") {
                Text("Blocking stops messages both ways. Muting keeps the chat but silences notifications.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Safety & Privacy")
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FFF5E1"), Color(hex: "#F0E6D2")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
    }
}

// MARK: - Blocked

struct BlockedUser: Identifiable {
    let id: String
    let displayName: String
    let createdAt: Date?
}

struct BlockedUsersView: View {
    let service: ChatService
    @State private var blocked: [BlockedUser] = []
    @State private var listener: ListenerRegistration?

    var body: some View {
        List {
            if blocked.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "hand.raised")
                        .font(.title2)
                    Text("No blocked users").font(.headline)
                    Text("People you block will appear here.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(blocked) { u in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(u.displayName).font(.headline)
                            if let d = u.createdAt {
                                Text("Blocked \(RelativeDateTimeFormatter().localizedString(for: d, relativeTo: Date()))")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button("Unblock") {
                            service.unblock(userId: u.id) { _ in }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
        .onAppear {
            listener?.remove()
            listener = Firestore.firestore()
                .collection("users").document(service.currentUid)
                .collection("blocks")
                .order(by: "createdAt", descending: true)
                .addSnapshotListener { snap, _ in
                    let items: [BlockedUser] = snap?.documents.map { d in
                        let data = d.data()
                        return BlockedUser(
                            id: d.documentID,
                            displayName: (data["displayName"] as? String) ?? d.documentID,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                        )
                    } ?? []
                    blocked = items
                }
        }
        .onDisappear { listener?.remove(); listener = nil }
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FFF5E1"), Color(hex: "#F0E6D2")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
    }
}

// MARK: - Muted

struct MutedUser: Identifiable {
    let id: String
    let displayName: String
    let createdAt: Date?
}

struct MutedUsersView: View {
    let service: ChatService
    @State private var muted: [MutedUser] = []
    @State private var listener: ListenerRegistration?

    var body: some View {
        List {
            if muted.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.title2)
                    Text("No muted users").font(.headline)
                    Text("Chats you mute will appear here.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(muted) { u in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(u.displayName).font(.headline)
                            if let d = u.createdAt {
                                Text("Muted \(RelativeDateTimeFormatter().localizedString(for: d, relativeTo: Date()))")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button("Unmute") {
                            service.unmute(userId: u.id) { _ in }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("Muted Users")
        .onAppear {
            listener?.remove()
            listener = Firestore.firestore()
                .collection("users").document(service.currentUid)
                .collection("mutes")
                .order(by: "createdAt", descending: true)
                .addSnapshotListener { snap, _ in
                    let items: [MutedUser] = snap?.documents.map { d in
                        let data = d.data()
                        return MutedUser(
                            id: d.documentID,
                            displayName: (data["displayName"] as? String) ?? d.documentID,
                            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                        )
                    } ?? []
                    muted = items
                }
        }
        .onDisappear { listener?.remove(); listener = nil }
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FFF5E1"), Color(hex: "#F0E6D2")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
    }
}
