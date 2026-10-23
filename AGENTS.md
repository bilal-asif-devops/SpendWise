# SpendWise — Permanent Development Rules & Engineering Standards

These rules establish strict, non-negotiable project-level constraints and best practices for developing, testing, maintaining, and verifying the SpendWise Flutter application (`SpendWise_Flutter`).

---

## 1. Protect the Existing Project
- **Baseline Verification:** Always inspect the current Git branch, commit SHA, working tree, project structure, and existing rule files before making modifications.
- **Preserve Working Features:** Existing working features, guest data isolation, transaction entry flows, and Firebase configurations (`lib/firebase_options.dart`, `android/app/google-services.json`, `firestore.rules`) must be preserved. Never overwrite, delete, or fabricate configuration values.
- **Explicit Approval for Changes:** Never delete or overwrite established configuration, dependencies, or vault storage formats without explaining the rationale and obtaining explicit user approval.
- **History & Branch Protection:** Do not switch branches, reset changes, or rewrite Git history without explicit user permission. Dedicated feature or bug-fix branches must branch from verified base commits.

---

## 2. Flutter and Dart Quality
- **Official Standards:** Adhere strictly to Effective Dart and official Flutter architectural guidelines.
- **Architecture & State Management:** Maintain the established Provider-based architecture (`FinanceProvider`, `AuthSyncProvider`), immutable data models, and clean separation between UI widgets, domain providers, and services.
- **Responsive Layout Design:** 
  - Ensure all layouts adapt gracefully without `RenderFlex` overflow across viewports ranging from narrow mobile screens (320px–400px wide, e.g. 400 × 642) to desktop browsers (1280px+).
  - Use `Expanded`, `Flexible`, `ConstrainedBox`, and `TextOverflow.ellipsis` on variable-length texts, headers, and action rows.
  - Never wrap `ListTile`s in intermediate colored `Container`s without an intervening `Material` widget (use `Material(color: ..., shape: ...)` directly to preserve ink splashes and avoid framework assertion failures).
- **Mandatory Verification Pipeline:** After any meaningful code change, execute:
  1. `dart format` (ensure all files adhere to canonical Dart formatting)
  2. `flutter analyze` (maintain 0 errors, 0 warnings, 0 lints)
  3. `flutter test` (run the relevant test suite or full suite; maintain 100% pass rate)
  4. Build verification (`flutter build web --release` or target platform build)

---

## 3. Financial Correctness
- **Precision & Safety:** Use precise, decimal-safe monetary calculations. Never rely on unrounded floating point operations for balance mutation or currency conversions.
- **Currency & Invariants:**
  - Safely handle multi-currency conversions and user-selected primary currency symbols.
  - Prevent balance distortion during transfers or liability settlements (e.g. credit card bill payments debit source cash and reduce card liabilities by the exact payment amount without inflating `totalExpenses`).
  - Validate non-zero, positive, finite transaction amounts; reject `NaN`, negative amounts, and positive/negative infinity.
- **Historical Integrity:** Never silently alter historical transactions, category assignments, or wallet balances.

---

## 4. Firebase and Security
- **Authentic Configuration:** Always use real Firebase configuration generated via FlutterFire CLI (`lib/firebase_options.dart`). Never fabricate mock IDs or credentials in production files.
- **Truthful Cloud Sync:**
  - Verify Firestore rules, real connectivity, and actual read/write behavior before reporting a successful synchronization.
  - Never report a successful cloud sync based solely on authentication state (`isAuthenticated`). Only display `"Cloud Synced • Firebase"` when a sync has genuinely completed (`lastSyncTime != null`).
  - When authenticated prior to initial sync, truthfully display `"Account Connected • Firebase"`.
- **Per-User Isolation:** Enforce strict UID-based data isolation (`users/{uid}/vault`). One user must never read or write another user's financial vault.
- **Zero Credential Leakage:** Never log, print, or commit auth tokens, private keys, refresh secrets, or PII. Diagnostic logging must only output high-level safe flags (`userExists`, `providerIds`, `isAnonymous`, `emailDomain`).

---

## 5. Real Functionality
- **No Deceptive Placeholders:** Do not substitute mock data, hardcoded fake accounts, or simulated bank connections for real functionality.
- **Explicit Labeling:** Clearly identify prototypes, roadmap previews, or coming-soon features (e.g. receipt scanning roadmap dialogs).
- **Guest & Offline Behavior:** Preserve deterministic Guest Mode and offline-first capabilities. Guest vaults must remain completely isolated from sample data, and local vaults must never be overwritten by stale state upon reload.

---

## 6. MCPs, Skills, and Browser Verification
- **Ecosystem Capabilities:** Actively use installed official Flutter, Dart, and Firebase skills (`.agents/skills/` or Antigravity builtins) for testing, static analysis, rules authoring, and layout fixes.
- **Genuine Tool Invocations:** Use only MCP tools and servers that are genuinely registered and active (e.g. REA MCP, flutter_dart MCP). Never invent tool names or falsely claim a tool was executed.
- **Runtime Browser Inspection:** 
  - Utilize REA browser inspection tools (`list_browser_targets`, `inspect_web_page`, `capture_web_screenshot`) when verifying live web preview UI on `localhost`.
  - Validate visual rendering on actual browser viewports to catch rendering overflows and layout anomalies rather than relying solely on static code review.

---

## 7. Completion Reports
For every substantial task, the completion report must document:
1. **Root Causes & Architecture:** Clear explanation of why any issue occurred and how it was resolved.
2. **Files Changed:** Granular list of modified, added, or removed files with line references.
3. **Automated Test Results:** Explicit command output and passed/failed counts across test suites.
4. **Static Analysis & Build Status:** Results of `flutter analyze` and `flutter build`.
5. **Runtime & Visual Verification:** Evidence from browser or runtime testing (distinguishing real backend results from mock tests).
6. **Open Questions & Manual Actions:** Clear disclosure of any required manual user steps or console configurations.
