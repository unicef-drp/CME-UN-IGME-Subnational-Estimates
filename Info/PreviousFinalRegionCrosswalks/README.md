# Previous-final Admin-1 region crosswalks

These files map Admin-1 geography in the 2023 final-estimates workbook to the
current boundary lookup used for 2026 country reports. They are required when
previous-round internal identifiers or names cannot be matched safely to the
current geography by normalized display name.

Each CSV is a complete, one-to-one mapping for the country and contains:

- `admin_level`: currently `Admin1`;
- `previous_internal`: the identifier in the 2023 final workbook;
- `previous_name`: the region name in the 2023 final workbook;
- `current_internal`: the identifier in the current country Admin-name lookup;
- `current_name`: the corresponding name in the current country Admin-name
  lookup.

The comparison pipeline treats a country crosswalk as authoritative. Every
previous-final region must appear exactly once, every current target must exist,
and multiple previous regions may not map to one current region.

## Benin

`Benin_2023_to_2026.csv` records the complete 12-department mapping. The 2023
workbook spells `Atacora` as `Atakora` and `Couffo` as `Kouffo`. It also assigns
`admin1_6` to Donga and `admin1_7` to Kouffo, while the current lookup assigns
`admin1_6` to Couffo and `admin1_7` to Donga. The explicit crosswalk prevents
those reordered identifiers and spelling differences from being mistaken for
missing or different departments.

## Chad

`Chad_2023_to_2026.csv` maps all 23 previous-final regions to the current
Admin-1 lookup. The two aliases are `Barh el Ghazel` -> `Barh-El-Gazel` and
`Ville de N'Djamena` -> `N'Djamena`. N'Djamena moves from previous `admin1_22`
to current `admin1_17`; Ouaddai through Tibesti consequently use different
internal identifiers. Matching internal identifiers alone would mislabel them.

The mapping was checked against sheet 1 of
`Subnational_estimates_2023-08-15.xlsx` (TCD, Admin1, total-sex NMR/U5MR) and
the current lookup loaded by `load_country_admin_lookup()` on 2026-09-21.
This crosswalk is used only for report comparisons; it does not change model
estimates or boundary files. The failed run and its pre-refresh backup remain
under run `20260921_145008`; recovery rebuilds the failed summary using the
completed upstream outputs and records a separate recovery manifest.
