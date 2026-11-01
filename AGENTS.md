# AGENTS.md

These rules apply to agents working in this repository unless the user explicitly overrides them.

## Product and language

- Toolbox is a native macOS utility app using SwiftUI, AppKit, and public system APIs.
- Use English for UI, messages, filenames, README, and project documentation. Communicate with Raycal in Simplified Chinese by default.
- Implement only selected work. Unselected ideas remain candidates in TODO.md.

## Before changes

1. Read this file completely, then README.md, TODO.md, DECISIONS.md, and CHANGELOG.md.
2. Inspect Git status, affected files, and actual behavior. Preserve unrelated uncommitted work.
3. Establish scope, dependencies, risk, and acceptance criteria. Ask when a missing choice materially changes the result.

## Work and documentation

- Track Candidate, Selected, In progress, Blocked, and Completed states in TODO.md. Mark complete after implementation and proportionate verification.
- Update README for capabilities/limitations, DECISIONS for lasting decisions, and CHANGELOG for implemented user-visible changes.
- Describe current facts. Do not equate plans, implementation, build success, UI acceptance, signing, notarization, or publication.
- Prefer minimal changes, preserve modules and compatibility, and avoid unsolicited refactors, stack replacements, dependencies, or feature removal.
- Validate relevant success/failure paths. Inspect realistic rendering for visual defects rather than relying only on a build.
- Delegate independent workflows when useful; the main agent integrates and verifies results.

## Privacy and system integration

- Prefer local processing; upload user data only when required and authorized.
- Keep Cloudflare tokens in Keychain, never source, logs, fixtures, or ordinary settings.
- Request permissions as needed and explain their use. Clipboard history needs explicit retention, exclusion, and deletion behavior.
- Password generation/checks stay offline and do not persist input.
- Use public APIs for Finder, power assertions, and background tasks; expose running state.
- Protect source media and prevent unintended output overwrites.

## Git and distribution

- Stage only authorized paths/hunks; review staged diff and relevant verification before committing.
- Commits do not imply push/publication authority. The first public GitHub repository and DMG release were authorized on 2026-11-01; external changes must remain in scope.
- Exclude secrets, private configuration, signing credentials, build products, and personal data from Git.
- Verify the exact distributed app/DMG; report build, signing, notarization, publication, and real-machine acceptance separately.
