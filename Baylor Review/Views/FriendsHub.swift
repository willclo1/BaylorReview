import SwiftUI

struct FriendsHubView: View {
    @ObservedObject var vm: FriendViewModel
    @State private var tab: Tab = .friends

    enum Tab: String, CaseIterable { case friends = "Friends", incoming = "Incoming", sent = "Sent" }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FFF5E1"), Color(hex: "#F0E6D2")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                // Segmented with counts
                Picker("", selection: $tab) {
                    Text("\(Tab.friends.rawValue) (\(friendsCount))").tag(Tab.friends)
                    Text("\(Tab.incoming.rawValue) (\(incomingCount))").tag(Tab.incoming)
                    Text("\(Tab.sent.rawValue) (\(sentCount))").tag(Tab.sent)
                }
                .pickerStyle(.segmented)
                .tint(Color(hex: "#2E5930"))
                .padding([.horizontal, .top])

                // List
                List(currentList) { f in
                    FriendRow(
                        friend: f,
                        tab: tab,
                        accept: { vm.acceptRequest(from: f.id) },
                        decline: { vm.declineRequest(from: f.id) },
                        cancel: { vm.cancelRequest(with: f.id) },
                        remove: { vm.unfriend(f.id) },
                        avatarColors: gradientColors(for: f.fullName)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        switch tab {
                        case .incoming:
                            Button { vm.acceptRequest(from: f.id) } label: { Label("Accept", systemImage: "checkmark") }
                                .tint(Color(hex: "#2E5930"))
                            Button(role: .destructive) { vm.declineRequest(from: f.id) } label: { Label("Decline", systemImage: "xmark") }
                        case .sent:
                            Button(role: .destructive) { vm.cancelRequest(with: f.id) } label: { Label("Cancel", systemImage: "xmark") }
                        case .friends:
                            Button(role: .destructive) { vm.unfriend(f.id) } label: { Label("Remove", systemImage: "person.fill.xmark") }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color(hex: "#2E5930"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .onAppear { if !vm.hasLoaded { vm.loadData() } }
        .animation(.easeOut(duration: 0.2), value: tab)
    }

    // MARK: - Computed

    private var currentList: [Friend] {
        switch tab {
        case .friends:  return vm.friendsList
        case .incoming: return vm.incomingList
        case .sent:     return vm.sentList
        }
    }

    private var friendsCount: Int { vm.friendsList.count }
    private var incomingCount: Int { vm.incomingList.count }
    private var sentCount: Int { vm.sentList.count }

    // MARK: - Avatar color helper

    private func gradientColors(for name: String) -> [Color] {
        let palettes: [[Color]] = [
            [Color(hex: "#2E5930"), Color(hex: "#1B4D20")],
            [Color(hex: "#C9A961"), Color(hex: "#A8924E")],
            [Color(hex: "#D4A574"), Color(hex: "#B8935A")],
            [Color(hex: "#006B35"), Color(hex: "#2E5930")]
        ]
        let idx = abs(name.hashValue) % palettes.count
        return palettes[idx]
    }
}

// MARK: - Row Subview (keeps type-checking fast)

private struct FriendRow: View {
    let friend: Friend
    let tab: FriendsHubView.Tab
    let accept: () -> Void
    let decline: () -> Void
    let cancel: () -> Void
    let remove: () -> Void
    let avatarColors: [Color]

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(LinearGradient(colors: avatarColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(friend.fullName.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                )

            // Meta
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.fullName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "#004C26"))
                    .lineLimit(1)

                Text("\(friend.major) • \(friend.year)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#004C26").opacity(0.85))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Actions (bigger, no clipping)
            switch tab {
            case .incoming:
                HStack(spacing: 10) {
                    pillFilled("checkmark", "Accept", action: accept)
                    pillOutline("xmark", "Decline", action: decline)
                }
            case .sent:
                pillOutline("xmark", "Cancel", action: cancel)
            case .friends:
                pillOutline("person.fill.xmark", "Remove", action: remove)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }

    // MARK: - Buttons

    private func pillFilled(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.95)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: "#004C26")))
            .foregroundColor(.white)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }

    private func pillOutline(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.95)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(hex: "#004C26"), lineWidth: 1)
            )
            .foregroundColor(Color(hex: "#004C26"))
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}
