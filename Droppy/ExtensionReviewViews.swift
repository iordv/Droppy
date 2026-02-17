import SwiftUI

// MARK: - Extension Review Components
// Extracted from ExtensionInfoView.swift for faster incremental builds

struct ExtensionReviewsSheet: View {
    let extensionType: ExtensionType
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    @AppStorage(AppPreferenceKey.disableAnalytics) private var disableAnalytics = PreferenceDefault.disableAnalytics
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
                if !disableAnalytics && !reviews.isEmpty {
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
                    Image(systemName: "xmark")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 32))
            }
            .padding(DroppySpacing.xl)
            
            Divider()
            
            if disableAnalytics {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Analytics is disabled")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Reviews and ratings are hidden while \"Skip All Analytics\" is enabled.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
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
                        .padding(DroppySpacing.xl)
                    }
                }
            }
        }
        .frame(width: 450, height: 500)
        .background(useTransparentBackground ? AnyShapeStyle(.ultraThinMaterial) : AdaptiveColors.panelBackgroundOpaqueStyle)
        .onAppear {
            Task {
                guard !disableAnalytics else {
                    isLoading = false
                    reviews = []
                    return
                }
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
                                    withAnimation(DroppyAnimation.state) {
                                        selectedRating = star
                                        showFeedbackField = true
                                    }
                                }
                                .scaleEffect(hoveringRating == star ? 1.15 : 1.0)
                                .animation(DroppyAnimation.stateEmphasis, value: hoveringRating)
                        }
                    }
                    
                    // Optional feedback field
                    if showFeedbackField && selectedRating > 0 {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                TextField("Optional feedback…", text: $feedbackText, axis: .vertical)
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
                                        }
                                    }
                                }
                                .buttonStyle(DroppyAccentButtonStyle(color: extensionType.categoryColor, size: .small))
                                .disabled(isSubmittingRating)
                            }
                            .droppyTextInputChrome(
                                cornerRadius: DroppyRadius.ml,
                                horizontalPadding: 12,
                                verticalPadding: 10
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
        guard !disableAnalytics, selectedRating > 0, !isSubmittingRating else { return }
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
        .padding(DroppySpacing.lg)
        .background(AdaptiveColors.buttonBackgroundAuto)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }
}
