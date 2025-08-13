// FriendViewModel.swift

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum FriendStatus: String {
    case none, outgoing, incoming, friends
}

@MainActor
class FriendViewModel: ObservableObject {
    @Published var me: Friend?
    @Published private(set) var allUsers: [Friend] = []
    @Published var suggested: [Friend] = []
    @Published var searchResults: [Friend] = []
    @Published var hasLoaded = false

    // NEW: friendship status by other user id
    @Published var statuses: [String: FriendStatus] = [:]

    private let db = Firestore.firestore()
    private var searchWorkItem: DispatchWorkItem?
    private var friendshipListener: ListenerRegistration?

    // Search and filter inputs
    @Published var searchText: String = "" { didSet { performSearch() } }
    @Published var filterMajor: String = "" { didSet { performSearch() } }
    @Published var filterYear: String = "" { didSet { performSearch() } }

    private var myUID: String { Auth.auth().currentUser?.uid ?? "" }

    deinit { friendshipListener?.remove() }

    // MARK: - Load
    func loadData() {
        guard !myUID.isEmpty else { return }

        // Load current user profile
        db.collection("users").document(myUID).getDocument { [weak self] snap, error in
            guard let self else { return }
            if let error = error { print("Error loading user profile: \(error.localizedDescription)"); return }
            guard let data = snap?.data() else { print("No user profile data found"); return }

            let profile = Friend(
                id: myUID,
                fullName: data["fullName"] as? String ?? "",
                year: data["year"] as? String ?? "",
                major: data["major"] as? String ?? ""
            )
            Task { @MainActor in
                self.me = profile
                // Default filters
                self.filterMajor = profile.major
                self.filterYear  = profile.year
            }

            // Load all other users, then attach friendship listener
            self.loadAllUsers(excluding: self.myUID) { [weak self] in
                self?.attachFriendshipListener()
            }
        }
    }

    private func loadAllUsers(excluding myUID: String, completion: @escaping () -> Void) {
        db.collection("users").getDocuments { [weak self] snapshot, error in
            guard let self else { return }
            if let error = error { print("Error loading users: \(error.localizedDescription)"); self.hasLoaded = true; completion(); return }
            guard let documents = snapshot?.documents else { print("No users found"); self.hasLoaded = true; completion(); return }

            let friends = documents.compactMap { doc -> Friend? in
                guard doc.documentID != myUID else { return nil }
                let data = doc.data()
                return Friend(
                    id: doc.documentID,
                    fullName: data["fullName"] as? String ?? "",
                    year: data["year"] as? String ?? "",
                    major: data["major"] as? String ?? ""
                )
            }

            Task { @MainActor in
                self.allUsers = friends
                self.calculateSuggested()
                self.performSearch()
                self.hasLoaded = true
                completion()
            }
        }
    }

