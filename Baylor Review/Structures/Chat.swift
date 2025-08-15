import Foundation
import FirebaseFirestore

// MARK: - Core chat models

public struct Chat: Identifiable, Equatable, Hashable {
    public var id: String
    public var participantIds: [String]
    public var createdAt: Timestamp?
    public var lastMessageText: String?
    public var lastMessageAt: Timestamp?
    public var lastSenderId: String?

    public init(id: String,
                participantIds: [String],
                createdAt: Timestamp?,
                lastMessageText: String?,
                lastMessageAt: Timestamp?,
                lastSenderId: String?) {
        self.id = id
        self.participantIds = participantIds
        self.createdAt = createdAt
        self.lastMessageText = lastMessageText
        self.lastMessageAt = lastMessageAt
        self.lastSenderId = lastSenderId
    }
}

public struct Message: Identifiable, Equatable, Hashable {
    public var id: String
    public var senderId: String
    public var text: String
    public var createdAt: Timestamp?

    public init(id: String,
                senderId: String,
                text: String,
                createdAt: Timestamp?) {
        self.id = id
        self.senderId = senderId
        self.text = text
        self.createdAt = createdAt
    }
}

public struct ChatMember: Equatable, Hashable {
    public var lastReadAt: Timestamp?
    public init(lastReadAt: Timestamp? = nil) {
        self.lastReadAt = lastReadAt
    }
}

// MARK: - Reporting

/// Make this enum public so `ChatService.reportUser(reason:)` can be public.
public enum AbuseReason: String, CaseIterable, Identifiable {
    case harassmentOrHate   = "Harassment or hate"
    case sexualContent      = "Sexual content"
    case spam               = "Spam or scam"
    case selfHarmOrThreats  = "Self-harm or threats"
    case other              = "Other"

    public var id: String { rawValue }
}

/// Public error type used by `ChatService.reportUser(...)`.
public struct DuplicateUserReportError: LocalizedError {
    public init() {}
    public var errorDescription: String? {
        "You’ve already reported this user in this chat."
    }
}
