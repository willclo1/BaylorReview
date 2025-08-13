import SwiftUI
import Foundation
import FirebaseAuth
import FirebaseFirestore



struct FindFriendsView: View {
    @StateObject private var vm = FriendViewModel()
    @State private var showingFilters = false
    @State private var searchText = ""
    @State private var selectedFriend: Friend?   // ⬅️ NEW

    init() {
        let barBG = UIColor(Color(hex: "#2E5930"))

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = barBG
        appearance.shadowColor = nil

        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navBar.compactScrollEdgeAppearance = appearance
        }
        navBar.tintColor = .white
        navBar.barStyle = .black
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FFF5E1"), Color(hex: "#F0E6D2")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(hex: "#004C26"))
                                .font(.system(size: 16))

                            TextField("Search by name, major, or year...", text: $searchText)
                                .foregroundColor(Color(hex: "#004C26"))
                                .minimumScaleFactor(0.8)
                                .onChange(of: searchText) { vm.updateSearchText($0) }
                                .onAppear {
                                    UITextField.appearance().attributedPlaceholder = NSAttributedString(
                                        string: "Search by name, major, or year...",
                                        attributes: [NSAttributedString.Key.foregroundColor: UIColor(Color(hex: "#004C26").opacity(0.7))]
                                    )
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#E8DCC6"))
                        .cornerRadius(12)
                        .shadow(color: Color(hex: "#EFEAD9").opacity(0.15), radius: 3, y: 2)

                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                showingFilters.toggle()
                            }
                        } label: {
                            Image(systemName: showingFilters ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: "#004C26"))
                        }
                    }
                    .padding(.horizontal)

                    // Filter Section
                    if showingFilters {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "graduationcap.fill")
                                    .foregroundColor(Color(hex: "#004C26"))
                                    .font(.system(size: 16))
                                Text("Filter Options")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "#004C26"))
                                Spacer()
                                Button("Clear") {
                                    vm.clearFilters()
                                    searchText = ""
                                }
                                .font(.caption)
                                .foregroundColor(Color(hex: "#004C26"))
                            }

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Major")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: "#004C26"))
                                    TextField("e.g. Computer Science", text: $vm.filterMajor)
                                        .foregroundColor(Color(hex: "#004C26"))
                                        .modernInputStyle()
                                        .minimumScaleFactor(0.8)
                                        .onAppear {
                                            UITextField.appearance().attributedPlaceholder = NSAttributedString(
                                                string: "e.g. Computer Science",
                                                attributes: [NSAttributedString.Key.foregroundColor: UIColor(Color(hex: "#004C26").opacity(0.7))]
                                            )
                                        }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Class Year")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: "#004C26"))
                                    TextField("e.g. 2026", text: $vm.filterYear)
                                        .keyboardType(.numberPad)
                                        .foregroundColor(Color(hex: "#004C26"))
                                        .modernInputStyle()
                                        .minimumScaleFactor(0.8)
                                        .onAppear {
                                            UITextField.appearance().attributedPlaceholder = NSAttributedString(
                                                string: "e.g. 2026",
                                                attributes: [NSAttributedString.Key.foregroundColor: UIColor(Color(hex: "#004C26").opacity(0.7))]
                                            )
                                        }
                                }
                            }
                        }
                        .padding()
                        .background(Color(hex: "#F5F0E8").opacity(0.8))
                        .cornerRadius(16)
                        .shadow(color: Color(hex: "#EFEAD9").opacity(0.08), radius: 6, y: 3)
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }

                    // Results Summary
                    if !vm.searchResults.isEmpty || !vm.suggested.isEmpty {
                        HStack {
                            if !searchText.isEmpty || !vm.filterMajor.isEmpty || !vm.filterYear.isEmpty {
                                Text("\(vm.searchResults.count) results found")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#004C26"))
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FFF5E1"), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Suggested (only when not searching)
                        if !vm.suggested.isEmpty && searchText.isEmpty {
                            SectionHeader(
                                title: "Suggested for You",
                                subtitle: "Students in your major and year",
                                icon: "person.2.fill"
                            )
                            .foregroundColor(Color(hex: "#004C26"))

                            LazyVStack(spacing: 8) {
                                ForEach(vm.suggested) { friend in
                                    EnhancedFriendRow(
                                        friend: friend,
                                        isReverseIcon: false,
                                        status: vm.statusFor(friend.id),
                                        onAdd:     { vm.sendRequest(to: friend.id) },
                                        onCancel:  { vm.cancelRequest(with: friend.id) },
                                        onAccept:  { vm.acceptRequest(from: friend.id) },
                                        onDecline: { vm.declineRequest(from: friend.id) },
                                        onUnfriend:{ vm.unfriend(friend.id) },
                                        onSelect:  { selectedFriend = friend }   // ⬅️ NEW
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Search results (or All Students when not searching)
                        if !vm.searchResults.isEmpty {
                            SectionHeader(
                                title: searchText.isEmpty ? "All Students" : "Search Results",
                                subtitle: searchText.isEmpty ? "Browse all available students" : "Matching your search criteria",
                                icon: "person.3.fill"
                            )
                            .foregroundColor(Color(hex: "#004C26"))

                            LazyVStack(spacing: 8) {
                                ForEach(vm.searchResults) { friend in
                                    EnhancedFriendRow(
                                        friend: friend,
                                        isReverseIcon: true,
                                        status: vm.statusFor(friend.id),
                                        onAdd:     { vm.sendRequest(to: friend.id) },
                                        onCancel:  { vm.cancelRequest(with: friend.id) },
                                        onAccept:  { vm.acceptRequest(from: friend.id) },
                                        onDecline: { vm.declineRequest(from: friend.id) },
                                        onUnfriend:{ vm.unfriend(friend.id) },
                                        onSelect:  { selectedFriend = friend }   // ⬅️ NEW
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Empty state
                        if vm.searchResults.isEmpty && vm.suggested.isEmpty && vm.hasLoaded {
                            EmptyStateView(searchText: searchText)
                                .padding(.top, 40)
                                .foregroundColor(Color(hex: "#004C26"))
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Find Friends")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color(hex: "#2E5930"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: FriendsHubView(vm: vm)) {
                    Image(systemName: "person.2.fill")
                }
            }
        }
        .onAppear { vm.loadData() }
        .sheet(item: $selectedFriend) { friend in
            NavigationStack {
                FriendProfileView(friend: friend, vm: vm)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .safeAreaInset(edge: .bottom) {
            BannerAdView(adUnitID: AdConfig.bannerUnitID)
            .frame(height: 50)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
        }
    }
}


struct SectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(Color(hex: "#004C26"))
                        .font(.system(size: 16, weight: .semibold))
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#004C26"))
                        .minimumScaleFactor(0.8)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color(hex: "#004C26"))
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Row

struct EnhancedFriendRow: View {
    let friend: Friend
    let isReverseIcon: Bool

    // Relationship state + actions
    let status: FriendStatus
    let onAdd: () -> Void
    let onCancel: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onUnfriend: () -> Void
    let onSelect: () -> Void     // ⬅️ NEW

    @State private var isPressed = false

    private var gradientColors: [Color] {
        let baseColors = [
            [Color(hex: "#004C26"), Color(hex: "#006B35")],
            [Color(hex: "#D4A574"), Color(hex: "#B8935A")],
            [Color(hex: "#2E5930"), Color(hex: "#004C26")],
            [Color(hex: "#C9A961"), Color(hex: "#A8924E")],
            [Color(hex: "#1B4D20"), Color(hex: "#2E5930")]
        ]
        let hash = abs(friend.fullName.hashValue)
        return baseColors[hash % baseColors.count]
    }

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .overlay(
                    Text(String(friend.fullName.prefix(1)))
                        .foregroundColor(Color(hex: "#004C26"))
                        .font(.system(size: 20, weight: .bold))
                )
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            // Meta
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.fullName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "#004C26"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#004C26"))
                        Text(friend.major)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#004C26"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#004C26"))
                        Text("Class of \(friend.year)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#004C26"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }

            Spacer()

            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color(hex: "#EFEAD9").opacity(0.06), radius: 4, y: 2)
        )
        .contentShape(Rectangle())          // ⬅️ make whole row tappable
        .onTapGesture { onSelect() }        // ⬅️ open profile on card tap (buttons still work)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            switch status {
            case .none:
                pill(primaryIcon: isReverseIcon ? "arrow.uturn.left" : "plus", title: "Add", action: onAdd)

            case .outgoing:
                pill(primaryIcon: "clock", title: "Sent", disabled: true)
                pillOutline(primaryIcon: "xmark", title: "Cancel", action: onCancel)

            case .incoming:
                pill(primaryIcon: "checkmark", title: "Accept", action: onAccept)
                pillOutline(primaryIcon: "xmark", title: "Decline", action: onDecline)

            case .friends:
                pill(primaryIcon: "checkmark.seal.fill", title: "Friends", disabled: true)
                pillOutline(primaryIcon: "person.fill.xmark", title: "Remove", action: onUnfriend)
            }
        }
    }

    @ViewBuilder
    private func pill(primaryIcon: String, title: String, disabled: Bool = false, action: (() -> Void)? = nil) -> some View {
        Button(action: { action?() }) {
            HStack(spacing: 6) {
                Image(systemName: primaryIcon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .allowsTightening(true)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: "#004C26")))
            .foregroundColor(.white)
            .opacity(disabled ? 0.6 : 1.0)
        }
        .disabled(disabled || action == nil)
    }

    @ViewBuilder
    private func pillOutline(primaryIcon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: primaryIcon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .allowsTightening(true)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#004C26"), lineWidth: 1))
            .foregroundColor(Color(hex: "#004C26"))
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let searchText: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#004C26").opacity(0.6))

            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No students found" : "No results for '\(searchText)'")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#004C26"))
                    .minimumScaleFactor(0.8)

                Text(searchText.isEmpty
                     ? "Try adjusting your filters or check back later."
                     : "Try different search terms or clear your filters.")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#004C26"))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 40)
    }
}

