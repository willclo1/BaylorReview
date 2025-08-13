import Foundation
import FirebaseAuth
import FirebaseFirestore

struct Chat: Identifiable, Equatable {
    var id: String
    var participantIds: [String]
    var createdAt: Timestamp?
    var lastMessageText: String?
    var lastMessageAt: Timestamp?
    var lastSenderId: String?
}

struct Message: Identifiable, Equatable {
    var id: String
    var senderId: String
    var text: String
    var createdAt: Timestamp?
}

struct ChatMember {
    var lastReadAt: Timestamp?
}

@MainActor
final class ChatService: ObservableObject {
    private let db = Firestore.firestore()
    private let uid: String

    @Published var chats: [Chat] = []
    private var chatsListener: ListenerRegistration?

    init(currentUserId: String) {
        self.uid = currentUserId
    }

    deinit {
        chatsListener?.remove()
    }

    var currentUid: String { uid }

    func chatId(with otherId: String) -> String {
        [uid, otherId].sorted().joined(separator: "_")
    }

    // Create if missing, otherwise return id
    func getOrCreateChat(with otherId: String, completion: @escaping (String) -> Void) {
        let cid = chatId(with: otherId)
        let ref = db.collection("chats").document(cid)

        ref.getDocument { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("get chat error:", err)
                completion(cid)
                return
            }
            if let snap, snap.exists {
                completion(cid)
                return
            }

            // Seed order fields so list queries are stable even before first message
            let now = FieldValue.serverTimestamp()
            let data: [String: Any] = [
                "participantIds": [self.uid, otherId],
                "createdAt": now,
                "lastMessageText": "",
                "lastMessageAt": now,
                "lastSenderId": ""
            ]
            ref.setData(data) { err in
                if let err = err { print("create chat error:", err) }

                ref.collection("members").document(self.uid)
                    .setData(["lastReadAt": now], merge: true)
                ref.collection("members").document(otherId)
                    .setData(["lastReadAt": now], merge: true)

                completion(cid)
            }
        }
    }

    // Send a text and update chat summary
    func send(text: String, in chatId: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let msgRef = db.collection("chats").document(chatId)
            .collection("messages").document()

        let message: [String: Any] = [
            "senderId": uid,
            "text": trimmed,
            "createdAt": FieldValue.serverTimestamp()
        ]

        msgRef.setData(message) { err in
            if let err = err { print("send msg error:", err) }
        }

        let chatRef = db.collection("chats").document(chatId)
        chatRef.setData([
            "lastMessageText": trimmed,
            "lastMessageAt": FieldValue.serverTimestamp(),
            "lastSenderId": uid
        ], merge: true)
    }

    // Live list of chats for current user
    func listenChats() {
        chatsListener?.remove()

        // NOTE: Ensure a composite index exists for:
        // participantIds (array_contains) + lastMessageAt (desc)
        chatsListener = db.collection("chats")
            .whereField("participantIds", arrayContains: uid)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snap, err in
                guard let self = self else { return }
                if let err = err {
                    print("listen chats error:", err)
                    return
                }
                let docs = snap?.documents ?? []
                let mapped: [Chat] = docs.map(Self.mapChat)
                DispatchQueue.main.async {
                    self.chats = mapped
                }
            }
    }

    func stopListening() {
        chatsListener?.remove()
        chatsListener = nil
    }
    
    func markRead(chatId: String) {
           Firestore.firestore()
               .collection("chats").document(chatId)
               .collection("members").document(uid)
               .setData(["lastReadAt": FieldValue.serverTimestamp()], merge: true)
       }

    // Live list of messages (ascending for UI)
    @discardableResult
    func listenMessages(
        chatId: String,
        limit: Int = 100,
        onChange: @escaping ([Message]) -> Void
    ) -> ListenerRegistration {
        return db.collection("chats").document(chatId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snap, err in
                if let err = err {
                    print("listen messages error:", err)
                    onChange([])
                    return
                }
                let docs = snap?.documents ?? []
                // Drop any with unresolved serverTimestamp to avoid "blank" sort/render
                let items: [Message] = docs
                    .map(Self.mapMessage)
                    .filter { $0.createdAt != nil }
                    .sorted { ($0.createdAt!.dateValue()) < ($1.createdAt!.dateValue()) }

                onChange(items)
            }
    }

    // MARK: - Mapping helpers

    private static func mapChat(_ d: QueryDocumentSnapshot) -> Chat {
        let x = d.data()
        let participants = x["participantIds"] as? [String] ?? []
        let createdAt = x["createdAt"] as? Timestamp
        let lastText = x["lastMessageText"] as? String
        let lastAt = x["lastMessageAt"] as? Timestamp
        let lastSender = x["lastSenderId"] as? String

        return Chat(
            id: d.documentID,
            participantIds: participants,
            createdAt: createdAt,
            lastMessageText: lastText,
            lastMessageAt: lastAt,
            lastSenderId: lastSender
        )
    }

    private static func mapMessage(_ d: QueryDocumentSnapshot) -> Message {
        let x = d.data()
        let senderId = x["senderId"] as? String ?? ""
        let text = x["text"] as? String ?? ""
        let createdAt = x["createdAt"] as? Timestamp

        return Message(
            id: d.documentID,
            senderId: senderId,
            text: text,
            createdAt: createdAt
        )
    }
}
