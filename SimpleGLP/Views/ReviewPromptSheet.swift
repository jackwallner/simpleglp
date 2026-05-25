import SwiftUI
import UIKit

@MainActor
final class ReviewPromptCoordinator: ObservableObject {
    static let shared = ReviewPromptCoordinator()

    enum Presentation {
        case enjoymentPrompt
        case feedbackOnly
    }

    @Published var pendingPresentation: Presentation?

    private init() {}

    func requestEnjoymentPrompt() {
        pendingPresentation = .enjoymentPrompt
    }

    func requestFeedback() {
        pendingPresentation = .feedbackOnly
    }

    func clear() {
        pendingPresentation = nil
    }
}

enum ReviewPromptDismissOutcome: Sendable {
    case notNow
    case feedbackSubmitted
    case openedWriteReview
    case enjoyedMaybeLater
}

struct ReviewPromptSheet: View {
    enum Step {
        case enjoyment
        case reviewPitch
        case feedback
    }

    let initialStep: Step
    let onFinish: (ReviewPromptDismissOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step
    @State private var feedbackText = ""
    @FocusState private var feedbackFocused: Bool

    init(initialStep: Step = .enjoyment, onFinish: @escaping (ReviewPromptDismissOutcome) -> Void) {
        self.initialStep = initialStep
        self.onFinish = onFinish
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .enjoyment:
                    enjoymentContent
                case .reviewPitch:
                    reviewPitchContent
                case .feedback:
                    feedbackContent
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") {
                        handleNotNow()
                    }
                }
            }
        }
        .presentationDetents(step == .feedback ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var navigationTitle: String {
        switch step {
        case .enjoyment: "Enjoying the app?"
        case .reviewPitch: "Support an indie dev"
        case .feedback: "Help us improve"
        }
    }

    private var enjoymentContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.brand)
                    .frame(width: 64, height: 64)
                Image(systemName: "heart.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 8)

            Text("If Simple GLP is making shot day easier, a quick rating on the App Store helps more people find a private tracker.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button {
                    step = .reviewPitch
                } label: {
                    primaryButtonLabel("Yes, I'm enjoying it")
                }
                .buttonStyle(.plain)

                Button {
                    step = .feedback
                } label: {
                    secondaryButtonLabel("Not really")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var reviewPitchContent: some View {
        VStack(spacing: 18) {
            Text("Simple GLP is built by one indie developer — no ads, no accounts, and your shot history stays on your device.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Text("An honest App Store review takes seconds and helps others find a fast, private GLP-1 shot log.")
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button {
                    ReviewPromptTracker.markOpenedWriteReview()
                    UIApplication.shared.open(AppStoreReviewLinks.writeReviewURL)
                    finish(.openedWriteReview)
                } label: {
                    primaryButtonLabel("Rate on the App Store")
                }
                .buttonStyle(.plain)

                Button {
                    ReviewPromptTracker.markShown()
                    finish(.enjoyedMaybeLater)
                } label: {
                    secondaryButtonLabel("Maybe later")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What would make Simple GLP work better for you?")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $feedbackText)
                .font(.body)
                .frame(minHeight: 140)
                .padding(10)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .focused($feedbackFocused)

            Text("Opens your mail app with a draft to the developer. No analytics — just your words.")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)

            Button {
                sendFeedback()
            } label: {
                primaryButtonLabel("Send feedback")
            }
            .buttonStyle(.plain)
            .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onAppear { feedbackFocused = true }
    }

    private func primaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.brand, in: Capsule())
    }

    private func secondaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    private func handleNotNow() {
        ReviewPromptTracker.markShown()
        finish(.notNow)
    }

    private func sendFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = Self.feedbackMailURL(body: trimmed) else { return }
        ReviewPromptTracker.markFeedbackSubmitted()
        UIApplication.shared.open(url)
        finish(.feedbackSubmitted)
    }

    private func finish(_ outcome: ReviewPromptDismissOutcome) {
        onFinish(outcome)
        dismiss()
    }

    static func feedbackMailURL(body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "jackwallner@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Simple GLP feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