private extension View {
    func modernInputStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#EFEAD9"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#004C26").opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Friend Profile (Sheet Content)

struct FriendProfileView: View {
    let friend: Friend
    @ObservedObject var vm: FriendViewModel

    @Environment(\.dismiss) private var dismiss

    private var status: FriendStatus {
        vm.statusFor(friend.id)
    }

    private var gradientColors: [Color] {
        let baseColors = [
            [Color(hex: "#004C26"), Color(hex: "#006B35")],
            [Color(hex: "#D4A574"), Color(hex: "#B8935A")],
            [Color(hex: "#2E5930"), Color(hex: "#004C26")],
            [Color(hex: "#C9A961"), Color(hex: "#A8924E")],
            [Color(hex: "#1B4D20"), Color(hex: "#2E5930")]
        ]
        let hash = abs(friend.fullName.hashValue)
        return baseColors[hash % baseColors.count]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Header
                VStack(spacing: 12) {
                    Circle()
                        .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 96, height: 96)
                        .overlay(
                            Text(String(friend.fullName.prefix(1)))
                                .foregroundColor(Color(hex: "#004C26"))
                                .font(.system(size: 42, weight: .bold))
                        )
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                    Text(friend.fullName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "#004C26"))

                    HStack(spacing: 10) {
                        Label(friend.major, systemImage: "graduationcap.fill")
                        Label("Class of \(friend.year)", systemImage: "calendar")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#004C26"))
                }
                .padding(.top, 8)

