import RevenueCat
import RevenueCatUI
import SwiftUI

struct SimplePaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StoreService

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Simple GLP Pro")
                    .font(.largeTitle.weight(.bold))
                Text("Unlock proactive alerts and personalized pattern insights.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if store.isLoadingProducts {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if store.products.isEmpty {
                    Text("Products unavailable. Check your connection.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.products, id: \.storeProduct.productIdentifier) { package in
                        Button {
                            purchase(package)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(package.glpProDisplayName)
                                        .font(.headline)
                                    Text(package.glpProPriceLabel)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.purchaseInFlight {
                                    ProgressView()
                                } else {
                                    Image(systemName: "lock.open.fill")
                                        .foregroundStyle(AppTheme.brand)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(store.purchaseInFlight)
                        .buttonStyle(.plain)
                    }
                }

                if let error = store.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button("Restore purchases") {
                    Task { await store.restorePurchases() }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(24)
            .background(AppTheme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func purchase(_ package: Package) {
        Task {
            do {
                let state = try await store.purchase(package)
                if state == .purchased {
                    dismiss()
                }
            } catch {
                store.lastError = "Purchase failed. Try again."
            }
        }
    }
}