    // MARK: - Friendship realtime listener
    private func attachFriendshipListener() {
        friendshipListener?.remove()
        guard !myUID.isEmpty else { return }

        friendshipListener = db.collection("friendships")
            .whereField("users", arrayContains: myUID)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                var map: [String: FriendStatus] = [:]
                snap?.documents.forEach { doc in
                    let data = doc.data()
                    let users = (data["users"] as? [String]) ?? []
                    guard users.count == 2 else { return }
                    let other = (users[0] == self.myUID) ? users[1] : users[0]
                    let from  = data["from"] as? String ?? ""
                    let status = data["status"] as? String ?? "pending"

                    if status == "friends" { map[other] = .friends }
                    else { map[other] = (from == self.myUID) ? .outgoing : .incoming }
                }
                Task { @MainActor in
                    self.statuses = map
                }
            }
    }

    // MARK: - Helpers
    private func pairId(_ a: String, _ b: String) -> String {
        a < b ? "\(a)_\(b)" : "\(b)_\(a)"
    }

    func statusFor(_ otherId: String) -> FriendStatus {
        statuses[otherId] ?? .none
    }
    func sendRequest(to otherId: String) {
        guard !myUID.isEmpty, otherId != myUID else { return }
        let id  = pairId(myUID, otherId)
        let ref = db.collection("friendships").document(id)

        db.runTransaction({ (tx, errorPointer) -> Any? in
            do {
                let existing = try tx.getDocument(ref)
                if existing.exists {
                    return nil // already pending/friends
                }
                tx.setData([
                    "users": [self.myUID, otherId].sorted(),
                    "from": self.myUID,
                    "status": "pending",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ref)
                return nil
            } catch let err as NSError {
                errorPointer?.pointee = err
                return nil
            }
        }) { (_, error) in
            if let error { print("sendRequest error: \(error.localizedDescription)") }
        }
    }

    func cancelRequest(with otherId: String) {
        guard !myUID.isEmpty else { return }
        let id = pairId(myUID, otherId)
        db.collection("friendships").document(id).delete { err in
            if let err { print("cancelRequest error: \(err.localizedDescription)") }
        }
    }

    func declineRequest(from otherId: String) {
        cancelRequest(with: otherId)
    }

    func acceptRequest(from otherId: String) {
        guard !myUID.isEmpty else { return }
        let id  = pairId(myUID, otherId)
        let ref = db.collection("friendships").document(id)

        db.runTransaction({ (tx, errorPointer) -> Any? in
            do {
                let snap = try tx.getDocument(ref)
                guard snap.exists else {
                    errorPointer?.pointee = NSError(
                        domain: "Friends", code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Request not found"]
                    )
                    return nil
                }

                let status = snap.get("status") as? String
                let from   = snap.get("from") as? String
                guard status == "pending", from != self.myUID else {
                    errorPointer?.pointee = NSError(
                        domain: "Friends", code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid state to accept"]
                    )
                    return nil
                }

                tx.updateData(["status": "friends"], forDocument: ref)
                return nil
            } catch let err as NSError {
                errorPointer?.pointee = err
                return nil
            }
        }) { (_, error) in
            if let error { print("acceptRequest error: \(error.localizedDescription)") }
        }
    }

    func unfriend(_ otherId: String) {
        guard !myUID.isEmpty else { return }
        let id = pairId(myUID, otherId)
        db.collection("friendships").document(id).delete { [weak self] err in
            if let err {
                print("unfriend error: \(err.localizedDescription)")
                return
            }
            self?.deleteDirectChat(with: otherId)
        }
    }
    

    private func deleteDirectChat(with otherId: String, completion: ((Error?) -> Void)? = nil) {
        let cid = pairId(myUID, otherId)
        let chatRef = db.collection("chats").document(cid)
        let messagesRef = chatRef.collection("messages")
        let membersRef  = chatRef.collection("members")

        // 1) delete all messages (batched, recursive)
        deleteCollection(messagesRef, batchSize: 300) { [weak self] err in
            if let err { print("delete messages error:", err); completion?(err); return }

            // 2) delete all members docs
            membersRef.getDocuments { snap, err in
                if let err { print("get members error:", err); completion?(err); return }

                let batch = self?.db.batch()
                snap?.documents.forEach { batch?.deleteDocument($0.reference) }
                batch?.commit { err in
                    if let err { print("delete members error:", err); completion?(err); return }

                    // 3) finally delete the chat doc
                    chatRef.delete { err in
                        if let err { print("delete chat doc error:", err) }
                        completion?(err)
                    }
                }
            }
        }
    }


    private func deleteCollection(_ ref: CollectionReference,
                                  batchSize: Int = 300,
                                  completion: @escaping (Error?) -> Void) {
        ref.limit(to: batchSize).getDocuments { [weak self] snap, err in
            if let err { completion(err); return }
            guard let self else { completion(nil); return }

            let docs = snap?.documents ?? []
            guard !docs.isEmpty else { completion(nil); return }

            let batch = self.db.batch()
            docs.forEach { batch.deleteDocument($0.reference) }
            batch.commit { err in
                if let err { completion(err); return }
                // Recurse until empty
                self.deleteCollection(ref, batchSize: batchSize, completion: completion)
            }
        }
    }

    // MARK: - Lists (Friends / Incoming / Sent)
    var friendsList: [Friend] {
        idsToFriends(statuses.filter { $0.value == .friends }.map(\.key))
    }
    var incomingList: [Friend] {
        idsToFriends(statuses.filter { $0.value == .incoming }.map(\.key))
    }
    var sentList: [Friend] {
        idsToFriends(statuses.filter { $0.value == .outgoing }.map(\.key))
    }

    private func idsToFriends(_ ids: [String]) -> [Friend] {
        let index = Dictionary(uniqueKeysWithValues: allUsers.map { ($0.id, $0) })
        return ids.compactMap { index[$0] }.sorted { $0.fullName < $1.fullName }
    }

    // MARK: - Suggestions / Search (unchanged logic)
    private func calculateSuggested() {
        guard let me else { return }
        suggested = allUsers
            .filter { $0.year.lowercased() == me.year.lowercased() && $0.major.lowercased() == me.major.lowercased() }
            .sorted { $0.fullName < $1.fullName }
    }

    func updateSearchText(_ newText: String) {
        searchText = newText
        searchWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.performSearch() }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func performSearch() {
        guard !allUsers.isEmpty else { return }

        let searchTerm = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let majorFilter = filterMajor.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let yearFilter  = filterYear.trimmingCharacters(in: .whitespacesAndNewlines)

        if searchTerm.isEmpty && majorFilter.isEmpty && yearFilter.isEmpty {
            searchResults = allUsers.sorted { $0.fullName < $1.fullName }
            return
        }

        let scoredResults: [(friend: Friend, score: Int)] = allUsers.compactMap { friend in
            var score = 0
            var matches = false

            if !searchTerm.isEmpty {
                let nameMatch  = friend.fullName.lowercased().contains(searchTerm)
                let majorMatch = friend.major.lowercased().contains(searchTerm)
                let yearMatch  = friend.year.contains(searchTerm)
                if nameMatch { score += 10; matches = true }
                if majorMatch { score += 5;  matches = true }
                if yearMatch { score += 3;   matches = true }
            }

            if !majorFilter.isEmpty {
                if friend.major.lowercased().contains(majorFilter) { score += 5; matches = true }
                else if searchTerm.isEmpty { return nil }
            }

            if !yearFilter.isEmpty {
                if friend.year == yearFilter { score += 5; matches = true }
                else if searchTerm.isEmpty { return nil }
            }

            return matches ? (friend: friend, score: score) : nil
        }

        let sortedResults = scoredResults.sorted {
            $0.score == $1.score ? ($0.friend.fullName < $1.friend.fullName) : ($0.score > $1.score)
        }
        searchResults = sortedResults.map { $0.friend }
    }

    func clearFilters() {
        searchText = ""
        filterMajor = ""
        filterYear = ""
        if let me {
            filterMajor = me.major
            filterYear  = me.year
        }
    }

    func getPopularMajors() -> [String] {
        let majorCounts = Dictionary(grouping: allUsers, by: { $0.major })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        return Array(majorCounts.prefix(10).map { $0.key })
    }

    func getAvailableYears() -> [String] {
        let uniqueYears = Set(allUsers.map { $0.year })
        return uniqueYears.sorted()
    }
}
