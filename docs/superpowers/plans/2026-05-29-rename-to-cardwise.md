# Rename / Rebrand to CardWise — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the project from "SmartCard" to "CardWise" everywhere — source folders, XcodeGen project, targets/schemes, bundle IDs, in-code identifiers, docs, the GitHub repo, and the local repo-root folder.

**Architecture:** XcodeGen owns the project — `project.yml` is the source of truth and `SmartCard.xcodeproj` is generated. So the rename edits `project.yml` + renames the three source directories + fixes in-code symbols, then regenerates the project. GitHub repo rename via `gh`. The physical repo-root folder move is the final, isolated step (it changes absolute paths the tooling uses).

**Tech Stack:** Swift / SwiftUI, XcodeGen, Xcode 16, `gh` CLI, git.

**Ordering:** This plan runs **before** the UI redesign plan, so the redesign edits files at their final `CardWise/` paths.

**Naming map:**
| Old | New |
|---|---|
| `SmartCard` (project/app target) | `CardWise` |
| `SmartCardTests` | `CardWiseTests` |
| `SmartCardWidget` | `CardWiseWidget` |
| `SmartCard/` (source dir) | `CardWise/` |
| `SmartCardApp` (struct) | `CardWiseApp` |
| `SmartCardWidget` (struct/bundle) | `CardWiseWidget` |
| `com.smartcard` (bundleIdPrefix) | `com.cardwise` |
| `com.smartcard.app[.widget/.tests]` | `com.cardwise.app[.widget/.tests]` |
| `group.com.smartcard.app` | `group.com.cardwise.app` |
| `SmartCard.storekit` | `CardWise.storekit` |
| `SmartCard.entitlements` | `CardWise.entitlements` |
| `SmartCardWidget.entitlements` | `CardWiseWidget.entitlements` |
| Display name "SmartCard" | "CardWise" |
| `tmj-studio/SmartCard` (GitHub) | `tmj-studio/CardWise` |
| `~/Desktop/SmartCard` (folder) | `~/Desktop/CardWise` |

> **Pre-release assumption:** App is v1.0.0, not yet shipped. Changing bundle IDs and the app-group ID is therefore safe (no installed-base/widget-data migration needed). If the app HAS shipped, stop and revisit — bundle-ID change = new App Store record.

---

### Task 1: Branch for the rename

- [ ] **Step 1: Create a working branch**

Run:
```bash
cd /Users/rich/Desktop/SmartCard
git checkout -b chore/rename-to-cardwise
```
Expected: `Switched to a new branch 'chore/rename-to-cardwise'`

- [ ] **Step 2: Confirm clean baseline build state is known**

Run:
```bash
xcodegen generate && xcodebuild -project SmartCard.xcodeproj -scheme SmartCard -destination 'generic/platform=iOS Simulator' -quiet build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **` (establishes the pre-rename build works; if it fails for unrelated reasons, note it before proceeding).

---

### Task 2: Rename source directories

**Files:** directory renames only (content unchanged in this task).

- [ ] **Step 1: git mv the three source dirs**

Run:
```bash
git mv SmartCard CardWise
git mv SmartCardTests CardWiseTests
git mv SmartCardWidget CardWiseWidget
```
Expected: no output; `git status` shows renames.

- [ ] **Step 2: Rename brand-named files inside the dirs**

Run:
```bash
git mv CardWise/App/SmartCardApp.swift CardWise/App/CardWiseApp.swift
git mv CardWise/SmartCard.entitlements CardWise/CardWise.entitlements
git mv CardWiseWidget/SmartCardWidget.swift CardWiseWidget/CardWiseWidget.swift
git mv CardWiseWidget/SmartCardWidget.entitlements CardWiseWidget/CardWiseWidget.entitlements
git mv SmartCard.storekit CardWise.storekit
```
Expected: renames staged. (Verify each path first with `ls`; if a filename differs, adjust. `CardWiseWidget/` file list: run `ls CardWiseWidget`.)

- [ ] **Step 3: Commit the moves**

```bash
git add -A
git commit -m "chore: rename source directories SmartCard -> CardWise"
```

---

### Task 3: Update `project.yml`

**Files:** Modify `project.yml`

- [ ] **Step 1: Rewrite identifiers in project.yml**

