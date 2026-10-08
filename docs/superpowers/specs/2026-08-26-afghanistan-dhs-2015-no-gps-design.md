# Afghanistan DHS 2015 No-GPS Admin-1 Design

## Goal

Include Afghanistan DHS 2015 in Admin-1 mortality estimation by assigning births to GeoRepo provinces from the labelled DHS `v024` variable, while retaining MICS 2023 as the only survey in the same-frame stratified branch and using DHS 2015 plus MICS 2023 in the final all-survey unstratified model.

## Sampling-Frame Contract

- The complete cluster dataset contains DHS 2015 and MICS 2023.
- The same-frame cluster dataset contains MICS 2023 only, controlled by `surveys_1frame: 2023`.
- Same-frame stratified models therefore continue to use MICS 2023 only.
- All-survey unstratified models use DHS 2015 and MICS 2023.
- Afghanistan's final model remains benchmarked and unstratified.

The surveys are intentionally kept in different branches because DHS 2015 used a household-listing frame prepared in 2003-04 and updated in 2009, whereas MICS 2022-23 used the 2019 NSIA satellite-imagery frame.

## Architecture

Add a narrowly scoped, configuration-driven DHS fallback to the shared processing path. The fallback is active only for survey years explicitly listed in a country's Info JSON. Normal DHS surveys must continue to provide both a births recode and geographic dataset and follow the existing GPS-to-polygon assignment.

For configured no-GPS surveys, the processor will:

1. Retain a births-recode-only survey during DHS API selection.
2. Read the configured labelled Admin-1 variable (`v024`).
3. Convert its value labels to province names.
4. Apply explicit country aliases.
5. Fail closed unless the mapped observed names match the GeoRepo Admin-1 inventory exactly.
6. Attach GeoRepo Admin-1 indices and internal names.
7. Set longitude and latitude to missing because no point data exist.

The reusable validation and assignment logic belongs in a supporting helper. The main data-processing script only selects the applicable branch and preserves the existing birth-history transformation.

## Afghanistan Mapping

The DHS 2015 recode exposes 34 `v024` labels. Six differ from the current GeoRepo names:

| DHS label | GeoRepo label |
|---|---|
| Wardak | Maidan Wardak |
| Kunarha | Kunar |
| Nooristan | Nuristan |
| Urozgan | Uruzgan |
| Helmand | Hilmand |
| Herat | Hirat |

All other province labels match directly. The mapped set must equal all 34 GeoRepo Admin-1 regions.

## Why BB8 Remains Possible Without GPS

Admin-1 BB8 does not require household or cluster point coordinates when the survey already identifies the Admin-1 unit. The observation likelihood is constructed from births, deaths, exposure time, survey weights, time, and province membership. Spatial smoothing is defined by the GeoRepo province adjacency matrix, not by the survey cluster coordinates. GPS is needed only to infer province membership when the recode does not already provide a validated Admin-1 identifier, and for finer geospatial assignment that this Admin-1-only run does not attempt.

## Failure Conditions

Processing stops rather than guessing if the configured variable is absent or unlabelled, a DHS label is blank, a mapped label is absent from GeoRepo, two labels map ambiguously, or the observed mapped inventory does not cover the configured GeoRepo Admin-1 inventory.

## Testing and Verification

- Unit-test births-only DHS survey selection.
- Unit-test labelled `v024` extraction and all six Afghanistan aliases.
- Unit-test fail-closed behavior for an unmatched province.
- Run the real Afghanistan processing stage and verify both surveys in the complete dataset and only 2023 in the same-frame dataset.
- Refit Admin-1 models and verify the final filenames select benchmarked, unstratified, all-survey results.
- Regenerate and visually inspect the dashboard and country-summary PDF.

