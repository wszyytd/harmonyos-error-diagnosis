# Morandi Glow Glass Buttons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the report and history pages' default blue buttons with a consistent fixed Morandi glow-glass button system.

**Architecture:** Extend the existing `GlassActionButton` visual-state model with semantic variants and reuse that component across report, history, and confirmation surfaces. Business callbacks and ViewModels remain unchanged.

**Tech Stack:** HarmonyOS API 26, ArkTS, ArkUI, ImmersiveMaterial, Hypium, Hvigor.

## Global Constraints

- Fixed palette: grey-blue `#7189A6`, sage `#7F9B86`, terracotta `#B06F61`, mist blue-grey `#A7B2BE`.
- Preserve all save, favorite, delete, clear, navigation, loading, and confirmation behavior.
- Keep touch targets at least 44 vp and disable heavy effects when `VisualEffectMode.OFF`.
- Do not change page layout, bottom navigation, OCR, tools, or theme settings.

---

### Task 1: Semantic Morandi glass component

**Files:**
- Modify: `entry/src/main/ets/components/common/GlassActionButtonModels.ets`
- Modify: `entry/src/main/ets/components/common/GlassActionButton.ets`
- Test: `entry/src/test/unit/GlassActionButtonModels.test.ets`

**Interfaces:**
- Produces: `GlassActionStyle` with `PRIMARY`, `FAVORITE`, `DANGER`, `SECONDARY`.
- Produces: `createGlassActionVisualState(..., style)` returning fixed semantic colors, glow, material, scale, and disabled state.

- [ ] Add focused failing assertions for all four semantic colors and effect-off degradation.
- [ ] Run `hvigor test --no-daemon` and confirm failure because semantic styles are absent.
- [ ] Implement the enum, semantic tokens, and component `style` property.
- [ ] Run `hvigor test --no-daemon` and confirm the suite passes.

### Task 2: Apply styles to report, history, and dialogs

**Files:**
- Modify: `entry/src/main/ets/pages/report/ReportPage.ets`
- Modify: `entry/src/main/ets/components/history/HistoryReportCard.ets`
- Modify: `entry/src/main/ets/pages/history/RecordsRootView.ets`
- Modify: `entry/src/main/ets/pages/history/HistorySettingsPage.ets`
- Modify: `entry/src/main/ets/components/common/ConfirmActionDialog.ets`

**Interfaces:**
- Consumes: `GlassActionButton` and `GlassActionStyle` only; existing callbacks remain unchanged.
- Produces: consistent visible labels and semantic glass treatment on every button in the selected surfaces.

- [ ] Replace report-page buttons with semantic `GlassActionButton` calls.
- [ ] Replace history card favorite/delete and history page clear actions.
- [ ] Replace privacy/back and confirmation dialog actions.
- [ ] Build the Debug HAP and run `git diff --check`.
- [ ] Commit with `style: unify morandi glow glass buttons`.
