# Nigeria WorldPop Alignment Comparison Design

## Goal

Produce a Nigeria-only comparison of under-one (U1) and under-five (U5) population counts from three WorldPop raster sources:

1. Legacy Global 1 before alignment, 2000–2020.
2. The locally available Global 1 rasters aligned to Global 2, 2000–2015.
3. Global 2 R2025A, 2015–2025.

The comparison will include one whole-country figure and a separate Admin-1 faceted figure. It will not alter the population-weight files used elsewhere in the mortality-estimation pipeline.

## Scope

### Included

- Nigeria only.
- Annual years 2000–2025.
- U1 and U5 population counts.
- Whole-country totals derived by summing the Admin-1 zonal totals.
- Nigeria Admin-1 unit totals using all 38 polygons in the repository's GeoRepo layer: 36 states, Federal Capital Territory, and `Under National Administration`.
- Download and retention of the legacy 2000–2020 source rasters.
- Static PDF plots and tidy CSV comparison tables.
- An input manifest recording the source, year, sex, age band, path, and file-readability status of every raster.

### Excluded

- Admin-2/LGA aggregation.
- Interactive HTML output.
- Changes to `adm1_weights_u1.rda`, `adm1_weights_u5.rda`, or other pipeline weights.
- Replacement or deletion of the existing untracked U5-only exploratory script and outputs.

## Data Sources

### Legacy Global 1, 2000–2020

Download four 1 km unconstrained age-sex rasters for each year from the official WorldPop `Global_2000_2020_1km` collection:

```text
https://data.worldpop.org/GIS/AgeSex_structures/Global_2000_2020_1km/unconstrained/{year}/NGA/nga_{sex}_{age}_{year}_1km.tif
```

For every year, `{sex}` is `f` or `m` and `{age}` is `0` or `1`. The consolidated raw-data location is:

```text
C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents/UN IGME Subnational/Worldpop data/Global1_2000_2020/Nigeria/
```

The downloader will cache valid existing files, download through a temporary filename, verify that the GeoTIFF is readable, and only then move it to its final filename.

### Aligned Global 1, 2000–2015

Read the locally available constrained 1 km rasters from:

```text
C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents/UN IGME Subnational/Worldpop data/Global1_2000_2020_aligned/Nigeria_extracted/{year}/NGA/nga_{sex}_{age}_{year}_constrained_1km.tif
```

Aligned 2015 is retained alongside Global 2 2015 so the two sources can be compared in their shared transition year.

### Global 2 R2025A, 2015–2025

Read the locally available constrained 1 km aggregate rasters from:

```text
C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents/UN IGME Subnational/Worldpop data/Global2_2015_2030/Nigeria/nga_{sex}_{age2}_{year}_CN_1km_R2025A_UA_v1.tif
```

Here `{age2}` is `00` for under one and `01` for ages one through four.

### Administrative boundaries

Use the Nigeria GeoRepo layers already configured by `Info/Nigeria_general_info.json`:

- Admin 0: `georepo_NGA_0`
- Admin 1: `georepo_NGA_1`

Use the existing Nigeria admin-name crosswalk so plot facets display GeoRepo state names.

## Population Definitions

For every source and year:

```text
U1 = female age 0 + male age 0
U5 = female age 0 + female age 1–4 + male age 0 + male age 1–4
```

The legacy/aligned age-band code `1` and the Global 2 age-band code `01` both represent ages one through four.

## Aggregation

1. Load and sum the required sex/age raster layers for U1 and U5 without writing additional combined rasters.
2. Reproject the GeoRepo polygons to the raster CRS when necessary; do not resample population counts solely to match the boundary CRS.
3. Reuse the repository's rasterize-plus-zonal-sum convention to calculate an Admin-1 population count for each state.
4. Define the whole-country value as the sum of all Admin-1 zonal counts for the same source, year, and indicator.
5. Also calculate an independent Admin-0 zonal count as a diagnostic. Record the difference from the summed Admin-1 result and fail verification when the absolute discrepancy exceeds 0.25% of the Admin-0 total. This tolerance allows for raster-cell assignment along independently rasterized Admin-0 and Admin-1 edges while still detecting material coverage problems.
6. Retain source-specific series rather than interpolating or extending missing years.

The comparison represents the combined effect of the source revisions, alignment, constrained/unconstrained methods, and updated demographic totals. Plot labels and notes will describe it as a source comparison rather than attributing every difference solely to spatial realignment.

## Outputs

Write analysis outputs under:

```text
Data/Countries/Nigeria/worldpop/comparison/
```

