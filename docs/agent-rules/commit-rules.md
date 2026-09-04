# Git Commit Rules

IMPORTANT: Only commit when the user explicitly says "commit". Never commit proactively.

## Commit Process

1. Stage all relevant changed files
2. Review the diff to understand what changed and WHY
3. Auto-generate the commit message — do not ask the user for a message
4. Execute the commit immediately

## Why This Format

AI scans git history via `git log --oneline`, which shows only subject lines. In large repos, this can consume 20k+ tokens. The subject line is often the ONLY thing read — it must be self-contained and keyword-rich. The body provides deeper context when AI investigates a specific commit.

## Subject Line Format

```
[Prefix] Specific action on specific target(s) (keyword1, keyword2, keyword3)
```

### Prefixes

| Prefix | When |
|--------|------|
| `[Feature]` | New functionality — screens, components, managers, models, integrations |
| `[Bug]` | Fixing broken behavior — crashes, incorrect logic, regressions |
| `[Clean]` | Everything else — refactoring, renaming, deleting, docs, config, rules, dependencies |

### Subject Line Rules

- **Imperative mood** — "Add", "Fix", "Remove", not "Added", "Fixed", "Removed"
- **Name specific entities** — screen names, component names, manager names, method names
- **50-75 characters** — information-dense, not terse. Pack keywords, cut filler
- **Self-contained** — must make sense without reading the body or diff
- **Keyword tag** — append parenthesized list of relevant method names, types, enums, or identifiers not already in the title
- **No agent attribution** — never include "Co-Authored-By" or references to an agent in the commit message

### Body (Required for Non-Trivial Changes)

AI can see WHAT changed from the diff. The body explains what the diff cannot:

- **Why** — what prompted this change? What problem does it solve?
- **What was affected** — which layers, screens, or managers were touched?
- **Decisions** — any alternatives considered or tradeoffs?

Skip the body only for trivial changes (typo fix, single config line, adding a rules file).

## Good Examples

```
[Feature] Add analytics tracking to HomePresenter and SettingsPresenter (trackHomeViewed, trackSettingsTapped, HomeInteractor, SettingsInteractor)

Added trackEvent calls for all user actions in Home and Settings.
Follows existing pattern from PaywallPresenter.
```

```
[Bug] Fix PaywallPresenter crash on nil product during purchase tap (onPurchasePressed, selectedProduct, guard)

onPurchasePressed force-unwrapped selectedProduct which could be nil
if products hadn't loaded. Added guard with LogManager error logging.
```

```
[Bug] Fix StreakManager listener not cancelling on logout (logOut, currentCollectionListenerTask, Task.cancel)

logOut() cleared streak count but not the active listener task,
causing stale data on next login. Added task cancellation.
```

```
[Clean] Refactor CoreInteractor login to async let (UserManager, PurchaseManager, ABTestManager, parallel)

Replaced sequential awaits with async let for faster login.
```

```
[Clean] Add swift-6 rules file
```

## Bad Examples

```
[Feature] Add new stuff              ← no specific targets
[Bug] Fix bug                        ← no searchable context
[Clean] Various improvements         ← zero information
[Clean] Update files                 ← which files? why?
Updated the home screen             ← missing prefix, past tense
```

## Rules

- Combine all staged changes into a single commit
- If changes span unrelated work, suggest splitting before committing
- Never commit `.env`, credentials, or secrets
