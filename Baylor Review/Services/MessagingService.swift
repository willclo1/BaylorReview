import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
public final class ChatService: ObservableObject {
    private let db = Firestore.firestore()
    private let uid: String

    @Published public var chats: [Chat] = []
    private var chatsListener: ListenerRegistration?

    public init(currentUserId: String) {
        self.uid = currentUserId
    }

    deinit {
        chatsListener?.remove()
    }

    public var currentUid: String { uid }

    // Deterministic id for a 1:1 chat
    public func chatId(with otherId: String) -> String {
        [uid, otherId].sorted().joined(separator: "_")
    }

    // Create chat if missing, otherwise return existing id
    public func getOrCreateChat(with otherId: String, completion: @escaping (String) -> Void) {
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
    public func send(text: String, in chatId: String) {
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

    // Realtime list of chats for current user
    public func listenChats() {
        chatsListener?.remove()

        // Ensure composite index: participantIds (array_contains) + lastMessageAt (desc)
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
                Task { @MainActor in
                    self.chats = mapped
                }
            }
    }

    public func stopListening() {
        chatsListener?.remove()
        chatsListener = nil
    }

    public func markRead(chatId: String) {
        db.collection("chats").document(chatId)
            .collection("members").document(uid)
            .setData(["lastReadAt": FieldValue.serverTimestamp()], merge: true)
    }

    // Live list of messages (ascending for UI)
    @discardableResult
    public func listenMessages(
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
                let items: [Message] = docs
                    .map(Self.mapMessage)
                    .filter { $0.createdAt != nil }
                    .sorted { ($0.createdAt!.dateValue()) < ($1.createdAt!.dateValue()) }

                onChange(items)
            }
    }


    public func reportUser(
        reportedUid: String,
        in chatId: String,
        reason: AbuseReason,
        details: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let reports = db.collection("reports_users")

        reports
            .whereField("reporterUid", isEqualTo: uid)
            .whereField("reportedUid", isEqualTo: reportedUid)
            .whereField("chatId", isEqualTo: chatId)
            .limit(to: 1)
            .getDocuments { snapshot, err in
                if let err = err {
                    completion(.failure(err))
                    return
                }
                if let snap = snapshot, !snap.documents.isEmpty {
                    completion(.failure(DuplicateUserReportError()))
                    return
                }

                var payload: [String: Any] = [
                    "reporterUid": self.uid,
                    "reportedUid": reportedUid,
                    "chatId": chatId,
                    "reason": reason.rawValue,
                    "status": "pending",
                    "createdAt": FieldValue.serverTimestamp()
                ]
                if let details, !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    payload["details"] = details
                }

                reports.addDocument(data: payload) { err in
                    if let err = err { completion(.failure(err)) }
                    else { completion(.success(())) }
                }
            }
    }

    // MARK: - Mapping helpers

    private static func mapChat(_ d: QueryDocumentSnapshot) -> Chat {
        let x = d.data()
        return Chat(
            id: d.documentID,
            participantIds: x["participantIds"] as? [String] ?? [],
            createdAt: x["createdAt"] as? Timestamp,
            lastMessageText: x["lastMessageText"] as? String,
            lastMessageAt: x["lastMessageAt"] as? Timestamp,
            lastSenderId: x["lastSenderId"] as? String
        )
    }

    private static func mapMessage(_ d: QueryDocumentSnapshot) -> Message {
        let x = d.data()
        return Message(
            id: d.documentID,
            senderId: x["senderId"] as? String ?? "",
            text: x["text"] as? String ?? "",
            createdAt: x["createdAt"] as? Timestamp
        )
    }
}
