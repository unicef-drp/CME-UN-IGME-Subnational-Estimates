# Ethiopia Report Layout and Labels Design

## Goal

Regenerate the 2026 Ethiopia country report with every six-year median-map figure arranged as two rows by three columns and with `Snnp` displayed as `Southern Nations, Nationalities, and Peoples’ Region` everywhere a report-facing region label is printed.

## Scope

The change covers the report figures produced by `Rcode/11_Report_Plot.R`, the previous-final comparison appendix produced by `Rcode/12_Previous_Final_Comparison.R`, and the assembled public PDF at `Results/Ethiopia/Ethiopia Report 2026.pdf`. It does not rename model identifiers, saved estimate rows, shapefile attributes, or spatial join keys. Percentage-decline figures contain one map each and therefore remain single-map figures.

## Configuration and Data Flow

Add a named `report_admin_name_map` object to `Info/Ethiopia_general_info.json`. The country-info loader already exposes every top-level JSON field to the report context, so the mapping becomes available without a second country-specific file.

A reusable supporting script will validate and apply exact display-name replacements. `Rcode/11_Report_Plot.R` will retain separate join and display columns: raw GeoRepo/GADM names continue to join estimates to geometry, while mapped display names feed legends, panel titles, and any visible map labels. `Rcode/12_Previous_Final_Comparison.R` will apply the same mapping when it builds canonical region labels for appendix facets.

## Map Layout

A reusable layout helper will define a six-panel map grid with two rows, three columns, and dimensions derived from the panel size. Both Admin-1 and Admin-2 selected-year NMR/U5MR maps will use the same layout. The selected years remain 2000, 2005, 2010, 2015, 2020, and the latest available projection year.

## Validation

Add focused regression tests before implementation. Tests will cover exact label replacement, preservation of unmapped labels, rejection of ambiguous mappings, Ethiopia’s configured alias, and shared use of the 2-by-3 layout in both selected-year map blocks. After the tests pass, rerun Ethiopia report plots, rebuild the core summary and previous-final appendix, extract PDF text to confirm the full label is present and `Snnp` is absent, then render and inspect the report pages containing maps and regional trend charts.

## Safety

The workspace contains substantial existing edits, including changes to report sources. Only the approved files and new focused helper/test files will be touched, and existing modifications will be preserved.
