import Foundation
import FirebaseFirestore

// MARK: - Core chat models

public struct Chat: Identifiable, Equatable {
    public var id: String
    public var participantIds: [String]
    public var createdAt: Timestamp?
    public var lastMessageText: String?
    public var lastMessageAt: Timestamp?
    public var lastSenderId: String?
}

public struct Message: Identifiable, Equatable {
    public var id: String
    public var senderId: String
    public var text: String
    public var createdAt: Timestamp?
}

public struct ChatMember {
    public var lastReadAt: Timestamp?
}

// MARK: - Reporting types

public enum AbuseReason: String, CaseIterable, Identifiable {
    case harassmentOrHate = "Harassment or hate"
    case profanityOrInappropriate = "Profanity / inappropriate"
    case misleadingOrSpam = "Misleading / spam"
    case privateInfo = "Private info / doxxing"
    case other = "Other"

    public var id: String { rawValue }
}

public struct DuplicateUserReportError: LocalizedError {
    public var errorDescription: String? {
        "You’ve already reported this user in this chat."
    }
}
