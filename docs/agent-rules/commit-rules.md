# Git Commit Rules

IMPORTANT: Only commit when the user explicitly says "commit". Never commit proactively.

## Commit Process

1. Stage all relevant changed files
2. Review the diff to understand what changed and WHY
3. Auto-generate the commit message — do not ask the user for a message
4. Execute the commit immediately

## Why This Format

AI scans git history via `git log --oneline`, which shows only subject lines. In large repos, this can consume 20k+ tokens. The subject line is often the ONLY thing read — it must be self-contained and keyword-rich. The body provides deeper context when AI investigates a specific commit.

This project follows [Conventional Commits](https://www.conventionalcommits.org/) and GitHub's commit-message guidance, so history stays machine-parseable and tooling (changelogs, semantic versioning) can consume it.

## Message Structure

```
<type>(<scope>): <subject>

<body>

<footer>
```

- **One blank line** between subject and body, and between body and footer.
- Subject line is mandatory. Body and footer are optional but required for non-trivial changes.
- One logical change per commit. Do not mix unrelated work.

## Subject Line

```
<type>(<scope>): <subject>
```

### Types

| Type | When |
|------|------|
| `feat` | New functionality — screens, components, managers, models, integrations |
| `fix` | Fixing broken behavior — crashes, incorrect logic, regressions |
| `refactor` | Restructuring without changing behavior |
| `perf` | Performance improvements |
| `docs` | Documentation, rules, comments |
| `test` | Adding or fixing tests |
| `build` | Build system, dependencies, Xcode project, scripts |
| `ci` | CI configuration and scripts |
| `chore` | Everything else — renaming, deleting, config, housekeeping |
| `revert` | Reverting a previous commit |

### Scope

Optional. Name the concrete area touched, in lowercase: a screen, RIB, manager, or module (e.g. `paywall`, `streak-manager`, `root-dependencies`, `core`). Omit the parentheses when no single scope fits.

### Subject Rules

- **Imperative mood** — "Add", "Fix", "Remove", not "Added", "Fixed", "Removed"
- **Capitalize** the first word; **no trailing period**
- **≤ 50 characters** where practical, hard limit 72
- **Name specific entities** — screen names, component names, manager names, method names
- **Self-contained** — must make sense without reading the body or diff
- **Keyword-rich** — pack searchable identifiers; cut filler words
- **No agent attribution** — never include "Co-Authored-By" or references to an agent

### Body

AI can see WHAT changed from the diff. The body explains what the diff cannot:

- **Why** — what prompted this change? What problem does it solve?
- **What was affected** — which layers, screens, or managers were touched?
- **Decisions** — any alternatives considered or tradeoffs?

Wrap the body at 72 characters. Use the imperative mood for the summary line and use prose or bullets freely below it.

Skip the body only for trivial changes (typo fix, single config line, adding a rules file).

### Footer

Use the footer for metadata:

- **Breaking changes** — start with `BREAKING CHANGE:` and describe the impact and migration.
- **Issue references** — link GitHub issues so they auto-close and cross-reference: `Closes #123`, `Fixes #123`, `Refs #123`.

## Good Examples

```
feat(home): add analytics tracking to HomePresenter

Added trackEvent calls for all user actions in Home and Settings.
Follows existing pattern from PaywallPresenter.

Closes #142
```

```
fix(paywall): guard nil product on purchase tap

onPurchasePressed force-unwrapped selectedProduct which could be nil
if products hadn't loaded. Added guard with LogManager error logging.

Fixes #187
```

```
fix(streak): cancel listener task on logout

logOut() cleared streak count but not the active listener task,
causing stale data on next login. Added task cancellation.
```

```
refactor(core): parallelize login with async let

Replaced sequential awaits with async let for faster login across
UserManager, PurchaseManager, and ABTestManager.
```

```
docs(rules): add swift-6 rules file
```

```
feat(api)!: rename Reward Credit accessor

BREAKING CHANGE: rewardCreditBalance() is now rewardCredits();
update all call sites in RewardManager and consumers.
```

## Bad Examples

```
feat: add new stuff                  ← no scope, no specific targets
fix: fix bug                         ← no searchable context
chore: various improvements          ← zero information
chore: update files                  ← which files? why?
Updated the home screen              ← missing type, past tense, capitalized
feat(Home): Add analytics.           ← scope must be lowercase, no period
```

## Rules

- Combine all staged changes into a single commit
- If changes span unrelated work, suggest splitting before committing
- Keep type and scope lowercase; keep the subject imperative and capitalized
- Separate subject, body, and footer with blank lines
- Reference issues in the footer when one exists
- Never commit `.env`, credentials, or secrets
