# History Management and Favorites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore safe history deletion/clear confirmation and add persistent favorite toggling from history cards and report details.

**Architecture:** Extend the existing database-store-repository-ViewModel chain with a single favorite update operation. Reapply the behavior of commit `7407c3f` to the current UI without cherry-picking unrelated files. Pages only dispatch ViewModel events and render operation state.

**Tech Stack:** HarmonyOS API 26, ArkTS, ArkUI, relationalStore, Hypium Local Test, Hvigor.

## Global Constraints

- Keep current diagnosis, AI, immersive UI, and navigation changes intact.
- Do not implement search, category filters, favorite sorting, OCR, JSON/HTTP completion, or T20-T24 acceptance.
- Favorite state is persisted in `diagnosis_report.is_favorite`; saved-time ordering does not change.
- Use a small focused test set and run the complete local suite once before completion.

---

### Task 1: Persistent favorite update

**Files:**
- Modify: `entry/src/main/ets/storage/database/DatabaseManager.ets`
- Modify: `entry/src/main/ets/storage/database/ReportStore.ets`
- Modify: `entry/src/main/ets/storage/database/LazyReportDataStore.ets`
- Modify: `entry/src/main/ets/repository/report/ReportRepository.ets`
- Modify: `entry/src/main/ets/repository/report/LocalReportRepository.ets`
- Modify: `entry/src/test/fakes/FakeReportDatabaseStore.ets`
- Modify: `entry/src/test/fakes/FakeReportStore.ets`
- Modify: `entry/src/test/fakes/FakeReportRepository.ets`
- Test: `entry/src/test/unit/ReportStore.test.ets`
- Test: `entry/src/test/unit/ReportRepository.test.ets`

**Interfaces:**
- Produces: `updateFavorite(reportId: string, favorite: boolean): Promise<AppResult<boolean>>` on store and repository contracts.
- Consumes: relationalStore update with an ID predicate and `{ is_favorite: 0 | 1 }` values.

- [ ] Add focused failing tests for persisted favorite toggle, missing report, and storage failure.
- [ ] Run `hvigor test --no-daemon` and confirm the new tests fail because `updateFavorite` is absent.
- [ ] Add the minimal database update boundary and implement the store/repository operation.
- [ ] Run `hvigor test --no-daemon` and confirm the focused tests pass.
- [ ] Commit with `feat: persist report favorites`.

### Task 2: History delete, clear, confirmation, and favorite UI

**Files:**
- Modify: `entry/src/main/ets/viewmodel/home/HomeModels.ets`
- Modify: `entry/src/main/ets/viewmodel/history/HistoryViewModel.ets`
- Modify: `entry/src/main/ets/components/history/HistoryReportCard.ets`
- Modify: `entry/src/main/ets/pages/history/RecordsRootView.ets`
- Modify: `entry/src/main/ets/pages/history/HistorySettingsPage.ets`
- Modify: `entry/src/main/ets/service/platform/AppRuntime.ets`
- Test: `entry/src/test/unit/HistoryViewModel.test.ets`

**Interfaces:**
- Consumes: `ReportRepository.deleteById`, `clearAll`, and `updateFavorite`.
- Produces: `deleteReport`, `clearHistory`, `toggleFavorite`, `retryMutation`, mutation state, and card events.

- [ ] Restore a minimal subset of the old `7407c3f` ViewModel tests and add one favorite success/failure test.
- [ ] Run `hvigor test --no-daemon` and confirm failure because mutation APIs are absent.
- [ ] Implement mutation state and safe list updates in `HistoryViewModel`.
- [ ] Add optional favorite/delete card actions; keep compact home cards unchanged.
- [ ] Add delete and clear confirmation dialogs to both history surfaces.
- [ ] Run `hvigor test --no-daemon` and confirm the focused tests pass.
- [ ] Commit with `feat: restore history management actions`.

### Task 3: Report detail favorite action and documentation

**Files:**
- Modify: `entry/src/main/ets/viewmodel/report/ReportViewModel.ets`
- Modify: `entry/src/main/ets/pages/report/ReportPage.ets`
- Test: `entry/src/test/unit/ReportViewModel.test.ets`
- Modify: `docs/开发实施计划.md`

**Interfaces:**
- Consumes: `ReportRepository.updateFavorite`.
- Produces: `toggleFavorite(): Promise<boolean>`, favorite mutation status/error, and a report-page favorite button.

- [ ] Add one failing ViewModel test for successful persistence and one for failure preserving state.
- [ ] Run `hvigor test --no-daemon` and confirm the new tests fail because the action is absent.
- [ ] Implement the ViewModel operation and report-page button/error notice.
- [ ] Update T16, T17, T19, and the P1 favorite status in `docs/开发实施计划.md`; leave T20-T24 truthful and incomplete.
- [ ] Run the complete local test suite, ArkTS linter, Debug HAP build, and `git diff --check`.
- [ ] Commit with `feat: add favorite action to reports`.
