# Ghana Admin-1 Pipeline Design

## Objective

Produce the Ghana BB8 comparison dashboard and country summary PDF using Admin-1 outputs only. The all-survey unstratified family will use DHS 2003, 2008, 2014, and 2022 plus MICS 2011 and 2018. The shared-frame family will use 2011, 2014, and 2018, all based on the 2010 Population and Housing Census frame.

## Selected approach

Keep the checked-in Ghana GeoRepo Admin-2 layer available during survey preprocessing so DHS and MICS GPS clusters can be spatially assigned without weakening the source data. Before direct estimates and every downstream stage, remove the Admin-2 layer variables from the active country context and set `BB8_ADMIN1_ONLY=1`. This preserves complete geospatial preprocessing while preventing Admin-2 direct, weight, BB8, dashboard, diagnostic, report, and summary outputs.

Two alternatives were rejected:

- Removing Admin-2 from Ghana's persistent Info file would simplify downstream execution but would discard useful Admin-2 assignments during preprocessing.
- Setting only `BB8_ADMIN1_ONLY=1` would suppress BB8/report Admin-2 products but would still run Admin-2 direct estimates and population weights.

## Country configuration

- Keep `frame_year` at 2010.
- Set `surveys_1frame` to `2011, 2014, 2018` in both Ghana Info sources.
- Keep the all-survey data file limited to `2003, 2008, 2011, 2014, 2018, 2022`.
- Select benchmarked all-survey unstratified Admin-1 BB8 as the final report model.
- Preserve the GeoRepo Ghana Admin-0/1/2 layers and use the existing 10-region Admin-1 geography.

## MICS processing

Extract the Ghana MICS 2017/18 GPS shapefile into a survey-specific repository folder. Add a Ghana-specific entry point to `MICS_Geospatial_DataProcessing.R` that combines `gha_2018_bh.sav` with the GPS clusters and assigns GeoRepo Admin-1/Admin-2 names. Save the result as `gha.2018.geo.tmp.rda`.

Add deterministic MICS temporary-file selection so recursive survey folders are supported and a `*.geo.tmp.rda` artifact replaces the non-geospatial artifact for the same survey rather than duplicating it.

Regenerate the MICS 2011 non-geospatial artifact without dropping Brong Ahafo. The survey and GeoRepo both use the same ten Admin-1 regions, so all ten regions must be retained.

## Execution flow

1. Validate Ghana configuration and MICS preprocessing tests.
2. Create the Ghana 2011 non-GPS and 2018 GPS temporary artifacts.
3. Run preparation and GeoRepo checks.
4. Run data processing with full spatial matching, then verify the all-survey and same-frame survey inventories.
5. Remove Admin-2 variables from the active context for downstream scripts.
6. Run direct/smoothed-direct estimates, Admin-1 population weights, and the preliminary comparison.
7. Use the verified 2010 urban-frame CSV to create stratification weights.
8. Fit both shared-frame stratified and all-survey unstratified BB8 families, including Admin-1 benchmarks.
9. Generate the comparison dashboard, diagnostics, final report plots, and summary PDF.

## Verification

- The 2018 MICS artifact must contain 660 GPS clusters with non-missing coordinates and GeoRepo Admin-1 names.
- Both MICS artifacts must cover all ten Ghana Admin-1 regions, including Brong Ahafo.
- `Ghana_cluster_dat.rda` must contain exactly `2003, 2008, 2011, 2014, 2018, 2022`.
- `Ghana_cluster_dat_1frame.rda` must contain exactly `2011, 2014, 2018`.
- Admin-1 U1 and U5 weights must cover 2000 through 2025 and sum to one within each year.
- The Betabinomial result inventory must include shared-frame stratified and all-survey unstratified Admin-1 NMR/U5MR outputs and benchmarks, with no required Admin-2 products.
- The dashboard and `Results/Ghana/11_CountrySummary.pdf` must render successfully.
- Benchmarked population-weighted Admin-1 aggregates must be compared with IGME; investigate U5 gaps above 5 per 1,000 or NMR gaps above 2 per 1,000.

