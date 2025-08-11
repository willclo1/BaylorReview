import SwiftUI

struct RateProfessorView: View {
    @StateObject private var manager = ProfessorViewModel()
    @State private var showingAddReview = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#FFF5E1"), Color(hex: "#F5F0DC")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // MARK: Header
                    VStack(alignment: .leading, spacing: 8) {
        
                        HStack {
                            Text("Rate Professors")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(hex: "#004C26"))
                            Spacer()
                            Button {
                                showingAddReview = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundColor(Color(hex: "#004C26"))
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color(hex: "#F5B800")))
                            }
                        }

                        // Subtitle
                        Text("Most Recent Reviews")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(Color(hex: "#004C26"))
                    }
                    .padding(.horizontal)

                    // MARK: Content
                    if manager.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Color(hex: "#F5B800"))
                        Spacer()
                    } else if manager.professors.isEmpty {
                        Spacer()
                        Text("No reviews yet. Be the first!")
                            .foregroundColor(Color(hex: "#004C26"))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(manager.professors) { professor in
                                    ProfessorRow(professor: professor)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    Spacer()
                }
                .padding(.top)
            }
            .navigationBarHidden(true)
            .onAppear { manager.fetchProfessors() }
            .sheet(isPresented: $showingAddReview) {
                AddReviewView(manager: manager)
            }
        }
    }
}

struct ProfessorRow: View {
    let professor: Professor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(professor.name)
                        .font(.headline)
                        .foregroundColor(Color(hex: "#004C26"))
                    Text(professor.course)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#F5B800"))
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color(hex: "#F5B800"))
                    Text("\(Int(professor.rating))")
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#004C26"))
                }
            }

            Text(professor.review)
                .font(.body)
                .foregroundColor(Color(hex: "#004C26"))
                .lineLimit(3)

            HStack {
                Spacer()
                Text(professor.dateCreated.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(Color(hex: "#F5B800"))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        )
    }
}
