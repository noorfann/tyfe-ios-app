# Tyfe project instructions

This is the canonical project guidance for Codex and other coding agents working in this repository. User instructions and safety constraints take priority over this file; when guidance conflicts, follow the higher-priority instruction and call out the conflict briefly.

## Caveman workflow

- Caveman mode is the default response style for this project at full intensity, while preserving exact technical meaning. Return to normal prose when the user asks for it.
- Before each task, check available Caveman skills and invoke every task-specific Caveman skill whose trigger matches. Use `caveman-explore` for cold-start or broad repository localization, `caveman-review` for code reviews, and `caveman-commit` for commit-message requests. Use other Caveman skills only when their stated trigger applies.
- Keep persisted project documentation, code comments, commit bodies, and messages intended for other humans in normal prose unless the user explicitly requests Caveman formatting.

## Working agreement

- Inspect the relevant files, tests, and existing patterns before editing.
- Keep each change scoped to the requested outcome. Reuse existing seams before adding abstractions, dependencies, services, or configuration.
- Continue through implementation and focused verification when the request is clear. Ask only when a missing choice would materially change the result or an external action is required.
- Preserve existing user changes. Review `git status` before editing and keep unrelated changes out of the task.
- Keep the project runnable after every coherent slice.
- Use `apply_patch` for source and documentation edits. When runtime tooling is explicitly requested, use the repository's existing scripts and Xcode tooling for generation, builds, tests, and diagnostics.
- Treat commits, pushes, remote changes, history rewrites, dependency upgrades, and destructive filesystem operations as explicit user actions. The project commit rule requires the user to say `commit` before committing.
- Do not run builds, unit tests, UI tests, simulator launches, application launches, or other runtime verification unless the user explicitly requests it.
- Invoke XcodeBuildMCP only when the user explicitly requests XcodeBuildMCP by name. A general implementation or verification request does not authorize using it.
- Adding or editing test source does not authorize executing tests.
- When verification is not requested, use read-only/static checks and non-rewriting SwiftLint only; state clearly in the handoff that runtime verification was skipped by policy.
- Before reporting completion, run only the permitted static command that proves the claim, read its exit status and failures, and report blockers plainly.

## Project facts

- Platform: iOS 18.0.
- Language: Swift 6 with async/await.
- UI: SwiftUI with `@Observable` state.
- Architecture: VIPER + RIBs with the flow `View → Presenter → Interactor → Manager`.
- Persistence and services belong behind Managers and protocol-based services.
- Build configurations: `Mock`, `Development`, and `Production`.

Use `Mock` for local development, previews, and UI tests. Mock code must not initialize Firebase, Supabase, or other remote services. Development and Production currently use local fallback services pending Supabase integration. Keep secrets out of the repository and client source.

## Architecture rules

- Views render state and call Presenter methods. They do not access Interactors or Managers directly.
- Presenters are `@Observable @MainActor` and own screen state and user-action orchestration.
- Interactor protocols extend `GlobalInteractor`; the owning RIB implements them on its concrete Interactor.
- Router protocols extend `GlobalRouter`; Routers handle navigation only.
- Managers own data, persistence, integrations, and domain operations. Presenters reach them only through Interactors.
- Components are dumb UI: inject data and closures; keep business state in the screen Presenter or owning Manager.
- Register every new screen through the owning RIB's Router, Interactor, and Builder.
- Register every new Manager in `Root/Dependencies/Dependencies.swift` and resolve it through the owning RIB Interactor.

## Swift and SwiftUI conventions

- Prefer structured concurrency and value types. Keep actor isolation intentional and fix the underlying ownership problem instead of bypassing Swift 6 checks.
- Use `.asButton()` for interactive UI, `ImageLoaderView` for remote images, and `router.showAlert()` for alerts.
- Use Dynamic Type-friendly system fonts and stable `ForEach` identifiers.
- Keep Views declarative and side-effect free; put asynchronous work in Presenters or Managers.
- Track user-facing Presenter and Manager operations with the existing `LogManager` convention, excluding private Activity, reward, and social details from analytics.
- Do not introduce deprecated SwiftUI APIs, `print()`, `Task.detached`, `DispatchQueue`, or `@unchecked Sendable` without a documented, reviewed reason.

## Delivery workflow

1. Identify the acceptance criteria and explicit non-goals.
2. Trace the entry point through View, Presenter, Interactor, Manager, service, and persistence layers as applicable.
3. Implement the smallest complete vertical slice using existing project patterns.
4. Add or update focused Swift Testing, integration, UI, or device coverage appropriate to the risk.
5. When runtime verification is explicitly requested, run focused verification, then a broader build or test when the change crosses module or configuration boundaries. Otherwise, use the permitted static checks.
6. Summarize changed files, verification evidence, and any material omission or follow-up.

## On-demand project guidance

Read only the rule set needed for the task from [`docs/agent-rules/README.md`](docs/agent-rules/README.md). Use the project workflow reference in [`docs/workflows/README.md`](docs/workflows/README.md) when a task matches one of its scaffolding or refactoring workflows.

The files under [`docs/legacy/claude/`](docs/legacy/claude/) are archival material from the former agent setup. They are not instructions for current work and should not be edited unless the user explicitly asks for historical recovery.
