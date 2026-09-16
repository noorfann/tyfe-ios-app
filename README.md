# Tyfe — Focus, Reward, Repeat

Tyfe turns intended effort into deliberate downtime. Plan your day, complete fixed 25-minute Focus Sessions, earn Reward Credits, and spend them on bounded, guilt-free leisure — with a private social layer for gentle accountability.

```
Plan intended effort
        ↓
Complete a 25-minute Focus Session
        ↓
Earn 1 Reward Credit
        ↓
Claim intentional downtime
        ↓
Return to the next session, or finish the day
```

- **Platform:** iPhone-first iOS 18.0
- **Stack:** Swift 6, SwiftUI, Swift Concurrency
- **Status:** In active development

## App highlights

**Plan without becoming a task manager**
Create lightweight Activities and set a Daily Plan — the number of Focus Sessions you intend to complete today. Plans describe intention, not debt. Missed days are recorded, never punished.

**Focus in a fixed 25-minute session**
Every session runs for exactly 25 minutes against one Activity. The timer keeps running when the app is backgrounded or the phone is locked, and you get a single explicit pause of up to five minutes. There is no manual completion.

**Earn only by finishing**
A Focus Session awards exactly 1 Reward Credit, and only when the timer naturally completes. Abandoned sessions earn nothing, and duplicate completions can't inflate your balance. Credits are personal, non-monetary, non-transferable, never go negative, and reset to zero at the start of each local day.

**Spend credits on bounded downtime**
Redeem starter or custom Rewards from fixed duration tiers — 1 credit / 15 min, 2 credits / 30 min, 4 credits / 60 min. Only one Reward Claim can be active at a time, and its timer ends on schedule. Unused time doesn't silently extend or refund.

**Stay accountable in private Circles**
Create or join invite-only Circles to share limited progress and send preset Cheers. Members see today's planned and completed totals, completion percentage, and a coarse Focus Status — never Activity names, notes, credits, rewards, or full history. There are no feeds, rankings, chat, or missed-plan alerts.

**Works offline, first**
The complete core loop works locally with no account and no network. An account is only required for Circles; the social layer syncs a minimal, bounded snapshot and shows the last synced state when offline.

**Accessible by default**
A warm, game-board visual language with Dynamic Type, VoiceOver labels, Reduce Motion support, high-contrast states, and text — not color alone — conveying every status.

## Screenshots

| | |
|---|---|
| <img src="docs/screenshots/1.%20Create%20today%20activities.png" width="260" alt="Today screen with credits, sessions, and today's activities"> | <img src="docs/screenshots/2.%20Start%20focusing.png" width="260" alt="Focus Chamber showing a running 25-minute session"> |
| **Plan today's activities** | **Start focusing** |
| <img src="docs/screenshots/3.%20Earn%20credit.png" width="260" alt="Session complete screen earning 1 Reward Credit"> | <img src="docs/screenshots/4.%20Claim%20rewards.png" width="260" alt="Rewards screen with credit balance and fixed duration tiers"> |
| **Earn a Reward Credit** | **Claim a Reward** |
| <img src="docs/screenshots/5.%20Enjoy%20rewards.png" width="260" alt="Rewards screen showing a reward in progress with a countdown"> | <img src="docs/screenshots/6.%20Join%20Circles.png" width="260" alt="Circles screen with members, focus status, and Cheer actions"> |
| **Enjoy bounded downtime** | **Join a Circle** |

## Getting started

### Requirements

- macOS with **Xcode 16 or later** (developed with Xcode 26)
- An iPhone simulator running **iOS 18.0** or later
- No Supabase project, credentials, or network access needed for local development

### Run the app

1. Clone the repository:

   ```sh
   git clone git@github.com:noorfann/tyfe-ios-app.git
   cd tyfe-ios-app
   ```

2. Open the project in Xcode:

   ```sh
   open tyfe-ios-app.xcodeproj
   ```

3. Select the **`tyfe-ios-app - Mock`** scheme and any iPhone simulator, then run with **⌘R**.

The Mock scheme is self-contained: it uses deterministic local services and never initializes Supabase, Firebase, or other remote services. It is the intended configuration for local development, previews, and UI tests.

### Other build configurations

| Scheme | Purpose | Notes |
| --- | --- | --- |
| **`tyfe-ios-app - Mock`** | Local development, previews, UI tests | No network or credentials; start here |
| **`tyfe-ios-app - Development`** | Hosted Supabase development environment | Requires a local, untracked `tyfe-ios-app/Utilities/Keys.swift` |
| **`tyfe-ios-app - Production`** | Production release | Requires production credentials and explicit reviewed promotion |

Secrets never belong in source control. `Keys.swift` and `.env` files are gitignored — see `.gitignore`.

### Tests

The **`tyfe-ios-appUnitTests`** and **`tyfe-ios-appUITests`** targets run against the Mock configuration. Domain rules and Managers are covered with Swift Testing, and UI tests run deterministically without network access. Run them from Xcode with **⌘U**.

## Architecture

Tyfe follows a strict **VIPER + RIBs** flow:

```
View → Presenter → Interactor → Manager
```

- **Views** render state and call Presenter methods; they never touch Managers directly.
- **Presenters** are `@Observable @MainActor` and own screen state and user-action orchestration.
- **Interactors** expose Manager operations through protocol boundaries and own their RIB.
- **Managers** own data, persistence, integrations, and domain operations. Persistence and services live behind protocol-based services.
- **Components** are dumb UI: data in, closures out.

Focus completions and credit changes are recorded as idempotent local ledger entries rather than mutating an opaque balance, so duplicate awards can be prevented. The persisted absolute session start/end timestamp drives the timer; the ticking UI is derived and never the source of truth. The device is authoritative for private data, while Supabase owns only social identity, membership, and the minimal Shared Progress snapshot.

See [`AGENTS.md`](AGENTS.md) for the full project rules and [`docs/agent-rules/`](docs/agent-rules/) for architecture details.

## Project structure

```
tyfe-ios-app/
├── tyfe-ios-app/                 # App target
│   ├── Core/                     # VIPER screens (Onboarding, Today, Focus, Rewards, Circles, …)
│   ├── Managers/                 # Focus, Rewards, Social, LocalStore, Auth, … services
│   ├── Components/               # Dumb, reusable SwiftUI views and design system
│   ├── Root/                     # App entry, RIBs, dependency container
│   └── SupportingFiles/          # Assets, Info.plist, preview content
├── tyfe-ios-appUnitTests/        # Swift Testing coverage
├── tyfe-ios-appUITests/          # Deterministic UI tests (Mock)
├── supabase/                     # SQL migrations and Edge Functions
└── docs/                         # Screenshots, agent rules, and workflows
```

## Contributing

This project is built with an agent-assisted workflow:

- [`AGENTS.md`](AGENTS.md) — canonical project instructions for coding agents.
- [`docs/agent-rules/`](docs/agent-rules/) — architecture, Swift 6, SwiftUI, and commit rules.
- [`docs/workflows/`](docs/workflows/) — on-demand workflows for adding screens, Managers, components, models, tests, and more.

Inspect existing patterns before editing, keep changes scoped to the requested outcome, and run SwiftLint for modified Swift files.

## License and attribution

Released under the [MIT License](LICENSE.txt).

This project is built on the [SwiftfulStarterProject](https://github.com/SwiftfulThinking/SwiftfulStarterProject) architecture. Credit to Swiftful Thinking, LLC — see the [SwiftUI Advanced Architecture](https://www.swiftful-thinking.com/offers/REyNLwwH) course for the foundational patterns.
