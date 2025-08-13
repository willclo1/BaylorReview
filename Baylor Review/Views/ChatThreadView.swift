import SwiftUI
import FirebaseFirestore
import FirebaseAuth

private struct UserLite: Identifiable, Equatable {
    let id: String
    let displayName: String
}



public struct ChatThreadView: View {
    public let chatId: String
    public let service: ChatService

    @State private var messages: [Message] = []
    @State private var listener: ListenerRegistration?
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    // Reporting UI state (NEW)
    @State private var participants: [UserLite] = []   // other users in this chat
    @State private var selectedUserIndex: Int = 0
    @State private var showReportSheet = false
    @State private var reportThanks = false
    @State private var reportError: String?

    private var selectedUser: UserLite? {
        guard !participants.isEmpty, selectedUserIndex < participants.count else { return nil }
        return participants[selectedUserIndex]
    }

    public init(chatId: String, service: ChatService) {
        self.chatId = chatId
        self.service = service
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, m in
                            if shouldShowDayDivider(at: index) {
                                DayDivider(date: messages[index].createdAt?.dateValue())
                                    .padding(.vertical, 4)
                            }

                            MessageBubble(
                                message: m,
                                isMine: m.senderId == service.currentUid
                            )
                            .id(m.id)
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: inputFocused) { focused in
                    if focused, let last = messages.last?.id {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Composer
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message…", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "#E8DCC6"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#2E5930").opacity(0.25), lineWidth: 1)
                    )

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .padding(12)
                        .background(Circle().fill(Color(hex: "#2E5930")))
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: "#2E5930").opacity(0.3), radius: 4, y: 2)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
            }
            .padding(.all, 10)
            .background(
                ZStack {
                    Color(hex: "#EFEAD9").opacity(0.7)
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 0.5)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#2E5930"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .toolbar {
            // Center title: username picker (NEW)
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 16, weight: .semibold))
                    if participants.isEmpty {
                        Text("Chat")
                            .font(.headline)
                    } else {
                        Picker("", selection: $selectedUserIndex) {
                            ForEach(participants.indices, id: \.self) { idx in
                                Text(participants[idx].displayName).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .font(.headline)
                        .tint(.white)
                    }
                }
            }

            // Trailing: report button (NEW)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showReportSheet = true
                } label: {
                    Image(systemName: "flag.fill")
                }
                .disabled(selectedUser == nil)
                .accessibilityLabel("Report selected user")
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#FFF5E1"), Color(hex: "#F0E6D2")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
        .onAppear {
            listener?.remove()
            listener = service.listenMessages(chatId: chatId) { msgs in
                self.messages = msgs
                service.markRead(chatId: chatId)
            }
            loadParticipants() // NEW
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        // Report sheet + alerts (NEW)
        .sheet(isPresented: $showReportSheet) {
            if let victim = selectedUser {
                ReportUserSheet(username: victim.displayName) { reason, details in
                    service.reportUser(
                        reportedUid: victim.id,
                        in: chatId,
                        reason: reason,
                        details: details
                    ) { result in
                        switch result {
                        case .success: reportThanks = true
                        case .failure(let err): reportError = err.localizedDescription
                        }
                    }
                }
            }
        }
        .alert("Thanks for the report", isPresented: $reportThanks) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Our team will review it shortly.")
        }
        .alert("Couldn't send report", isPresented: Binding(
            get: { reportError != nil },
            set: { if !$0 { reportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reportError ?? "Unknown error.")
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        service.send(text: text, in: chatId)
        inputText = ""
    }

    // Resolve other participants' names for the picker (NEW)
    private func loadParticipants() {
        let db = Firestore.firestore()
        db.collection("chats").document(chatId).getDocument { snap, err in
            if let err = err { print("participants error:", err); return }
            let ids = (snap?.data()?["participantIds"] as? [String] ?? [])
                .filter { $0 != service.currentUid }

            if ids.isEmpty { return }

            let group = DispatchGroup()
            var results: [UserLite] = []
            for id in ids {
                group.enter()
                db.collection("users").document(id).getDocument { dsnap, _ in
                    let name = dsnap?.data()?["fullName"] as? String
                    let lite = UserLite(id: id, displayName: (name?.isEmpty == false ? name! : id))
                    results.append(lite)
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                self.participants = results.sorted { $0.displayName < $1.displayName }
                self.selectedUserIndex = 0
            }
        }
    }

    // MARK: - Day divider logic
    private func shouldShowDayDivider(at index: Int) -> Bool {
        guard index < messages.count else { return false }
        guard let curr = messages[index].createdAt?.dateValue() else { return false }
        if index == 0 { return true }
        guard let prev = messages[index - 1].createdAt?.dateValue() else { return true }
        return !Calendar.current.isDate(curr, inSameDayAs: prev)
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: Message
    let isMine: Bool

    private var maxBubbleWidth: CGFloat { UIScreen.main.bounds.width * 0.68 }

    private var timeString: String {
        guard let date = message.createdAt?.dateValue() else { return "" }
        return MessageBubble.timeFormatter.string(from: date)
    }

    var body: some View {
        HStack {
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundColor(isMine ? .white : Color(hex: "#0E3A1E"))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isMine {
                                LinearGradient(
                                    colors: [Color(hex: "#2E5930"), Color(hex: "#006B35")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            } else {
                                Color(hex: "#F5F0E8")
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: maxBubbleWidth, alignment: isMine ? .trailing : .leading)

                Text(timeString)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#F5B800"))
                    .padding(isMine ? .trailing : .leading, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .padding(.horizontal, 12)
        .transition(.opacity.combined(with: .move(edge: isMine ? .trailing : .leading)))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}

// MARK: - Day divider

private struct DayDivider: View {
    let date: Date?

    var body: some View {
        HStack {
            Divider().background(Color.black.opacity(0.15))
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: "#E8DCC6").opacity(0.9)))
                .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                .foregroundColor(Color(hex: "#0E3A1E"))
            Divider().background(Color.black.opacity(0.15))
        }
        .padding(.horizontal, 16)
    }

    private var label: String {
        guard let d = date else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }
}

// MARK: - Report sheet

private struct ReportUserSheet: View {
    let username: String
    var onSubmit: (_ reason: AbuseReason, _ details: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: AbuseReason = .harassmentOrHate
    @State private var details: String = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Report \(username)")
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "#004C26"))
                    Text("Tell us what happened. We’ll review it.")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#004C26").opacity(0.75))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(hex: "#004C26"))
                    Picker("Reason", selection: $reason) {
                        ForEach(AbuseReason.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Details (optional)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(hex: "#004C26"))
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)  
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "#F5B800").opacity(0.4), lineWidth: 1)
                        )
                }

                Spacer()
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color(hex: "#FFF5E1"), Color(hex: "#F5F0DC")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSubmit(reason, trimmed.isEmpty ? nil : trimmed)
                        dismiss()
                    } label: {
                        Text("Report").bold()
                    }
                }
            }
        }
    }
}
