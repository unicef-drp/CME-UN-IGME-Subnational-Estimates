# Ethiopia crisis allocation implementation plan

Goal: Implement the user-approved Tigray-only scenario for national famine crisis deaths in 2021-2023, with separate annual infant and age 1-4 population allocations to the seven Tigray zones.

Architecture: Add Ethiopia-specific preparation and application scripts. Reuse the existing tested death-to-qx and deterministic model-shift functions without changing their statistical behavior. Derive age 0 and age 1-4 population shares from the respective local WorldPop age-sex rasters; the existing u5 weight files combine both ages and cannot substitute for age 1-4. Aggregate zone populations and deaths to Admin-1 for exact hierarchy reconciliation. Scale national age-specific population totals using spatial shares, following the existing crisis denominator convention.

Tech stack: R, sf, terra, readxl, jsonlite, digest.

The geographic attribution for 2023 remains an explicit user-approved scenario assumption, not verified primary-source evidence. No new literature-derived mortality value is introduced. Preserve all source workbook totals. Preserve existing baseline model files, NMR, and unrelated countries.

- [x] Add and run failing tests for separate age shares, Tigray-only scope, annual and hierarchy reconciliation, missing/duplicate/invalid inputs, and refresh dispatch.
- [x] Implement preparation using current JSON, GeoRepo identifiers, source workbook and raw WorldPop bands 0 and 1 (ages 1-4).
- [x] Implement application using selected final model, separate crisis RDA outputs, source hashes and stale-input checks.
- [x] Back up touched existing files and hash baseline inputs. Run preparation/application and verify all summaries and estimated draws, unchanged non-target rows, raw draws, baseline files and NMR.
- [x] Enable Ethiopia crisis selection and refresh routing after successful output validation. Document method, evidence limits, national reconciliation and selected output paths. Produce a readable allocation CSV and diagnostic plot.

No model fitting, national-source revisions, DRC changes, or other-country adjustment changes are included.
