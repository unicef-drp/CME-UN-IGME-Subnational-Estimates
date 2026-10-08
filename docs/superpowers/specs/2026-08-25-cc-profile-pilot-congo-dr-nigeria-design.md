# 2026 CC Profile Pilot: Congo DR and Nigeria

## Status

Approved architecture, narrowed to a two-country pilot on 2026-08-25. Implementation must not begin until the user reviews this written specification.

## Objective

Build a standalone 2026 CC-profile exporter under `2026 Round Subnational/_code_CC_subnational` and pilot it for Congo DR and Nigeria. The exporter must read validated outputs from `UN-Subnational-Estimates-main`, reproduce the 2023 map-and-workbook pattern for 2000–2025, and write new profiles under `2026 Round Subnational/CC profile Subnational` without modifying the estimation repository's data or result artifacts.

## Pilot scope

The pilot produces four map PNGs and two Excel profiles:

- `maps/DR_Congo_U5MR.png`
- `maps/DR_Congo_NMR.png`
- `maps/Nigeria_U5MR.png`
- `maps/Nigeria_NMR.png`
- `CC profile Subnational/Democratic Republic of the Congo_subnational_estimates.xlsx`
- `CC profile Subnational/Nigeria_subnational_estimates.xlsx`

Congo DR exercises the Admin-1 plus Admin-2 template. Nigeria exercises the Admin-1-only template. Both countries include U5MR and NMR.

The pilot does not rerun models, change country JSON, edit boundaries, alter final-model selection, create publication-ready methodology text, or generate profiles for other countries.

## Observed input contract

### Congo DR

- Country key: `DR_Congo`; ISO3: `COD`; display name: `Democratic Republic of the Congo`.
- Configuration: `Info/DR_Congo_general_info.json`.
- Final model: AR1, unstratified, all-survey, benchmarked.
- GeoRepo layers: `georepo_COD_1` and `georepo_COD_2`.
- Admin-name tables: 26 Admin-1 rows and 188 Admin-2 rows.
- Final U5MR and NMR results each contain 676 Admin-1 rows and 4,888 Admin-2 rows: one row for every area and year from 2000 through 2025.
- Included survey records resolve to DHS 2007, DHS 2013, MICS 2018, and DHS 2023. The profile display text preserves the fieldwork-year wording from the 2026 country list: `Demographic and Health Survey 2007; Demographic and Health Survey 2013–2014; Multiple Indicator Cluster Survey 2018; Demographic and Health Survey 2023–2024`.

### Nigeria

- Country key and display name: `Nigeria`; ISO3: `NGA`.
- Configuration: `Info/Nigeria_general_info.json`.
- Final model: AR1, unstratified, all-survey, benchmarked.
- Configured output scope: Admin-1 only. The presence of an Admin-2 boundary file does not authorize an Admin-2 profile because `poly.layer.adm2` is absent from the country configuration and no Admin-2 final model is selected.
- Admin-name table: 38 Admin-1 rows.
- Final U5MR and NMR results each contain 988 Admin-1 rows: one row for every configured area and year from 2000 through 2025.
- Included survey records resolve to DHS 2003, DHS 2008, MIS 2010, DHS 2013, MICS 2017, DHS 2018, MICS 2021, and DHS 2024. The profile display text is `Demographic and Health Survey 2003; Demographic and Health Survey 2008; Malaria Indicator Survey 2010; Demographic and Health Survey 2013; Multiple Indicator Cluster Survey 2017; Demographic and Health Survey 2018; Multiple Indicator Cluster Survey 2021; Demographic and Health Survey 2024`.
- `Under National Administration` is present in both the configured name table and final results. The pilot must not silently remove it. Any exclusion requires an explicit country-configuration decision outside this exporter.

All six selected result tables have finite medians, ordered lower/median/upper bounds, and no duplicate region-year pairs.

## Recommended architecture

The exporter is a separate downstream product with three stages.

### 1. Extract and validate

R code reads the country JSON, resolves the configured final-model filenames, loads each selected `.rda`, and extracts the `overall` table. It maps internal region identifiers through `<Country>_Amat_Names.rda`, reads the configured GeoRepo layers with `sf`, and emits normalized profile-data CSV files plus a machine-readable validation summary.

Normalized estimate rows contain:

- country key, ISO3, and display name;
- indicator (`U5MR` or `NMR`);
- administrative level;
- Admin-1 and optional Admin-2 display names;
- internal region identifier;
- year;
- median, lower, and upper estimates per 1,000 live births.

The extractor multiplies probability-scale model values by 1,000 only once and rounds workbook-facing estimates to one decimal. The unrounded normalized values remain available for map classification and validation.

### 2. Render maps

R code renders maps with `sf` and `ggplot2`; it does not use the retired `rgdal`, `rgeos`, or `maptools` packages from the 2023 workflow.

Each administrative level is one horizontal block:

- left: a large 2025 map with a scale bar and readable area labels;
- right: small multiples for every year from 2000 through 2025;
- shared fixed legend and colors matching the 2023 profiles.

