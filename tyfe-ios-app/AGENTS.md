# iOS app execution guidance

Apply the repository-wide instructions in [`../AGENTS.md`](../AGENTS.md) for work under this directory.

## Verification policy

Builds, test runs, simulator launches, and other potentially long-running verification commands are opt-in. Run them only when the user explicitly requests build or test verification, or when the user provides a specific command to execute.

When verification is not requested, perform read-only inspection and static checks only, and report that runtime verification was intentionally skipped.