### Tables

- `nigeria_worldpop_input_manifest_2000_2025.csv`
  - One row per source/year/sex/age raster.
  - Includes the source label, expected path, file existence, and readability check.
- `nigeria_worldpop_national_u1_u5_2000_2025.csv`
  - One row per source/year/indicator.
  - Includes summed Admin-1 total, independent Admin-0 total, and their difference.
- `nigeria_worldpop_admin1_u1_u5_2000_2025.csv`
  - One row per source/year/indicator/Admin-1 unit.
  - Includes internal region identifier, GeoRepo label, and population count.
- `nigeria_worldpop_old_vs_aligned_difference_2000_2015.csv`
  - Paired legacy-versus-aligned differences and percentage differences at national and Admin-1 levels for the overlap period.

### Figures

- `nigeria_worldpop_national_u1_u5_2000_2025.pdf`
  - Two facets: U1 and U5.
  - Free y-scales so the smaller U1 counts remain readable.
- `nigeria_worldpop_admin1_u1_u5_2000_2025.pdf`
  - A multipage PDF faceted by Admin-1 unit.
  - U1 and U5 appear on separate page groups.
  - At most 20 states per page.

The three displayed series are:

- `Old Global 1 (pre-alignment)`, 2000–2020.
- `Aligned Global 1`, 2000–2015.
- `Global 2 R2025A`, 2015–2025.

Use stable source colors plus line types, points, and direct legend text so meaning does not depend on color alone. Add a vertical reference line at 2015 and do not draw connecting segments between sources, including where aligned Global 1 and Global 2 both contain 2015.

## Implementation Structure

Create a focused script:

```text
Rcode/_script_for_specific_tasks/compare_nigeria_worldpop_alignment.R
```

Separate pure helpers for source-path construction, U1/U5 composition, zonal aggregation, comparison-table construction, and plot-data preparation. Keep downloading and top-level orchestration outside those pure helpers so their behavior can be tested with small temporary rasters.

Create a focused test:

```text
tests/test_compare_nigeria_worldpop_alignment.R
```

The existing untracked `build_new_worldpop_u5_weights.R` file remains unchanged because it covers only U5 and includes legacy years outside this request.

## Error Handling

- Stop with a source/year-specific message when a required local aligned or Global 2 raster is missing.
- Retry no downloads implicitly; retain no failed final GeoTIFF.
- Reject a downloaded file that cannot be opened by `terra`.
- Stop when the four component rasters for an indicator do not share compatible geometry.
- Stop when any source/year/indicator total is non-finite or non-positive.
- Stop when an Admin-1 polygon lacks a GeoRepo display-name mapping.
- Record and report the Admin-0 versus summed Admin-1 closure diagnostic.

## Testing and Verification

Implementation will use a test-first workflow:

1. Verify source-path construction and source year ranges.
2. Verify U1 and U5 sums on synthetic rasters with known values.
3. Verify Admin-1 aggregation and national summation on synthetic polygons/rasters.
4. Verify that aligned Global 1 and Global 2 remain separate plot groups in their shared 2015 year.
5. Verify the output schema and expected source/year/indicator coverage.
6. Run the Nigeria analysis and confirm:
   - 84 legacy rasters are present and readable (21 years × 2 sexes × 2 age bands).
   - The aligned manifest contains 64 readable rasters (16 years × 2 sexes × 2 age bands).
   - The Global 2 manifest contains 44 readable rasters (11 years × 2 sexes × 2 age bands).
   - The national table contains 96 rows: 21 legacy, 16 aligned, and 11 Global 2 source-years, for two indicators.
   - The Admin-1 table contains those same source/year/indicator combinations for every Nigeria Admin-1 unit.
   - No population count is missing, non-finite, or negative.
   - Admin-0 versus summed Admin-1 closure is within 0.25%.
   - Both PDFs render without missing facets, clipped labels, or blank pages.

## Acceptance Criteria

- All raw rasters are read from the consolidated `Worldpop data` root and are readable.
- National and Admin-1 U1/U5 comparisons cover exactly the requested source-year ranges.
- The national PDF contains separate U1 and U5 facets and all three source labels.
- The Admin-1 PDF contains all 38 configured GeoRepo Admin-1 units for both indicators.
- Every Admin-1 facet retains a free upper scale and starts its y-axis at zero.
- CSV outputs preserve the exact counts used in the figures and provide explicit old-versus-aligned differences for 2000–2015.
- Existing mortality-pipeline population weights and the prior U5-only exploratory artifacts are unchanged.