Apply these exact replacements (every occurrence):
- `name: SmartCard` → `name: CardWise`
- `bundleIdPrefix: com.smartcard` → `bundleIdPrefix: com.cardwise`
- target key `SmartCard:` → `CardWise:`
- target key `SmartCardWidget:` → `CardWiseWidget:`
- target key `SmartCardTests:` → `CardWiseTests:`
- `path: SmartCard` → `path: CardWise`
- `path: SmartCardWidget` → `path: CardWiseWidget`
- `path: SmartCardTests` → `path: CardWiseTests`
- `com.smartcard.app` → `com.cardwise.app` (covers `.app`, `.app.widget`, `.app.tests`)
- `group.com.smartcard.app` → `group.com.cardwise.app`
- `INFOPLIST_KEY_CFBundleDisplayName: "SmartCard"` → `"CardWise"`
- Camera/Photo usage strings: `SmartCard uses…` / `SmartCard accesses…` → `CardWise uses…` / `CardWise accesses…`
- `SmartCard/Resources/...` resource paths → `CardWise/Resources/...`
- `SmartCard/GoogleService-Info.plist` → `CardWise/GoogleService-Info.plist`
- `path: SmartCard/SmartCard.entitlements` → `path: CardWise/CardWise.entitlements`
- `path: SmartCardWidget/SmartCardWidget.entitlements` → `path: CardWiseWidget/CardWiseWidget.entitlements`
- `- target: SmartCardWidget` (embed) → `- target: CardWiseWidget`
- `testTargets: - SmartCardTests` → `- CardWiseTests`
- `storeKitConfiguration: SmartCard.storekit` → `CardWise.storekit`

- [ ] **Step 2: Sanity-check no `SmartCard`/`smartcard` remains in project.yml**

Run: `grep -in "smartcard" project.yml`
Expected: no matches (empty output).

---

### Task 4: Update in-code identifiers and resource references

**Files:** `CardWise/App/CardWiseApp.swift`, `CardWiseWidget/CardWiseWidget.swift`, `CardWiseWidget/Info.plist`, and any source referencing the app group / old struct names.

- [ ] **Step 1: Find every remaining code/text reference**

Run:
```bash
grep -rin "SmartCard\|smartcard\|group.com.smartcard" CardWise CardWiseWidget CardWiseTests --include="*.swift" --include="*.plist"
```
Expected: a finite list. Common hits: `struct SmartCardApp` → `struct CardWiseApp`; `@main`; `SmartCardWidget` struct + `@main struct SmartCardWidgetBundle`; `WidgetDataManager` app-group string `group.com.smartcard.app`; `SubscriptionGate`/StoreKit product-id prefixes if any contain "smartcard".

- [ ] **Step 2: Replace symbol & string references**

For each hit, rename:
- `SmartCardApp` → `CardWiseApp` (struct + `@main`)
- `SmartCardWidget` struct/bundle names → `CardWiseWidget`
- App-group literal `"group.com.smartcard.app"` → `"group.com.cardwise.app"` (e.g. in `WidgetDataManager.swift`)
- Any user-facing "SmartCard" string in Swift → "CardWise"

> Keep `RecommendationEngine`, `SpendingCapTracker`, etc. untouched — only brand tokens change.

- [ ] **Step 3: Check StoreKit product IDs**

Run: `grep -in "smartcard" CardWise.storekit`
If product identifiers embed "smartcard", rename them AND update the matching literals in `SubscriptionManager`/`SubscriptionGate`. If they use a neutral prefix (e.g. `com.cardwise.pro`/already generic), leave them and note it. Expected: reconcile so storekit IDs == code IDs.

- [ ] **Step 4: Verify no stray references**

