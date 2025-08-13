import SwiftUI

struct RateProfessorView: View {
    @StateObject private var manager = ProfessorViewModel()
    @State private var showingAddReview = false

    // Report UI state
    @State private var reportTarget: ProfessorItem?
    @State private var showReportThanks = false
    @State private var reportError: String?

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
                            .accessibilityLabel("Add review")
                        }

                        Text("Most Recent Reviews")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(Color(hex: "#004C26"))
                    }
                    .padding(.horizontal)

                    // MARK: Content
                    Group {
                        if manager.isLoading {
                            VStack {
                                Spacer()
                                ProgressView()
                                    .tint(Color(hex: "#F5B800"))
                                Spacer()
                            }
                        } else if manager.items.isEmpty {
                            VStack {
                                Spacer()
                                Text("No reviews yet. Be the first!")
                                    .foregroundColor(Color(hex: "#004C26"))
                                Spacer()
                            }
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(manager.items) { item in
                                        ProfessorRow(
                                            item: item,
                                            onReport: { reportTarget = item }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top)
            }
            .navigationBarHidden(true)
            .onAppear { manager.fetchProfessors() }
            .sheet(isPresented: $showingAddReview) {
                AddReviewView(manager: manager)
            }
            .sheet(item: $reportTarget) { item in
                ReportReviewSheet(
                    item: item
                ) { reason, details in
                    manager.reportReview(
                        for: item,
                        reason: reason,
                        details: details
                    ) { result in
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
}

// MARK: - Row

struct ProfessorRow: View {
    let item: ProfessorItem
    var onReport: () -> Void

    var body: some View {
        let professor = item.professor

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
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
                    Text("\(Int(professor.rating))")
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color(hex: "#F5B800"))
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
        // Quick action: swipe to report
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onReport()
            } label: {
                Label("Report", systemImage: "flag")
            }
        }
        // Long-press context menu
        .contextMenu {
            Button(role: .destructive) {
                onReport()
            } label: {
                Label("Report review", systemImage: "flag")
            }
        }
    }
}

// MARK: - Report Sheet

enum ReportReason: String, CaseIterable, Identifiable {
    case harassmentOrHate = "Harassment or hate"
    case profanityOrInappropriate = "Profanity / inappropriate"
    case misleadingOrSpam = "Misleading / spam"
    case privateInfo = "Private info / doxxing"
    case other = "Other"

    var id: String { rawValue }
}

struct ReportReviewSheet: View {
    let item: ProfessorItem
    var onSubmit: (_ reason: ReportReason, _ details: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason = .profanityOrInappropriate
    @State private var details: String = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Header / summary of what is being reported
                VStack(alignment: .leading, spacing: 6) {
                    Text("Report review")
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "#004C26"))
                    Text("\(item.professor.name) • \(item.professor.course)")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#004C26").opacity(0.7))
                    Text("“\(item.professor.review)”")
                        .font(.callout)
                        .foregroundColor(Color(hex: "#004C26"))
                        .lineLimit(3)
                }

                // Reason picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(hex: "#004C26"))
                    Picker("Reason", selection: $reason) {
                        ForEach(ReportReason.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Extra details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details (optional)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(hex: "#004C26"))
                    
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                        .padding(8)
                        .scrollContentBackground(.hidden)  
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
                        onSubmit(reason, details.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank)
                        dismiss()
                    } label: {
                        Text("Report")
                            .bold()
                    }
                }
            }
        }
    }
}

// MARK: - Small helpers

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
