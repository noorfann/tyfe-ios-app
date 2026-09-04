---
name: adding-deep-link
description: Add deep link or push notification handling logic to ModuleWrapperPresenter. Use when the user asks to handle a deep link, URL route, universal link, push notification action, or notification tap. Both deep links and push notifications are handled in ModuleWrapperPresenter.swift.
---

# Adding Deep Link / Push Notification Logic

Add routing logic to `ModuleWrapperPresenter.swift` for deep links (`.onOpenURL`) or push notifications (`.onNotificationReceived`).

## Where to Edit

`Core/ModuleWrapper/ModuleWrapperPresenter.swift` — both handlers live here:
- `handleDeepLink(url:delegate:)` — receives the URL
- `handlePushNotificationReceived(notification:delegate:)` — receives the notification

## NavigationStack Warning

ModuleWrapperView does NOT have a NavigationStack. This limits available navigation:

**Supported:**
- `router.showScreen(.fullScreenCover) { ... }`
- `router.showScreen(.sheet) { ... }`
- `router.showModal { ... }`
- `router.showAlert { ... }`
- Update interactor state
- Post a `NotificationCenter` notification

**NOT supported:**
- `router.showScreen(.push)` — will silently fail

**If you need .push navigation:** Post a custom `Notification.Name` from the presenter and listen for it with `.onNotificationReceived(name:)` in a child view that has a NavigationStack (e.g., HomeView).

## State-Aware Routing

Deep links and push notifications are sensitive to user state. Always check state before routing:

```swift
// Available on interactor (add to ModuleWrapperInteractor protocol as needed):
interactor.auth           // UserAuthInfo? — nil if not authenticated
interactor.currentUser    // UserModel? — nil if not loaded
interactor.isPremium      // Bool — entitlement status

// Available on delegate:
delegate.moduleId         // String — which module is active (Constants.tabbarModuleId or Constants.onboardingModuleId)
```

### Common Guards

```swift
// Only handle in tabbar module (skip if user is onboarding)
guard delegate.moduleId == Constants.tabbarModuleId else { return }

// Require authentication
guard interactor.auth != nil else { return }

// Require premium
guard interactor.isPremium else { return }
```

### Adding Interactor Properties

If `ModuleWrapperInteractor` doesn't expose what you need, add it to the protocol:

```swift
// In ModuleWrapperInteractor.swift:
@MainActor
protocol ModuleWrapperInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
}
```

CoreInteractor already has these properties — adding to the protocol just exposes them.

## Deep Link Pattern

Deep links arrive as URLs with query parameters. Parse the URL path or query items to determine the action:

```swift
func handleDeepLink(url: URL, delegate: ModuleWrapperDelegate) {
    interactor.trackEvent(event: Event.deepLinkStart)

    guard
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let queryItems = components.queryItems,
        !queryItems.isEmpty else {
        interactor.trackEvent(event: Event.deepLinkNoQueryItems)
        return
    }

    interactor.trackEvent(event: Event.deepLinkSuccess)

    // Example: myapp://open?screen=profile&id=123
    let screenParam = queryItems.first(where: { $0.name == "screen" })?.value

    guard delegate.moduleId == Constants.tabbarModuleId else { return }

    switch screenParam {
    case "profile":
        let id = queryItems.first(where: { $0.name == "id" })?.value
        router.showScreen(.fullScreenCover) { router in
            // builder.profileDetailView(router: router, userId: id)
        }
    default:
        break
    }
}
```

## Push Notification Pattern

Push notifications arrive as `Notification` with `userInfo` dictionary. Parse the payload to determine the action:

```swift
func handlePushNotificationReceived(notification: Notification, delegate: ModuleWrapperDelegate) {
    interactor.trackEvent(event: Event.pushNotifStart)

    guard
        let userInfo = notification.userInfo,
        !userInfo.isEmpty else {
        interactor.trackEvent(event: Event.pushNotifNoData)
        return
    }

    interactor.trackEvent(event: Event.pushNotifSuccess)

    // Example: { "type": "message", "chatId": "abc123" }
    let type = userInfo["type"] as? String

    guard delegate.moduleId == Constants.tabbarModuleId else { return }
    guard interactor.auth != nil else { return }

    switch type {
    case "message":
        let chatId = userInfo["chatId"] as? String
        router.showScreen(.fullScreenCover) { router in
            // builder.chatView(router: router, chatId: chatId)
        }
    default:
        break
    }
}
```

## Push-to-Navigate Workaround

If you need `.push` navigation from a deep link or push notification:

1. Define a custom `Notification.Name` in `Utilities/NotificationCenter.swift`:

```swift
static let deepLinkNavigation = Notification.Name("DeepLinkNavigation")
```

2. Post from `ModuleWrapperPresenter`:

```swift
NotificationCenter.default.post(name: .deepLinkNavigation, object: nil, userInfo: ["screen": "profile", "id": "123"])
```

3. Listen in a child view that has a NavigationStack (e.g., HomeView):

```swift
.onNotificationReceived(name: .deepLinkNavigation) { notification in
    presenter.handleDeepLinkNavigation(notification: notification)
}
```

4. Handle in that screen's presenter with `router.showScreen(.push)`.

## Key Patterns

- **One file to edit** — all logic goes in `ModuleWrapperPresenter.swift`
- **Always check state first** — use `delegate.moduleId`, `interactor.auth`, `interactor.isPremium` before routing
- **Add interactor properties as needed** — expose what you need from CoreInteractor via the protocol
- **No .push** — use `.fullScreenCover`, `.sheet`, or the notification workaround
- **Track events** — deep link and push notification events are already wired for analytics
