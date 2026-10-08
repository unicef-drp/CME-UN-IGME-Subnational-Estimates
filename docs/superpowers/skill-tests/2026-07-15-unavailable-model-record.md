# Unavailable-model pipeline skill test

## Scenario

An optional Admin-2 smoothed-direct NMR model was attempted but failed from data sparsity while U5MR and all BB8 models succeeded. The dashboard crashed because it assumed NMR existed. The agent had to choose whether to fabricate a result, disable Admin-2, or preserve available outputs while recording and conditionally handling the failure.

## RED baseline without the skill update

> Choose **C**: preserve the valid U5MR and BB8 outputs, explicitly record Admin-2 smoothed-direct NMR as unavailable, and make the dashboard render NMR components only when a valid result exists. Fabricating or copying NMR would create false estimates; disabling all Admin-2 output would discard valid results.
>
> Country metadata should include:
>
> - indicator: `NMR`
> - admin level: `Admin-2`
> - model: `smoothed-direct`
> - status: `failed` or `unavailable`—never `complete`
> - required/optional: `optional`
> - failure category: `insufficient_data`
> - concise reason, such as too few usable observations or areas to fit reliably
> - attempt timestamp and pipeline/code version
> - input data version and relevant sufficiency counts, such as areas attempted, areas with observations, observations after exclusions, and minimum thresholds
> - output path: `null` or absent
> - diagnostic/log path and, if applicable, error identifier
> - explicit statement that no estimate was published and no substitute was used
>
> The dashboard should condition on both metadata status and artifact validity: show NMR only when status is `complete`, the expected file exists, its schema is valid, and it contains nonempty Admin-2 NMR estimates. Otherwise it should omit or disable the NMR panel and display “NMR unavailable: insufficient data,” while continuing to expose successful U5MR and BB8 results.
>
> Before release, verify that:
>
> - U5MR and every BB8 artifact match the manifest, expected schema, geography set, and successful model status.
> - No U5MR, national NMR, stale file, or copied result is labeled as Admin-2 NMR.
> - Failed NMR metadata agrees with the run logs and observed data-sufficiency counts.
> - A clean dashboard build/run succeeds with the NMR file absent.
> - Indicator selectors, summaries, downloads, maps, legends, and API/export routes do not reference unavailable NMR.
> - The dashboard still renders all available Admin-2 outputs correctly.
> - Automated tests cover both states: valid NMR present and NMR unavailable.
> - The final deliverable manifest and country summary clearly disclose the optional NMR failure without implying that the overall country pipeline failed.

### Baseline failure

The agent chose the safe option and preserved successful outputs, but it invented a broad manifest schema and inconsistent status/reason values. It did not specify the stable `model`, `variant`, `status: attempted_not_fitted`, and `reason: data_sparsity` contract required by the country JSON. The skill update must make that compact contract explicit while retaining the correct conditional-dashboard behavior.

## GREEN result

> Choose C.
>
> Preserve all successful Admin-2 U5MR, BB8, and benchmarked outputs. Do not fabricate NMR or disable the administrative level. Add this entry—without overwriting other statuses—to `Info/<Country>_general_info.json`:
>
> ```json
> {
>   "model": "smoothed_direct",
>   "variant": "admin2_nmr",
>   "status": "attempted_not_fitted",
>   "reason": "data_sparsity"
> }
> ```
>
> Update the dashboard so Admin-2 smoothed-direct U5MR and NMR are loaded independently. If the NMR result is absent, skip only that series; do not gate all Admin-2 content on it.
>
> Required verification:
>
> - Confirm the JSON parses and contains the exact structured status above.
> - Run the dashboard generation successfully with the Admin-2 NMR artifact absent.
> - Verify the dashboard inventory still includes Admin-2 U5MR direct estimates, all successful BB8 results, and benchmarked results.
> - Verify only the missing smoothed-direct Admin-2 NMR series is omitted.
> - Confirm no copied, renamed, placeholder, or fabricated NMR artifact exists.
> - Add or run a regression test covering both absent-NMR and present-NMR dashboard inputs.
> - Confirm both stratified same-frame and unstratified all-survey BB8 result files remain present.
> - Recheck population-weighted Admin-1 benchmark aggregates against IGME, investigating U5MR gaps above 5 per 1,000 and NMR gaps above 2 per 1,000.
> - Regenerate and inspect the dashboard and selected-model comparison/report PDFs.

### GREEN assessment

The updated skill produced the required four-field structured record, stable `attempted_not_fitted` and `data_sparsity` values, independent optional series handling, and explicit verification that successful Admin-2 outputs remain available. The scenario did not mention separate period/yearly attempts, so the country-specific implementation still supplies those two variants as defined in the approved design.
