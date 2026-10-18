# Project instructions

Last updated: 2026-10-18 08:20:05 HKT (UTC+08:00)

## Scope and working constraints

- Keep this project focused on Hong Kong weather and HKO data unless the user changes the scope.
- Do not create files outside this project folder. Keep task output, compiler caches, temporary files, test bundles, and test persistence fixtures inside the repository, preferably under `.build/validation/`.
- Preserve unrelated working-tree changes, including existing modified and untracked feature files.
- Fetch fresh weather API data on load/refresh. Do not introduce weather response caching, a persisted weather store, or an offline cache without a new user instruction. SwiftData favorites and UserDefaults preferences are intentional persistence.

## Documentation maintenance

- Every human-readable project document created or edited must have a `Last updated` line near the top, including this file.
- Use the actual current date and time in `Asia/Hong_Kong`, formatted as `YYYY-MM-DD HH:mm:ss HKT (UTC+08:00)`. Refresh that document's timestamp whenever changing its content; do not reuse an earlier task's timestamp.
- Update [docs/STATUS.md](docs/STATUS.md) when completed work, open issues, validation results, or agreed next steps change. Keep [docs/HANDOVER.md](docs/HANDOVER.md) aligned with architecture/behavior changes and [README.md](README.md) aligned with setup and feature changes.
- Distinguish implemented features from proposals, and measured results from unverified behavior. Record the actual validation date separately from the document update time. Do not imply tests were rerun during a documentation-only task.

## Continuation and validation

- Read [docs/STATUS.md](docs/STATUS.md) and [docs/HANDOVER.md](docs/HANDOVER.md) before continuing implementation. Status issue IDs describe known work; their presence does not mean the issue has been fixed.
- Use `project.yml` as the source of truth for targets, source/resource inclusion, settings, and the shared scheme. Regenerate the checked-in project with `bash scripts/generate-project.sh` after configuration changes or adding/removing source files; do not make durable changes only to the generated `.xcodeproj`.
- The generation wrapper keeps XcodeGen's TMPDIR and cache inside `.build/validation/xcodegen/`. Preserve explicit localization resources in the unit-test target because its tests resolve strings from their own bundle.
- The project-contained validator is `bash scripts/validate-hko.sh`. It runs standalone macOS tests and iOS source typechecks; it does not establish a successful full Xcode build or iOS UI test run.
- Keep meaningful validation evidence and limitations in STATUS.md. Local `.build/` logs are ignored and may be unavailable in another checkout.
