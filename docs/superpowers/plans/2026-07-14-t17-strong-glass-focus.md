# T17 Strong Glass Focus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the three approved T17 focal surfaces visibly luminous on the API 26 emulator without changing business behavior.

**Architecture:** Centralize strong-glass colors in `ThemePalette`, then let the existing Home, Diagnosis, and Report pages consume the same semantic tokens. Use a translucent surface, a 2vp bright border, and one static colored shadow to produce the two visible light layers without adding components or animation loops.

**Tech Stack:** HarmonyOS API 26, ArkTS, ArkUI, Hypium Local Test, Hvigor, ArkTS Linter.

## Global Constraints

- Only T17 visual styling may change; do not implement T18–T24.
- Do not change diagnosis, routing, persistence, or ViewModel behavior.
- Do not add or debug scrolling/gesture UiTest cases.
- Keep the existing one-shot press scale animation; add no looping animation.
- Do not commit, push, merge, or modify signing configuration.

---

### Task 1: Strong-glass theme tokens

**Files:**
- Modify: `entry/src/test/unit/AppStateStore.test.ets`
- Modify: `entry/src/main/ets/theme/ThemeModels.ets`

**Interfaces:**
- Produces: `ThemePalette.focusGlow: string` for the three focal surfaces.
- Preserves: `getThemePalette(theme: EffectiveTheme): ThemePalette` returning an isolated palette copy.

- [x] **Step 1: Write the failing palette test**

Extend `returns centralized semantic palettes` with assertions that light and dark palettes expose different non-empty `focusGlow` values, and that the returned copies preserve this value.

- [x] **Step 2: Run Local Test and verify RED**

Run the existing Hvigor `test --no-daemon` command. Expected: ArkTS compilation fails because `focusGlow` does not exist on `ThemePalette`.

- [x] **Step 3: Implement minimal strong-glass tokens**

Add `focusGlow` to `ThemePalette`, define light and dark values, copy it from the palette, lower the opacity of `focusSurface`, and strengthen `focusBorder` for the selected C direction.

- [x] **Step 4: Run Local Test and verify GREEN**

Run the same Hvigor Local Test command. Expected: all tests pass, including the new palette assertions.

### Task 2: Apply the strong-glass modifier to the three focal surfaces

**Files:**
- Modify: `entry/src/main/ets/pages/home/HomePage.ets`
- Modify: `entry/src/main/ets/pages/diagnosis/DiagnosisPage.ets`
- Modify: `entry/src/main/ets/pages/report/ReportPage.ets`

**Interfaces:**
- Consumes: `ThemePalette.focusSurface`, `ThemePalette.focusBorder`, and `ThemePalette.focusGlow`.
- Preserves: existing button IDs, events, routing parameters, state bindings, and animation timing.

- [x] **Step 1: Apply the C-style static light layers**

For each approved focal surface, set border width to 2vp and add `shadow({ radius: 24, color: this.palette().focusGlow, offsetX: 0, offsetY: 6 })`. Keep `BlurStyle.Thin`; do not alter ordinary cards.

- [x] **Step 2: Run compile-focused verification**

Run full Local Test, ArkTS Linter, Debug HAP build, and ohosTest HAP build. Expected: all commands exit zero and ArkTS accepts the shadow options on API 26.

- [x] **Step 3: Check patch hygiene**

Run `git diff --check` and inspect `git diff` for the four production files plus the palette test. Expected: no whitespace errors and no unrelated business changes.

- [x] **Step 4: Report without committing**

Report modified files, command results, the manual emulator checks left to the user, and suggest `style: strengthen T17 glass focus` as the Git commit message. Do not create the commit.
