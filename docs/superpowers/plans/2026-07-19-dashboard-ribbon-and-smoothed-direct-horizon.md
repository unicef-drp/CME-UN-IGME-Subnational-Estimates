# Dashboard Ribbon and Smoothed-Direct Horizon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide uncertainty bands with their selected series and remove unsupported projected Admin-1 smoothed-direct values from comparison dashboards.

**Architecture:** Plotly line and ribbon traces share method-specific legend groups controlled by group-level legend clicks. The R comparison builder clips Admin-1 smoothed-direct aggregates to the midpoint of the final observed survey period before serializing the dashboard bundle.

**Tech Stack:** R, Plotly for R, Quarto, base-R regression tests.

---

### Task 1: Lock the requested behaviors into regression tests

**Files:**
- Modify: `tests/test_bb8_dashboard_interactivity_defaults.R`
- Create: `tests/test_comparison_smoothed_direct_observed_horizon.R`

- [ ] Add assertions that both Plotly ribbon helpers set `legendgroup = method_name` and that `chart_layout()` sets `groupclick = "togglegroup"`.
- [ ] Add assertions that `Rcode/9_Comparison_Plot.R` defines an observed smoothed-direct cutoff and applies it to both Admin-1 period and yearly aggregate frames.
- [ ] Run both tests and confirm they fail because the requested behavior is absent.

### Task 2: Implement grouped legend behavior

**Files:**
- Modify: `Rcode/9_Comparison_Plot.qmd`

- [ ] Add `groupclick = "togglegroup"` to the common legend layout.
- [ ] Assign each ribbon `legendgroup = method_name`.
- [ ] Build Admin-1 regional median traces per method so their names, colors, and legend groups exactly match the ribbons.
- [ ] Run `tests/test_bb8_dashboard_interactivity_defaults.R` and confirm it passes.

### Task 3: Limit smoothed-direct diagnostics to observed support

**Files:**
- Modify: `Rcode/9_Comparison_Plot.R`

- [ ] Define `smoothed_direct_observed_cutoff` as the maximum midpoint of observed survey periods.
- [ ] Filter `sd.adm1.to.natl.frame` and `sd.adm1.yl.to.natl.frame` to years at or before that cutoff.
- [ ] Run `tests/test_comparison_smoothed_direct_observed_horizon.R` and confirm it passes.

### Task 4: Rebuild and verify Kenya dashboard

**Files:**
- Regenerate: `Results/Kenya/Kenya_bb8_comparison_dashboard.html`
- Regenerate: `Results/Kenya/Kenya_bb8_comparison_data.rds`

- [ ] Run `Rcode/9_Comparison_Plot.R` for Kenya with `BB8_ADMIN1_ONLY=1` and the bundled Quarto executable on `PATH`.
- [ ] Assert in the RDS bundle that both Admin-1 smoothed-direct methods end in 2021 while IGME and the selected BB8 series end in 2025.
- [ ] Assert the HTML is self-contained and includes `legendgroup` and `togglegroup` Plotly configuration.
- [ ] Run the focused dashboard tests and `git diff --check` on modified source and tests.
