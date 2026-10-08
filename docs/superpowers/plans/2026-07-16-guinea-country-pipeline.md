# Guinea Country Pipeline Execution Plan

**Goal:** Produce the Guinea BB8 model comparison dashboard and country-summary PDF using DHS 2005, DHS 2012, and DHS 2018. MICS 2016 is explicitly excluded because it is excluded from the national estimates.

**Configuration:** `Info/Guinea_general_info.json` is the source of truth. Keep `frame_year` as `[2014, 2017]`, set `surveys_1frame` to `[2018]`, set `survey_excluded` to `[2016]`, and retain the unstratified model as the final reporting model after comparing both model families.

**Required inputs:** GeoRepo Guinea administrative boundaries; DHS birth-recode and GPS files for 2005, 2012, and 2018; Guinea urban-frame proportions; population and IGME benchmarking inputs already used by the repository.

## Execution checkpoints

1. Validate the JSON syntax and the configured survey-frame values.
2. Run the Guinea preparation/preflight path and inventory all country inputs.
3. Download DHS inputs through the existing DHS workflow and verify the 2005, 2012, and 2018 birth-recode/GPS pairs.
4. Run Guinea data processing and verify that MICS 2016 is excluded while DHS 2005, 2012, and 2018 remain.
5. Run direct estimates, administrative weights, and pre-BB8 validation.
6. Run the same-frame stratified BB8 model using DHS 2018, plus the all-survey unstratified BB8 model using DHS 2005, 2012, and 2018.
7. Generate benchmark outputs, model-comparison plots, diagnostics, report plots, and `Results/Guinea/Guinea_bb8_comparison_dashboard.html`.
8. Render `Rcode/11_CountrySummary.Rmd` to `Results/Guinea/11_CountrySummary.pdf` with the repository's Quarto/Pandoc setup.
9. Run the GeoRepo, MICS, BB8, dashboard, and country-summary checks. Render the PDF to images and visually inspect pages 1, 2, and the last page.

## Completion evidence

- Both stratified and unstratified Guinea BB8 result families exist and pass validation.
- The comparison dashboard exists and contains Guinea model outputs.
- `Results/Guinea/11_CountrySummary.pdf` renders successfully and passes automated and visual checks.
- The run manifest/log records any excluded survey or unmet input explicitly; no survey is silently omitted.
