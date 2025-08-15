import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()
    @EnvironmentObject private var auth: AuthViewModel
    @State private var confirmLogout = false

    private let columns = [ GridItem(.adaptive(minimum: 300), spacing: 16) ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [ Color(hex: "#FFF5E1"), Color(hex: "#F5F0DC") ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Main content
                        VStack(spacing: 24) {
                            // Logo + title
                            VStack(spacing: 16) {
                                Image("logo2")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 260, height: 260)
                                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                                VStack(spacing: 8) {
                                    Text("BU Review")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: "#004C26"))

                                    Text("Find study buddies and share professor ratings")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(hex: "#F5B800"))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 32)
                                }
                            }

                            // Action grid (2x2)
                            LazyVGrid(columns: columns, spacing: 16) {
                                // Find Friends
                                Button {
                                    path.append(Route.findFriends)
                                } label: {
                                    CardButtonLabel(
                                        icon: "person.2.fill",
                                        iconColor: Color(hex: "#004C26"),
                                        title: "Find Friends",
                                        titleColor: Color(hex: "#004C26"),
                                        subtitle: "Connect with study partners",
                                        subtitleColor: Color(hex: "#004C26"),
                                        backgroundIconColor: Color(hex: "#004C26").opacity(0.1)
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())

                                // Messages
                                Button {
                                    path.append(Route.messages)
                                } label: {
                                    CardButtonLabel(
                                        icon: "bubble.left.and.bubble.right.fill",
                                        iconColor: Color(hex: "#004C26"),
                                        title: "Messages",
                                        titleColor: Color(hex: "#004C26"),
                                        subtitle: "Start a conversation",
                                        subtitleColor: Color(hex: "#004C26"),
                                        backgroundIconColor: Color(hex: "#004C26").opacity(0.1)
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())

                                // Rate Professor
                                Button {
                                    path.append(Route.rateProfessor)
                                } label: {
                                    CardButtonLabel(
                                        icon: "star.fill",
                                        iconColor: Color(hex: "#F5B800"),
                                        title: "Rate Professor",
                                        titleColor: Color(hex: "#F5B800"),
                                        subtitle: "Share your experience",
                                        subtitleColor: Color(hex: "#004C26"),
                                        backgroundIconColor: Color(hex: "#F5B800").opacity(0.1)
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())


                                Button {
                                    path.append(Route.professorList)
                                } label: {
                                    CardButtonLabel(
                                        icon: "list.bullet",
                                        iconColor: Color(hex: "#F5B800"),
                                        title: "All Professors",
                                        titleColor: Color(hex: "#F5B800"),
                                        subtitle: "Browse directory",
                                        subtitleColor: Color(hex: "#004C26"),
                                        backgroundIconColor: Color(hex: "#F5B800").opacity(0.1)
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 36)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
   
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        confirmLogout = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.headline)
                            Text("Log Out")
                                .font(.subheadline).fontWeight(.semibold)
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.15)) 
                        )
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        "Are you sure you want to log out?",
                        isPresented: $confirmLogout,
                        titleVisibility: .visible
                    ) {
                        Button("Log Out", role: .destructive) { auth.signOut() }
                        Button("Cancel", role: .cancel) { }
                    }
                }

                // Trailing: Friends hub quick access
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        path.append(Route.friendsHub)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.circle.fill")
                                .font(.title3)
                            Text("Friends")
                                .font(.subheadline).fontWeight(.semibold)
                                .lineLimit(1)
                        }
                        .foregroundColor(Color(hex: "#004C26"))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.92))
                                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            // Make the nav bar Baylor green with white content
            .toolbarBackground(Color(hex: "#2E5930"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(.white)

            .navigationDestination(for: Route.self) { route in
                switch route {
                case .findFriends:
                    FindFriendsView()
                case .rateProfessor:
                    RateProfessorView()
                case .professorList:
                    ProfessorListView()
                case .messages:
                    MessagesView()
                case .friendsHub:
                    FriendsHubView(vm: FriendViewModel())
                }
            }
        }
    }
}


struct CardButtonLabel: View {
    let icon: String
    let iconColor: Color
    let title: String
    let titleColor: Color
    let subtitle: String
    let subtitleColor: Color
    let backgroundIconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(backgroundIconColor)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(subtitleColor.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
        .contentShape(Rectangle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
    }
}
