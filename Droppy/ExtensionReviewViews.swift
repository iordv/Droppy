import SwiftUI

// MARK: - Extension Review Components
// Extracted from ExtensionInfoView.swift for faster incremental builds

struct ExtensionReviewsSheet: View {
    let extensionType: ExtensionType
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @Environment(\.dismiss) private var dismiss
    @State private var reviews: [ExtensionReview] = []
    @State private var isLoading = true
    @State private var averageRating: Double = 0
    
    // Rating state
    @State private var selectedRating: Int = 0
    @State private var hoveringRating: Int = 0
    @State private var feedbackText: String = ""
    @State private var hasSubmittedRating = false
    @State private var isSubmittingRating = false
    @State private var showFeedbackField = false
    @State private var isHoveringSubmit = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reviews")
                        .font(.title2.bold())
                    Text(extensionType.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Average rating
                if !reviews.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", averageRating))
                            .font(.title3.weight(.semibold))
                        Text("(\(reviews.count))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
            
            // Rating submission section
            ratingSubmitSection
            
            Divider()
            
            // Reviews list
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if reviews.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "star.bubble")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No reviews yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Be the first to rate this extension!")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(reviews) { review in
                            ReviewCard(review: review)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 450, height: 500)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black))
        .onAppear {
            Task {
                await loadReviews()
            }
        }
    }
    
    @ViewBuilder
    private var ratingSubmitSection: some View {
        VStack(spacing: 12) {
            if hasSubmittedRating {
                // Thank you message
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Thanks for your feedback!")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    Text("Rate this extension")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    // Star picker
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= (hoveringRating > 0 ? hoveringRating : selectedRating) ? "star.fill" : "star")
                                .font(.system(size: 24))
                                .foregroundStyle(star <= (hoveringRating > 0 ? hoveringRating : selectedRating) ? .yellow : .gray.opacity(0.4))
                                .onHover { hovering in
                                    hoveringRating = hovering ? star : 0
                                }
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedRating = star
                                        showFeedbackField = true
                                    }
                                }
                                .scaleEffect(hoveringRating == star ? 1.15 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: hoveringRating)
                        }
                    }
                    
                    // Optional feedback field
                    if showFeedbackField && selectedRating > 0 {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                TextField("Optional feedback...", text: $feedbackText, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.callout)
                                    .lineLimit(2...4)
                                
                                // Submit button inside the text field
                                Button {
                                    submitRating()
                                } label: {
                                    HStack(spacing: 4) {
                                        if isSubmittingRating {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Text("Submit")
                                                .font(.callout.weight(.semibold))
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(extensionType.categoryColor.opacity(isHoveringSubmit ? 1.0 : 0.85))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(AdaptiveColors.subtleBorderAuto, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isSubmittingRating)
                                .onHover { h in
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                        isHoveringSubmit = h
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.black.opacity(0.3))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        extensionType.categoryColor.opacity(0.6),
                                        style: StrokeStyle(
                                            lineWidth: 1.5,
                                            lineCap: .round,
                                            dash: [3, 3],
                                            dashPhase: 0
                                        )
                                    )
                            )
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func loadReviews() async {
        do {
            reviews = try await AnalyticsService.shared.fetchExtensionReviews(extensionId: extensionType.rawValue)
            if !reviews.isEmpty {
                averageRating = Double(reviews.map { $0.rating }.reduce(0, +)) / Double(reviews.count)
            }
            isLoading = false
        } catch {
            isLoading = false
        }
    }
    
    private func submitRating() {
        guard selectedRating > 0, !isSubmittingRating else { return }
        isSubmittingRating = true
        
        Task {
            try? await AnalyticsService.shared.submitExtensionRating(
                extensionId: extensionType.rawValue,
                rating: selectedRating,
                feedback: feedbackText.isEmpty ? nil : feedbackText
            )
            
            await MainActor.run {
                withAnimation {
                    hasSubmittedRating = true
                    isSubmittingRating = false
                }
                
                // Reload reviews to show new one
                Task {
                    await loadReviews()
                }
            }
        }
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let review: ExtensionReview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Stars
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundStyle(star <= review.rating ? .yellow : .gray.opacity(0.3))
                    }
                }
                
                Spacer()
                
                // Date
                Text(review.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            if let feedback = review.feedback, !feedback.isEmpty {
                Text(feedback)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
