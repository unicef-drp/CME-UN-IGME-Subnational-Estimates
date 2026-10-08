# AI Reference: BB8 Workflow Notes

Source script: `Rcode/8_10_BB8.R`

These notes summarize how to interpret the Beta-Binomial (`BB8`) model outputs for AI-assisted review, comparison, and downstream workflow decisions.

## Main Workflow Interpretation

The script fits multiple BB8 model variants for NMR and U5MR at national, Admin-1, and, when available, Admin-2 levels.

For final subnational estimates, benchmarked results are usually the preferred output because they align the subnational model estimates with the IGME national series. The unbenchmarked models are still important, but mainly as intermediate and diagnostic products.

## Why Keep Unbenchmarked Models

Unbenchmarked models are useful for:

- checking the model's natural fit before national benchmarking is applied;
- comparing the model-implied national aggregate against IGME;
- detecting whether benchmark adjustments are large or unusual;
- comparing stratified versus unstratified specifications;
- comparing same-sampling-frame models versus all-survey models;
- inspecting fit diagnostics, hyperparameters, fixed effects, and temporal patterns;
- generating benchmark ratios used by the benchmarked models.

In short: unbenchmarked models are mainly for QA, diagnostics, sensitivity checks, and deriving benchmark adjustments. Benchmarked subnational models are normally the final-candidate outputs.

## Benchmarking Logic

The benchmark target is the IGME national series. Because of this, there are no benchmarked national BB8 models in the usual sense: national estimates are the reference series that subnational estimates are adjusted to match.

The script benchmarks subnational models by:

1. fitting or reusing an unbenchmarked subnational model;
2. aggregating its subnational estimates to a national estimate;
3. comparing that model-implied national estimate with the IGME national value;
4. creating a benchmark adjustment ratio;
5. refitting the subnational model with the benchmark adjustment included.

## Time Model Selection

Some scripts use `time.model <- c("rw2", "ar1")[2]`, which selects `"ar1"`. Treat `"ar1"` as the usual first-pass/default time model unless diagnostics show that it is too rigid.

Use this rule of thumb:

- `ar1` is smoother and more stable year to year. It is usually safer when subnational data are sparse, noisy, or unevenly spaced across surveys.
- `rw2` is more flexible and can capture accelerating or decelerating mortality decline, but it can also follow noise more easily.
- Start with `ar1`, compare model-implied national aggregates against IGME, and inspect subnational trajectories for implausible jumps, excessive smoothing, or unrealistic bends.
- Try `rw2` when `ar1` visibly misses important trend curvature.
- Prefer the simpler and more stable model unless `rw2` clearly improves fit without introducing noisy or implausible subnational behavior.

Do not choose the time model only by which line is closest to IGME after benchmarking. Benchmarking can force national alignment, so the choice should also consider diagnostics, unbenchmarked behavior, and the plausibility of subnational trends.

## Model Families Produced

### Same Sampling Frame

These models use surveys from the most recent/common sampling frame.

- `bb.natl.unstrat.nmr`
- `bb.natl.strat.nmr`
- `bb.adm1.unstrat.nmr`
- `bb.adm1.strat.nmr`
- `bb.adm2.unstrat.nmr` if `poly.layer.adm2` exists
- `bb.adm2.strat.nmr` if `poly.layer.adm2` exists
- `bb.natl.unstrat.u5`
- `bb.natl.strat.u5`
- `bb.adm1.unstrat.u5`
- `bb.adm1.strat.u5`
- `bb.adm2.unstrat.u5` if `poly.layer.adm2` exists
- `bb.adm2.strat.u5` if `poly.layer.adm2` exists

### Benchmarked Stratified Models

These are benchmarked subnational stratified models based on the same-frame data.

- `bb.adm1.strat.nmr.bench`
- `bb.adm2.strat.nmr.bench` if `poly.layer.adm2` exists
- `bb.adm1.strat.u5.bench`
- `bb.adm2.strat.u5.bench` if `poly.layer.adm2` exists

### All-Survey Unstratified Models

These models use all available surveys, including surveys from different sampling frames.

- `bb.natl.unstrat.nmr.allsurveys`
- `bb.adm1.unstrat.nmr.allsurveys`
- `bb.adm2.unstrat.nmr.allsurveys` if `poly.layer.adm2` exists
- `bb.natl.unstrat.u5.allsurveys`
- `bb.adm1.unstrat.u5.allsurveys`
- `bb.adm2.unstrat.u5.allsurveys` if `poly.layer.adm2` exists

### All-Survey Benchmarked Unstratified Models

These are benchmarked subnational unstratified models based on all-survey data.

- `bb.adm1.unstrat.nmr.allsurveys.bench`
- `bb.adm2.unstrat.nmr.allsurveys.bench` if `poly.layer.adm2` exists
- `bb.adm1.unstrat.u5.allsurveys.bench`
- `bb.adm2.unstrat.u5.allsurveys.bench` if `poly.layer.adm2` exists

## Practical Selection Rule

When choosing outputs for final use:

- prefer benchmarked subnational results when available;
- use unbenchmarked results for diagnostics and comparison;
- compare same-frame stratified benchmarked results against all-survey unstratified benchmarked results when deciding which specification is most appropriate;
- use `ar1` as the default time model and move to `rw2` only when the comparison dashboard and diagnostics show that additional time-trend flexibility is justified;
- treat Admin-2 outputs as conditional on the country having `poly.layer.adm2` available;
- remember that saved files are often result objects such as `bb.res...`, plus diagnostics and summaries, rather than full `bb...` model objects.
