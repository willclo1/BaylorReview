import SwiftUI


struct ProfessorListView: View {
    @StateObject private var manager = ProfessorViewModel()
    @State private var searchText = ""

    // Group professors by name and build summaries
    private var groupedProfessors: [ProfessorSummary] {
        let grouped = Dictionary(grouping: manager.professors) { $0.name }
        var summaries = grouped.map { name, reviews in
            let avg = reviews.reduce(0) { $0 + $1.rating } / Double(reviews.count)
            let courses = Array(Set(reviews.map(\.course))).sorted()
            return ProfessorSummary(
                name: name,
                averageRating: avg,
                totalReviews: reviews.count,
                courses: courses,
                reviews: reviews.sorted(by: { $0.dateCreated > $1.dateCreated })
            )
        }
        if !searchText.isEmpty {
            summaries = summaries.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.courses.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        return summaries.sorted(by: { $0.name < $1.name })
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FFF5E1"), Color(hex: "#F5F0DC")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search header
                VStack(spacing: 16) {
                    Text("Browse Professors")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "#004C26"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(hex: "#004C26"))

                        TextField(
                            "",
                            text: $searchText,
                            prompt: Text("Search by professor or course")
                                .foregroundColor(Color(hex: "#004C26"))
                        ).foregroundColor(Color(hex: "#004C26"))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // Content
                if manager.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color(hex: "#F5B800"))
                    Spacer()
                } else if groupedProfessors.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 50))
                            .foregroundColor(Color(hex: "#F5B800"))

                        Text(searchText.isEmpty
                             ? "No professors found"
                             : "No results for '\(searchText)'")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "#004C26"))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(groupedProfessors, id: \.name) { summary in
                                NavigationLink {
                                    ProfessorDetailView(professorSummary: summary)
                                } label: {
                                    ProfessorSummaryCard(summary: summary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .onAppear { manager.fetchProfessors() }
    }
}



struct ProfessorDetailView: View {
    let professorSummary: ProfessorSummary

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FFF5E1"), Color(hex: "#F5F0DC")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Summary Card
                    VStack(spacing: 16) {
                        Text(professorSummary.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "#004C26"))

                        Text("Courses: \(professorSummary.courses.joined(separator: ", "))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#F5B800"))
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            VStack {
                                Text(String(format: "%.1f", professorSummary.averageRating))
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color(hex: "#004C26"))
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName:
                                            star <= Int(professorSummary.averageRating.rounded())
                                            ? "star.fill" : "star")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "#F5B800"))
                                    }
                                }
                                Text("Average Rating")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "#004C26"))
                            }

                            Divider()
                                .frame(height: 60)

                            VStack {
                                Text("\(professorSummary.totalReviews)")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color(hex: "#F5B800"))
                                Text("Total Reviews")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "#004C26"))
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                    )

                    // All reviews
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Reviews")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "#004C26"))
                            .padding(.horizontal, 4)

                        ForEach(professorSummary.reviews) { review in
                            IndividualReviewCard(review: review)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(professorSummary.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}


struct ProfessorSummaryCard: View {
    let summary: ProfessorSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#004C26"))
                    Text(summary.courses.joined(separator: ", "))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#F5B800"))
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#F5B800"))
                        Text(String(format: "%.1f", summary.averageRating))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "#004C26"))
                    }
                    Text("\(summary.totalReviews) review\(summary.totalReviews == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#004C26"))
                }
            }

            if let latest = summary.reviews.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Latest Review:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#004C26"))
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(latest.rating) ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "#F5B800"))
                            }
                        }
                    }
                    Text(latest.review)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#004C26"))
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
    }
}

struct IndividualReviewCard: View {
    let review: Professor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(review.course)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5B800"))
                Spacer()
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(review.rating) ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#F5B800"))
                    }
                    Text("\(Int(review.rating))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#004C26"))
                }
            }
            Text(review.review)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#004C26"))
            HStack {
                Spacer()
                Text(review.dateCreated.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#004C26"))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
}


struct ProfessorListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfessorListView()
        }
    }
}