Run: `grep -rin "smartcard" CardWise CardWiseWidget CardWiseTests CardWise.storekit`
Expected: empty (or only deliberately-kept matches you've justified in the commit message).

---

### Task 5: Regenerate the Xcode project & build

**Files:** delete `SmartCard.xcodeproj`, generate `CardWise.xcodeproj`.

- [ ] **Step 1: Remove the old generated project**

Run: `rm -rf SmartCard.xcodeproj`

- [ ] **Step 2: Generate the new project**

Run: `xcodegen generate`
Expected: `Created project at /Users/rich/Desktop/SmartCard/CardWise.xcodeproj`

- [ ] **Step 3: Build the renamed project**

Run:
```bash
xcodebuild -project CardWise.xcodeproj -scheme CardWise -destination 'generic/platform=iOS Simulator' -quiet build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -8
```
Expected: `** BUILD SUCCEEDED **`. If it fails, read the error, fix the offending reference, re-run. Do not proceed until green.

- [ ] **Step 4: Run tests**

Run:
```bash
xcodebuild -project CardWise.xcodeproj -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16' test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15
```
Expected: `TEST SUCCEEDED` (logic untouched, existing tests should pass).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: regenerate Xcode project as CardWise, update bundle ids and app group"
```

---

### Task 6: Update docs, metadata, and config text

**Files:** `CLAUDE.md`, `AGENTS.md`, `README.md`, `docs/README_EN.md`, `docs/README_ZH-TW.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `AppStore/AppStoreMetadata.md`, `AppStore/SubmissionChecklist.md`, `docs/GITHUB_ACTIONS_SETUP.md`, `.github/**`, `Functions/scraper/package.json`, `Functions/firebase/package.json`, `Scripts/take_screenshots*.sh`, prior spec/plan docs.

- [ ] **Step 1: List all remaining references repo-wide**

Run: `grep -rIl "SmartCard" . --exclude-dir=.git`
Expected: the doc/config files above.

- [ ] **Step 2: Replace brand references in docs/config**

Replace user-facing "SmartCard" → "CardWise" and any `SmartCard.xcodeproj` / `-scheme SmartCard` build commands → `CardWise.xcodeproj` / `-scheme CardWise`. In `package.json` files update `name`/description fields. Update `.github/` workflow scheme/project names. **Leave historical changelog entries that describe past "SmartCard" releases factually intact if rewriting them would be inaccurate — prefer adding a rename note.**

- [ ] **Step 3: Update CLAUDE.md & AGENTS.md project-overview headers and any `SmartCard/` tree diagrams to `CardWise/`.**

- [ ] **Step 4: Verify CI scheme references resolve**

Run: `grep -rin "scheme SmartCard\|SmartCard.xcodeproj" . --exclude-dir=.git`
Expected: empty.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs: update project name to CardWise across docs, CI, and metadata"
```

---

### Task 7: Rename the GitHub repository

> Requires admin on `tmj-studio/SmartCard`. The authed `gh` account is `Rich627`. If the command 403s, hand this step to the user (Settings → rename repo) and continue.

- [ ] **Step 1: Rename via gh**

Run:
```bash
gh repo rename CardWise --repo tmj-studio/SmartCard
```
Expected: `✓ Renamed repository tmj-studio/CardWise`. GitHub auto-redirects the old URL, but update the remote anyway.

- [ ] **Step 2: Update local remote URL**

Run (match existing protocol — repo uses ssh per `gh auth`):
```bash
git remote set-url origin git@github.com:tmj-studio/CardWise.git
git remote -v
```
Expected: origin points at `tmj-studio/CardWise`.

- [ ] **Step 3: Push the branch**

Run: `git push -u origin chore/rename-to-cardwise`
Expected: branch pushed; PR link printed.

---

### Task 8: Rename the local repo-root folder (final, isolated)

> This changes the absolute path the tools/cwd use. Do it last. After this, all paths are `/Users/rich/Desktop/CardWise/...`.

- [ ] **Step 1: Move the folder**

Run:
```bash
cd /Users/rich/Desktop && mv SmartCard CardWise && cd CardWise && pwd
```
Expected: `/Users/rich/Desktop/CardWise`

- [ ] **Step 2: Confirm git + build still work from the new path**

Run:
```bash
git status && xcodebuild -project CardWise.xcodeproj -scheme CardWise -destination 'generic/platform=iOS Simulator' -quiet build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
```
Expected: clean git, `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Open a PR**

```bash
gh pr create --title "Rename project to CardWise" --fill
```

---

## Self-Review

- **Spec coverage:** repo name ✓ (T7), folder name ✓ (T8), brand match ✓ (T2–T6). Bundle IDs/app group ✓ (T3–T4). Build/tests gate ✓ (T5).
- **Risk — GitHub rename perms:** handled with fallback to user (T7 note).
- **Risk — repo-root move breaking tooling:** isolated to last task (T8).
- **Risk — StoreKit/app-group literal drift:** explicit reconciliation steps (T4.3, T4.2).
- **Type/name consistency:** struct `CardWiseApp`, `CardWiseWidget`, app-group `group.com.cardwise.app`, bundle `com.cardwise.app*` used consistently across tasks.
