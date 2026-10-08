# Unmatched previous-final regions: current-only summary appendix

User decision, 22 September 2026: when previous-final regions cannot be
matched, omit that comparison and continue processing.

`run_country_summary_comparison_appendix()` now catches only the typed
`previous_final_unmatched_regions` error from the exact region-matching helper.
It regenerates the entire appendix using the existing current-only path:
current selected-model curves and available survey-direct estimates, without
previous-final curves. A warning identifies the unmatched regions. The
published `<Country>_appendix_status.csv` records the mode and skip reason
under `Results/<Country>/Figures/CurrentSubarea`.

Successful matches still produce the previous-final comparison. Missing or
unreadable inputs, invalid/ambiguous crosswalks, and missing required current
results remain errors. No fuzzy matching, crosswalk repair, configuration
changes, or model refitting are performed by this fallback. Older standalone
comparison artifacts are retained but are not appended to the new summary.

The standalone `run_previous_final_comparison()` and matching helper remain
strict; automatic fallback applies to summary assembly only. This policy is
not a waiver of benchmark-gap checks or visual review before publication.

Regression tests in `tests/test_previous_final_comparison.R` cover unmatched
Admin-1 and Admin-2, current/direct-only exported data, complete PDF assembly,
recorded skip reasons, matching previous-final plots and missing-workbook errors.
`tests/test_previous_final_admin1_mapping.R` retains strict crosswalk checks.

Ethiopia's failed summary from `20260922_184029_igme_refresh` is recovered
from the summary stage, reusing its completed benchmark/dashboard/diagnostic/
report stages. Its original pre-overwrite backup remains under
`C:/Users/yanliu/UNSubnationalBackups/20260922_183811/Ethiopia`.