Admin-1 and Admin-2 blocks are stacked vertically for Congo DR. Nigeria contains only the Admin-1 block. Admin-1 labels are shown. Admin-2 labels may be omitted when collision checks show they are unreadable; Congo DR's 188 Admin-2 areas are expected to trigger this rule. The estimates sheet remains the complete name reference.

U5MR classes, in deaths per 1,000 live births, are `≤25`, `25 to 50`, `50 to 75`, `75 to 100`, `100 to 150`, `150 to 200`, `200 to 300`, and `>300`.

NMR classes are `≤12`, `12 to 20`, `20 to 25`, `25 to 30`, `30 to 40`, `40 to 50`, `50 to 60`, and `>60`.

The ordered palette is `#CFF4FF`, `#FEEC9F`, `#FFD591`, `#FFC069`, `#FA8C16`, `#D46B08`, `#AD4E00`, and `#612500`.

### 3. Build workbooks

The workbook builder imports copies of the 2023 Admin-1 and Admin-2 templates, preserving their existing styles, dimensions, hyperlinks, and IGME branding. It updates the year labels from 2000–2021 to 2000–2025, writes the country title and numeric estimate rows, adds survey-source text, replaces the GADM boundary note with `Administrative boundaries are based on UNICEF GeoRepo, available at https://georepo.unicef.org/`, and embeds the new PNGs in the map sheets.

GeoRepo exposes only generic administrative-level types for these pilot layers, so the table headers remain `Admin Level 1` and `Admin Level 2`. The exporter must not invent country-specific type labels.

The legacy templates contain a stale workbook-defined name, `data_region`, whose formula is `#REF!`. The builder removes that unused defined name so the completed pilot workbooks do not retain a known formula error.

The 2023 files contain embedded map images, not native Excel chart objects. The pilot reproduces that structure and does not introduce unrelated charts.

Workbook tables are sorted by administrative level, Admin-1 name, Admin-2 name where applicable, and descending year, matching the established 2023 convention. Numeric cells remain numeric and use one decimal place.

## Directory layout

```text
2026 Round Subnational/
├── _code_CC_subnational/
│   ├── README.md
│   ├── config/
│   │   └── pilot_countries.csv
│   ├── templates/
│   │   ├── 2026_subnational_template_admin1.xlsx
│   │   └── 2026_subnational_template_admin2.xlsx
│   ├── R/
│   │   ├── cc_paths.R
│   │   ├── final_estimates.R
│   │   ├── profile_data.R
│   │   └── profile_maps.R
│   ├── js/
│   │   └── build_profiles.mjs
│   ├── tests/
│   ├── maps/
│   └── output/
│       ├── profile_data/
│       └── logs/<run-id>/
└── CC profile Subnational/
```

Paths are resolved from the exporter location or explicit command arguments. No script may depend on the current working directory, a Dropbox path, or a hard-coded user profile.

## Error handling and overwrite policy

The pilot validates before writing final artifacts. It stops a country on:

- missing or ambiguous final-model files;
- missing expected years;
- duplicate region-year rows;
- non-finite estimates or inverted uncertainty bounds;
- mismatched name-table, result, and boundary area sets;
- a configured Admin-2 level without valid Admin-2 estimates;
- missing or unreadable map PNGs before workbook creation.

One country's failure does not invalidate the other country's completed artifacts. The run summary records each country-indicator-level status and the exact blocker.

Existing maps and workbooks are not overwritten unless the pilot is invoked with an explicit overwrite flag. Because the 2026 destination is initially empty, the first successful run needs no replacement approval.

## Manifest and reproducibility

Every pilot run writes a timestamped manifest containing:

- repository root, git commit, and dirty-state summary;
- country JSON path and hash;
- selected final-model fields and resolved result paths;
- boundary metadata path, source, layers, and feature counts;
- estimate row counts, year range, and join diagnostics;
- survey-source text;
- commands, runtime versions, warnings, failures, and output paths;
- output file sizes and hashes;
- final status for each country.

The manifest must not contain credentials or row-level survey microdata.

## Tests and acceptance criteria

Focused tests cover:

1. Final-model filename resolution for the unstratified all-survey benchmarked branch.
2. Probability-to-per-1,000 conversion and one-decimal workbook output.
3. Exact region/year cardinalities: Congo DR 26 and 188 regions; Nigeria 38 regions; 26 years each.
4. Exact result/name/boundary set agreement.
5. Ordered uncertainty bounds, finite values, and duplicate detection.
6. Admin-2 selection from configuration rather than shapefile presence.
7. Fixed legend breaks, labels, and colors.
8. Workbook template selection, sheet names, title/year replacements, and numeric estimate cells.
9. Formula-error scan and drawing inventory after workbook export.

Visual acceptance requires inspection of all four PNGs and all sheets in both workbooks. Maps must not have blank panels, clipped legends, overlapping titles, unreadable Admin-1 labels, or missing years. Workbooks must retain the template's branding and layout, show the embedded maps, display complete headers and source notes, and contain no obvious clipped values or broken formulas.

The pilot is complete only when both profiles and all four maps pass these checks, or when any incomplete country is reported with a specific blocker and no invalid profile is presented as successful.
