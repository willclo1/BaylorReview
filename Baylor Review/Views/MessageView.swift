import SwiftUI
import FirebaseAuth

struct MessagesView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var vm = FriendViewModel()

    @State private var chatService: ChatService?
    @State private var authHandle: AuthStateDidChangeListenerHandle?
    @State private var showNewChat = false
    @State private var navigateToChatId: String?

    // id -> name map
    private var nameIndex: [String: String] {
        Dictionary(uniqueKeysWithValues: vm.allUsers.map { ($0.id, $0.fullName) })
    }
    private func displayName(for uid: String) -> String? {
        nameIndex[uid]
    }

    var body: some View {
        ZStack {
            // App background
            LinearGradient(
                colors: [Color(hex: "#FFF5E1"), Color(hex: "#F0E6D2")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            Group {
                if let service = chatService, vm.hasLoaded {
                    content(service: service)
                } else {
                    VStack(spacing: 12) {
                        ProgressView().progressViewStyle(.circular)
                        Text("Loading messages…")
                            .font(.callout)
                            .foregroundColor(Color(hex: "#004C26"))
                    }
                }
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNewChat = true } label: {
                    Image(systemName: "square.and.pencil").font(.title3)
                }
            }
        }
        .toolbarBackground(Color(hex: "#2E5930"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)

        // Lifecycle
        .onAppear {
            if !vm.hasLoaded { vm.loadData() }

            // Build/refresh ChatService ONLY when we have a real UID
            if authHandle == nil {
                authHandle = Auth.auth().addStateDidChangeListener { _, user in
                    let uid = user?.uid ?? ""
                    if uid.isEmpty {
                        chatService?.stopListening()
                        chatService = nil
                        return
                    }
                    if chatService?.currentUid != uid {
                        chatService?.stopListening()
                        chatService = ChatService(currentUserId: uid)
                        if vm.hasLoaded {
                            chatService?.listenChats()
                        }
                    }
                }
            }
        }
        .onDisappear {
            if let h = authHandle {
                Auth.auth().removeStateDidChangeListener(h)
                authHandle = nil
            }
        }
        // Start chats listener only after names are ready (prevents UID flicker in rows)
        .onChange(of: vm.hasLoaded) { loaded in
            if loaded { chatService?.listenChats() }
        }

        // New chat
        .sheet(isPresented: $showNewChat) {
            NewChatSheet(friends: vm.friendsList) { friend in
                guard let service = chatService else { return }
                service.getOrCreateChat(with: friend.id) { cid in
                    navigateToChatId = cid
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }

        // === Banner pinned to the bottom of this screen ===
        .safeAreaInset(edge: .bottom) {
            BannerAdView(adUnitID: AdConfig.bannerUnitID)
                .frame(height: 50)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
        }
    }
    @ViewBuilder
    private func content(service: ChatService) -> some View {
        ChatsList(
            service: service,
            nameIndex: nameIndex,
            navigateToChatId: $navigateToChatId
        )
    }
}


private struct ChatsList: View {
    @ObservedObject var service: ChatService
    let nameIndex: [String: String]
    @Binding var navigateToChatId: String?

    private func displayName(for uid: String) -> String? { nameIndex[uid] }

    var body: some View {
        List(service.chats) { chat in
            let otherId = chat.participantIds.first { $0 != service.currentUid } ?? ""
            let name = displayName(for: otherId)

            Button { navigateToChatId = chat.id } label: {
                ChatRow(chat: chat, displayName: name)
            }
            .listRowBackground(Color.white)
        }
        .listStyle(.plain)
        .background(Color.clear)
        .navigationDestination(item: $navigateToChatId) { cid in
            ChatThreadView(chatId: cid, service: service)
        }
    }
}


private struct ChatRow: View {
    let chat: Chat
    let displayName: String?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#2E5930"), Color(hex: "#1B4D20")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)

                if let name = displayName, let initial = name.first {
                    Text(String(initial).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                } else {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white.opacity(0.85))
                }
            }

            // Meta
            VStack(alignment: .leading, spacing: 4) {
                if let name = displayName {
                    Text(name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#004C26"))
                        .lineLimit(1)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#E8DCC6"))
                        .frame(width: 120, height: 12)
                        .redacted(reason: .placeholder)
                }

                Text(chat.lastMessageText?.isEmpty == false ? chat.lastMessageText! : "New chat")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#F5B800"))
                    .lineLimit(1)
            }

            Spacer()

            if let ts = chat.lastMessageAt?.dateValue() {
                Text(ts, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}



private struct NewChatSheet: View {
    let friends: [Friend]
    let onPick: (Friend) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [Friend] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return friends.sorted { $0.fullName < $1.fullName } }
        return friends.filter {
            $0.fullName.lowercased().contains(q) ||
            $0.major.lowercased().contains(q) ||
            $0.year.lowercased().contains(q)
        }
        .sorted { $0.fullName < $1.fullName }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#FFF5E1"), Color(hex: "#F0E6D2")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    // Search
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#2E5930"))
                        TextField("Search friends by name, major, or year", text: $query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(true)
                            .foregroundColor(Color(hex: "#004C26"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#E8DCC6"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#2E5930").opacity(0.25), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Friend list
                    List {
                        ForEach(filtered) { f in
                            Button {
                                onPick(f); dismiss()
                            } label: {
                                FriendPickRow(friend: f)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .buttonStyle(.plain)
                        }

                        if filtered.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "person.crop.circle.badge.exclamationmark")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(Color(hex: "#2E5930").opacity(0.8))
                                Text("No matches")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "#004C26"))
                                Text("Try a different name, major, or year.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("New Message")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(Color(hex: "#2E5930"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(.white)
        }
    }
}

private struct FriendPickRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#2E5930"), Color(hex: "#1B4D20")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(friend.fullName.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.92))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.fullName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#004C26"))
                    .lineLimit(1)

                Text("\(friend.major) • \(friend.year)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#004C26").opacity(0.85))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#F5B800"))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

private extension Optional where Wrapped == String {
    var item: String? { self }
}

extension String: Identifiable { public var id: String { self } }
