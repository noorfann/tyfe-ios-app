---
name: creating-paywall
description: Scaffold a new paywall variant view in Core/Paywall/Paywalls/ and wire it into the AB test switch. Use when the user asks to add a new paywall, create a paywall variant, add a subscription screen, or build a purchase flow. Covers custom paywalls (most common), StoreKit native paywalls, and RevenueCat paywalls. Every new paywall must be behind an AB test flag.
---

# Creating Paywall

Add a new paywall variant view and wire it into the paywall AB test.

## Architecture

The paywall system has two layers:

1. **Paywall screen** (VIPER) — `Core/Paywall/` — already exists, handles products loading, purchase logic, analytics, routing
2. **Paywall variant views** — `Core/Paywall/Paywalls/` — pure UI components that receive data via closures

`PaywallView.swift` switches on the AB test to render the active variant. New paywalls are added as variant views, not new screens.

## Steps

1. Determine the variant name (PascalCase, e.g., `MinimalPaywall`, `FeatureListPaywall`)
2. Determine the variant type (custom, storeKit, or revenueCat)
3. Create the variant view file in `Core/Paywall/Paywalls/`
4. Add a case to `PaywallTestOption` enum
5. Wire the variant into `PaywallView.swift` switch statement
6. Add preview(s) for the new variant

## Variant Types

| Type | When | Products | UI Owner |
|------|------|----------|----------|
| **Custom** (most common) | Full control over layout and design | Loaded via presenter, passed as `[AnyProduct]` | You build it |
| **StoreKit** | Apple's native `SubscriptionStoreView` | Loaded by StoreKit from product IDs | Apple's UI |
| **RevenueCat** | RevenueCat's remote paywall UI | Managed by RevenueCat dashboard | RevenueCat SDK |

## Custom Paywall Template

Custom paywalls are the most common type. They receive products and closures from `PaywallView`:

```swift
import SwiftUI

struct {VariantName}PaywallView: View {

    var products: [AnyProduct] = []
    var onBackButtonPressed: () -> Void = { }
    var onRestorePurchasePressed: () -> Void = { }
    var onPurchaseProductPressed: (AnyProduct) -> Void = { _ in }

    var body: some View {
        ZStack {
            // Background
            Color.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header / marketing content
                // ...

                // Product list
                ForEach(products) { product in
                    // product.title, product.priceStringWithDuration, product.subtitle
                }

                // CTA button (if single product) or tap on product row

                // REQUIRED: Restore purchase link
                Text("Restore Purchase")
                    .underline()
                    .asButton {
                        onRestorePurchasePressed()
                    }

                // REQUIRED: Legal links
                HStack {
                    Link("Privacy Policy", destination: URL(string: Constants.privacyPolicyURL)!)
                    Text("|")
                    Link("Terms of Service", destination: URL(string: Constants.termsOfServiceURL)!)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .overlay(
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .padding(8)
                .tappableBackground()
                .asButton {
                    onBackButtonPressed()
                }
                .padding(16),
            alignment: .topLeading
        )
    }
}

#Preview {
    {VariantName}PaywallView(products: AnyProduct.mocks)
}
```

## Required UI Elements

Every custom paywall **must** include:

1. **Product display** — show product title, price, and duration via `AnyProduct` properties
2. **Purchase action** — call `onPurchaseProductPressed(product)` when user taps to buy
3. **Restore purchase** — visible link calling `onRestorePurchasePressed()`
4. **Privacy policy link** — link to `Constants.privacyPolicyURL`
5. **Terms of service link** — link to `Constants.termsOfServiceURL`
6. **Dismiss button** — close button calling `onBackButtonPressed()`

## Wiring Into PaywallView.swift

### Add AB test case

Add a new case to `PaywallTestOption` in `Managers/ABTests/Models/PaywallTestOption.swift`:

```swift
enum PaywallTestOption: String, Codable, CaseIterable {
    case storeKit, custom, {variantName}

    static var `default`: Self {
        .storeKit
    }
}
```

