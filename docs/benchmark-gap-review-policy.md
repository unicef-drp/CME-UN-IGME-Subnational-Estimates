# Batch benchmark gaps: non-blocking review

User instruction on 23 September 2026: accept the reported gaps and do not stop
the queue at this check. Move the review to the end of batch processing.

The sequential batch worker now logs threshold exceedances and continues after
successful model/report execution and required output validation. It preserves
all per-country `benchmark_gap_validation.csv` files and manifest flags.
`batch_summary.csv` records the review flag and maximum NMR/U5MR gaps for every
newly completed country. `benchmark_gap_review.csv` collects flagged countries
for end-of-batch review, including prior runs from
`prior_benchmark_gap_review.csv`.

Thresholds and calculations remain unchanged: NMR 2 per 1,000 and U5MR 5 per
1,000 are review thresholds, not exact-equality constraints. No saved estimates
are edited, rescaled or refitted to eliminate a gap. This instruction applies
to gap warnings for the continuing queue, not just Haiti or Cameroon.

Required input, backup, execution, output-readability, finite-draw, coverage and
report validation failures still stop processing. Missing/unmatched historical
regions use the separately approved current-only summary fallback. Scientific
methodology and JSON-selected model scope are unchanged. Visual/analytical
review remains required before publication.

Haiti completed all stages in `20260922_235336_igme_refresh`; its models and
reports are retained and will not be rerun solely for the accepted gap warning.