                // Actions
                VStack(spacing: 12) {
                    switch status {
                    case .none:
                        PrimaryButton(title: "Add Friend", icon: "person.badge.plus") {
                            vm.sendRequest(to: friend.id)
                        }

                    case .outgoing:
                        DisabledButton(title: "Request Sent", icon: "clock")
                        SecondaryButton(title: "Cancel Request", icon: "xmark") {
                            vm.cancelRequest(with: friend.id)
                        }

                    case .incoming:
                        PrimaryButton(title: "Accept Request", icon: "checkmark") {
                            vm.acceptRequest(from: friend.id)
                        }
                        SecondaryButton(title: "Decline", icon: "xmark") {
                            vm.declineRequest(from: friend.id)
                        }

                    case .friends:
                        PrimaryButton(title: "Message", icon: "message.fill") {
                            // TODO: Hook up to your chat flow/navigation
                        }
                        SecondaryButton(title: "Remove Friend", icon: "person.fill.xmark") {
                            vm.unfriend(friend.id)
                        }
                    }
                }
                .padding(.top, 6)

                // Info section
                VStack(alignment: .leading, spacing: 12) {
                    Text("About")
                        .font(.headline)
                        .foregroundColor(Color(hex: "#004C26"))

                    VStack(spacing: 8) {
                        InfoRow(icon: "book.closed.fill", label: "Major", value: friend.major)
                        InfoRow(icon: "calendar", label: "Class Year", value: friend.year)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .shadow(color: Color(hex: "#EFEAD9").opacity(0.08), radius: 6, y: 3)
                    )
                }
                .padding(.horizontal)

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#FFF5E1"), Color(hex: "#F0E6D2")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundColor(.white)
            }
        }
        .toolbarBackground(Color(hex: "#2E5930"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Profile UI helpers

private struct PrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title).fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: "#004C26")))
            .foregroundColor(.white)
        }
    }
}

private struct SecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title).fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: "#004C26"), lineWidth: 1))
            .foregroundColor(Color(hex: "#004C26"))
        }
    }
}

private struct DisabledButton: View {
    let title: String
    let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title).fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: "#004C26").opacity(0.2)))
        .foregroundColor(Color(hex: "#004C26"))
    }
}

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundColor(Color(hex: "#004C26"))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(Color(hex: "#004C26").opacity(0.8))
                Text(value)
                    .font(.body)
                    .foregroundColor(Color(hex: "#004C26"))
            }
            Spacer()
        }
    }
}

