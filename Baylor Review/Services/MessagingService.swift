import Foundation
import FirebaseAuth
import FirebaseFirestore
import ObjectiveC 

@MainActor
public final class ChatService: ObservableObject {
    private let db = Firestore.firestore()
    private let uid: String

    @Published public var chats: [Chat] = []
    private var chatsListener: ListenerRegistration?

    public init(currentUserId: String) {
        self.uid = currentUserId
        startSafetyListeners()
    }

    deinit {
        chatsListener?.remove()
        stopSafetyListeners()
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

    // Send a text and update chat summary (completion is optional/backwards-compatible)
    public func send(
        text: String,
        in chatId: String,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion?(.success(()))
            return
        }

        let msgRef = db.collection("chats").document(chatId)
            .collection("messages").document()

        let message: [String: Any] = [
            "senderId": uid,
            "text": trimmed,
            "createdAt": FieldValue.serverTimestamp()
        ]

        msgRef.setData(message) { [weak self] err in
            if let err = err {
                print("send msg error:", err)
                completion?(.failure(err))
                return
            }

            let chatRef = self?.db.collection("chats").document(chatId)
            chatRef?.setData([
                "lastMessageText": trimmed,
                "lastMessageAt": FieldValue.serverTimestamp(),
                "lastSenderId": self?.uid ?? ""
            ], merge: true) { err in
                if let err = err {
                    print("update chat summary error:", err)
                    completion?(.failure(err))
                } else {
                    completion?(.success(()))
                }
            }
        }
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
        stopSafetyListeners()
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

// MARK: - Safety (blocks/mutes) via associated storage
extension ChatService {
    // KVC-friendly boxes (don’t require stored properties in the class)
    @objc dynamic public var _blockedIdsBox: NSMutableSet {
        if let box = objc_getAssociatedObject(self, &AssocKeys.blocked) as? NSMutableSet { return box }
        let box = NSMutableSet()
        objc_setAssociatedObject(self, &AssocKeys.blocked, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return box
    }
    @objc dynamic public var _mutedIdsBox: NSMutableSet {
        if let box = objc_getAssociatedObject(self, &AssocKeys.muted) as? NSMutableSet { return box }
        let box = NSMutableSet()
        objc_setAssociatedObject(self, &AssocKeys.muted, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return box
    }

    public var blockedIds: Set<String> { Set(_blockedIdsBox.compactMap { $0 as? String }) }
    public var mutedIds: Set<String> { Set(_mutedIdsBox.compactMap { $0 as? String }) }

    private struct AssocKeys {
        static var blocked = "blocked_box"
        static var muted = "muted_box"
        static var blockListener = "block_listener"
        static var muteListener  = "mute_listener"
    }

    public func startSafetyListeners() {
        stopSafetyListeners()
        let uid = currentUid

        let bl = db.collection("users").document(uid).collection("blocks")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self._blockedIdsBox.removeAllObjects()
                    snap?.documents.forEach { self._blockedIdsBox.add($0.documentID) }
                }
            }
        objc_setAssociatedObject(self, &AssocKeys.blockListener, bl, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let ml = db.collection("users").document(uid).collection("mutes")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self._mutedIdsBox.removeAllObjects()
                    snap?.documents.forEach { self._mutedIdsBox.add($0.documentID) }
                }
            }
        objc_setAssociatedObject(self, &AssocKeys.muteListener, ml, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    nonisolated public func stopSafetyListeners() {
        if let bl = objc_getAssociatedObject(self, &AssocKeys.blockListener) as? ListenerRegistration {
            bl.remove()
        }
        if let ml = objc_getAssociatedObject(self, &AssocKeys.muteListener) as? ListenerRegistration {
            ml.remove()
        }
        objc_setAssociatedObject(self, &AssocKeys.blockListener, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &AssocKeys.muteListener,  nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // Actions
    public func block(userId: String, displayName: String?, completion: @escaping (Result<Void,Error>)->Void) {
        let ref = db.collection("users").document(currentUid).collection("blocks").document(userId)
        ref.setData([
            "createdAt": FieldValue.serverTimestamp(),
            "displayName": displayName ?? userId
        ], merge: true) { err in
            if let err = err { completion(.failure(err)) } else { completion(.success(())) }
        }
    }

    public func unblock(userId: String, completion: @escaping (Result<Void,Error>)->Void) {
        db.collection("users").document(currentUid).collection("blocks").document(userId)
            .delete { err in
                if let err = err { completion(.failure(err)) } else { completion(.success(())) }
            }
    }

    public func mute(userId: String, displayName: String?, completion: @escaping (Result<Void,Error>)->Void) {
        let ref = db.collection("users").document(currentUid).collection("mutes").document(userId)
        ref.setData([
            "createdAt": FieldValue.serverTimestamp(),
            "displayName": displayName ?? userId
        ], merge: true) { err in
            if let err = err { completion(.failure(err)) } else { completion(.success(())) }
        }
    }

    public func unmute(userId: String, completion: @escaping (Result<Void,Error>)->Void) {
        db.collection("users").document(currentUid).collection("mutes").document(userId)
            .delete { err in
                if let err = err { completion(.failure(err)) } else { completion(.success(())) }
            }
    }

    /// Check both directions (I blocked them OR they blocked me).
    /// Note: Reading the *other* user’s block doc requires a permissive rule (see below).
    public func blockedEitherWay(with otherUid: String, completion: @escaping (_ iBlocked: Bool, _ theyBlocked: Bool) -> Void) {
        let myBlockRef    = db.collection("users").document(currentUid).collection("blocks").document(otherUid)
        let theirBlockRef = db.collection("users").document(otherUid).collection("blocks").document(currentUid)

        myBlockRef.getDocument { mySnap, _ in
            theirBlockRef.getDocument { theirSnap, _ in
                // If rules deny the second read, `theirSnap` will be nil; treat as unknown/false.
                completion(mySnap?.exists == true, theirSnap?.exists == true)
            }
        }
    }

    /// Convenience to get the "other" id for a 1:1 chat
    public func otherParticipantId(for chatId: String, completion: @escaping (String?) -> Void) {
        db.collection("chats").document(chatId).getDocument { snap, _ in
            let ids = snap?.data()?["participantIds"] as? [String] ?? []
            completion(ids.first { $0 != self.currentUid })
        }
    }
}

