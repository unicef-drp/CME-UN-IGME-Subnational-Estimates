# Default national benchmarking
The base BB8 model is fitted with survey HIV adjustments only. National benchmark ratios never enter the survey likelihood or merge with HIV factors.

For each indicator, administrative level and year (including projection years), the second step calculates:
factor = national IGME median / sum(population weight * regional posterior median).

The same factor multiplies every regional posterior rate draw for that year, including urban/rural stratum draws where present. Summaries and variance are recalculated from transformed draws. The weighted regional medians match the national median; the median of the weighted joint posterior draws is a different statistic and need not match exactly. Regional ratios and joint within-model draw indices are preserved.

National medians are fixed targets. National uncertainty is not propagated. NMR/U5MR and Admin-1/Admin-2 remain independently calibrated; no cross-outcome ordering or cross-level consistency constraint is imposed. Invalid coverage, missing national years, invalid weights, or transformed rates outside [0,1] stop execution rather than clipping.

Files retain the conventional *_bench.rda names and carry benchmark$method = "direct_pointmedian_v1". Saved diagnostic components describe the HIV-adjusted base fit; they do not represent a second fitted model. Raw latent INLA samples are retained under source.fit.draws, while calibrated rate samples are in draws.est and draws.est.overall.

The main BB8, unstratified, Admin-1 backfill and final Admin-2 recovery paths all use the same helper. Resume checks reject legacy offset-refit benchmark files. Existing country outputs require a rerun before they reflect the new default.