If `PaywallTestOption` doesn't exist yet, use the `creating-ab-test` skill to create the full AB test first (enum type, name: `paywallTest`), then add cases.

### Add switch case in PaywallView

In `PaywallView.swift`, add a case to the switch in `body`:

```swift
var body: some View {
    ZStack {
        switch presenter.paywallTest {
        case .custom:
            // existing custom paywall
        case .storeKit:
            // existing StoreKit paywall
        case .{variantName}:
            if presenter.products.isEmpty {
                ProgressView()
            } else {
                {VariantName}PaywallView(
                    products: presenter.products,
                    onBackButtonPressed: {
                        presenter.onBackButtonPressed()
                    },
                    onRestorePurchasePressed: {
                        presenter.onRestorePurchasePressed()
                    },
                    onPurchaseProductPressed: { product in
                        presenter.onPurchaseProductPressed(product: product)
                    }
                )
            }
        }
    }
    .task {
        await presenter.onLoadProducts()
    }
}
```

### Expose AB test in interactor

If not already done, add to `PaywallInteractor`:

```swift
@MainActor
protocol PaywallInteractor: GlobalInteractor {
    var paywallTest: PaywallTestOption { get }
    // ... existing methods
}
```

And expose in `PaywallPresenter`:

```swift
var paywallTest: PaywallTestOption {
    interactor.paywallTest
}
```

### Add preview per variant

In `PaywallView.swift`, add a preview that configures the MockABTestService with the new variant:

```swift
#Preview("{VariantName}") {
    let container = DevPreview.shared.container()
    container.register(ABTestManager.self, service: ABTestManager(service: MockABTestService(paywallTest: .{variantName})))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.paywallView(router: router)
    }
}
```

## StoreKit Paywall Variant

Uses Apple's `SubscriptionStoreView`. Simpler but less customizable:

```swift
import SwiftUI
import StoreKit

struct {VariantName}PaywallView: View {

    var productIds: [String] = EntitlementOption.allProductIds
    var onInAppPurchaseStart: ((Product) async -> Void)?
    var onInAppPurchaseCompletion: ((Product, Result<Product.PurchaseResult, any Error>) async -> Void)?

    var body: some View {
        SubscriptionStoreView(productIDs: productIds) {
            // Marketing content header
        }
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStoreControlStyle(.prominentPicker)
        .onInAppPurchaseStart(perform: onInAppPurchaseStart)
        .onInAppPurchaseCompletion(perform: onInAppPurchaseCompletion)
    }
}
```

StoreKit paywalls automatically include restore purchase. Wire using `presenter.onPurchaseStart` and `presenter.onPurchaseComplete` instead of `onPurchaseProductPressed`.

## RevenueCat Paywall Variant

Uses RevenueCat's remote paywall UI configured in the RevenueCat dashboard:

```swift
import SwiftUI
import RevenueCat
import RevenueCatUI

struct {VariantName}PaywallView: View {
    var body: some View {
        RevenueCatUI.PaywallView(displayCloseButton: true)
    }
}
```

RevenueCat paywalls handle products, purchasing, and restore internally. No closures needed.

## Key Patterns

- **Variant views are pure UI** — no interactor/router/presenter, just closures and data
- **PaywallView is the switch** — it selects which variant to render based on the AB test
- **Every variant needs an AB test case** — so paywalls can be tested against each other
- **Custom paywalls wrap products in ProgressView** — show loading state while `onLoadProducts` runs
- **Restore purchase is required** — App Store Review will reject without it
- **Privacy policy and terms of service are required** — for auto-renewable subscriptions
- **`AnyProduct` provides all display data** — `title`, `subtitle`, `priceString`, `priceStringWithDuration`
- **Presenter handles all purchase logic** — variant views only call closures, never import StoreKit or call interactor
- **Reference `CustomPaywallView.swift`** for the standard layout pattern
