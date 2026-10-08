# Admin-1 Previous-Final Comparison and National-Total Charts Design

## Scope

The previous-final appendix will compare Admin-1 only. Existing Admin-2 estimates,
figures, and core country-summary sections remain unchanged. Every country report
will gain one Admin-1 NMR overview and one Admin-1 U5MR overview containing the
official final national IGME series labelled `National total`.

## Previous-final region identity

Previous-round internal identifiers must not be treated as current identifiers.
The comparison will map prior Admin-1 rows to the current Admin-1 geography by
normalized display name unless an explicit country crosswalk exists. A crosswalk
is authoritative when present and maps the previous internal identifier and name
to the current internal identifier. Every prior region must map exactly once;
unmapped or ambiguous rows stop the appendix rather than producing mislabeled
figures.

Haiti will use
`Info/PreviousFinalRegionCrosswalks/Haiti_2023_to_2026.csv`. Its ten rows map the
2023 French department names to the current English department names and current
internal identifiers. In particular, 2023 `Ouest` maps to current `West`
(`admin1_1`).

## Crisis-adjusted current estimates

Current Admin-1 U5MR paths will continue through the shared crisis-result selector.
When `doCrisisAdj` is true, the comparison must load the `_crisis.rda` file and
must fail clearly if that required file is absent. NMR continues to use the normal
benchmarked result. This makes Haiti's 2010 adjustment appear in West rather than
under the region that happens to reuse the old internal identifier.

## National-total overview charts

Shared report-plot code will create two additional PDFs for every country:

- Admin-1 NMR trajectories plus the final official national NMR series.
- Admin-1 U5MR trajectories plus the final official national U5MR series.

Admin-1 trajectories will be thin, semi-transparent grey lines without individual
legend entries. The national series will be a thicker black line with the legend
label `National total`. This remains readable when a country has many Admin-1
regions; the existing paginated, coloured Admin-1 plots remain available for
region identification.

The national data come from `Data/IGME/igme2026_nmr.csv` and
`Data/IGME/igme2026_u5.csv`, already loaded by `Rcode/11_Report_Plot.R`. The new
figures use the selected final Admin-1 result object, including crisis-adjusted
U5MR when configured. `Rcode/11_CountrySummary.Rmd` will insert the two new charts
before the existing paginated Admin-1 spaghetti plots.

## Verification

Focused R tests will cover the Admin-1 default, explicit Haiti crosswalk,
unmapped-region failure, crisis-adjusted path selection, chart data validation,
the `National total` legend, deterministic filenames, and inclusion in the shared
country-summary template. The Haiti report will then be regenerated and the new
pages and previous-final appendix inspected visually.
