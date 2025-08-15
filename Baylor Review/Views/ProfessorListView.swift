import SwiftUI


struct ProfessorListView: View {
    @StateObject private var manager = ProfessorViewModel()
    @State private var searchText = ""

    // Reporting UI state
    @State private var reportTarget: ProfessorItem?
    @State private var showReportThanks = false
    @State private var reportError: String?

    // Group professors by name (from items, so we have doc IDs)
    private var groupedProfessors: [ProfessorSummary] {
        // Group by professor name
        let grouped = Dictionary(grouping: manager.items) { $0.professor.name }

        var summaries: [ProfessorSummary] = grouped.map { name, items in
            let ratings = items.map { $0.professor.rating }
            let avg = ratings.reduce(0, +) / Double(max(ratings.count, 1))
            let courses = Array(Set(items.map { $0.professor.course })).sorted()
            let sortedItems = items.sorted { $0.professor.dateCreated > $1.professor.dateCreated }

            return ProfessorSummary(
                name: name,
                averageRating: avg,
                totalReviews: items.count,
                courses: courses,
                items: sortedItems
            )
        }

        if !searchText.isEmpty {
            summaries = summaries.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.courses.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
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
                        )
                        .foregroundColor(Color(hex: "#004C26"))
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
                            ForEach(groupedProfessors) { summary in
                                NavigationLink {
                                    ProfessorDetailView(
                                        professorSummary: summary,
                                        onReport: { item in reportTarget = item }
                                    )
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

        // Ad
        .safeAreaInset(edge: .bottom) {
            BannerAdView(adUnitID: AdConfig.bannerUnitID)
                .frame(height: 50)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
        }

        // Report sheet + alerts
        .sheet(item: $reportTarget) { item in
            ReportReviewSheet(item: item) { reason, details in
                manager.reportReview(for: item, reason: reason, details: details) { result in
                    switch result {
                    case .success:
                        showReportThanks = true
                    case .failure(let err):
                        reportError = err.localizedDescription
                    }
                }
            }
        }
        .alert("Thanks for the report", isPresented: $showReportThanks) {
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
}

// MARK: - Detail view

struct ProfessorDetailView: View {
    let professorSummary: ProfessorSummary
    var onReport: (ProfessorItem) -> Void

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

                        ForEach(professorSummary.items) { item in
                            IndividualReviewCard(
                                item: item,
                                onReport: { onReport(item) }
                            )
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

// MARK: - Summary card

struct ProfessorSummaryCard: View {
    let summary: ProfessorSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#004C26"))
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

            if let latest = summary.items.first?.professor {
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

// MARK: - Individual review (with report actions)

struct IndividualReviewCard: View {
    let item: ProfessorItem
    var onReport: () -> Void

    private var review: Professor { item.professor }

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
        // Swipe to report
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onReport() } label: {
                Label("Report", systemImage: "flag")
            }
        }
        // Long press context menu
        .contextMenu {
            Button(role: .destructive) { onReport() } label: {
                Label("Report review", systemImage: "flag")
            }
        }
    }
}

// MARK: - Preview

struct ProfessorListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfessorListView()
        }
    }
}
