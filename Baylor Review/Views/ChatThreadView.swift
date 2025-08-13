import SwiftUI
import FirebaseFirestore

struct ChatThreadView: View {
    let chatId: String
    let service: ChatService   

    @State private var messages: [Message] = []
    @State private var listener: ListenerRegistration?
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
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
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#2E5930"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
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
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        service.send(text: text, in: chatId)
        inputText = ""
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
