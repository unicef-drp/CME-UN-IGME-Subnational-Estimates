# DR Congo crisis adjustment: 77/23 design

> **Superseded 2026-09-01:** This historical design used the preliminary IRC
> report's 77/23 split. The active design is
> `2026-09-01-dr-congo-crisis-71-29-design.md`, based on the final peer-reviewed
> Lancet result of 71% East / 29% Rest.

## Purpose

Prepare subnational under-five crisis deaths for the Democratic Republic of the
Congo from `Data/Crisis_Adjustment/Crisis_Under5_deaths_2026.xlsx`. The output is
compatible with the existing crisis-adjustment application script but does not
apply the adjustment to final estimates.

## Geographic allocation

For every allocated year and age component:

- 77% of national crisis deaths are assigned to the historical East group.
- 23% are assigned to the remaining provinces.

The East group is defined as the present-day descendants of the five provinces
identified in the supporting conflict literature: Katanga, Maniema, North Kivu,
Orientale, and South Kivu. In the current 26-province geography these are:

- Bas-Uele, Haut-Uele, Ituri, and Tshopo (former Orientale)
- Haut-Katanga, Haut-Lomami, Lualaba, and Tanganyika (former Katanga)
- Maniema, Nord-Kivu, and Sud-Kivu

Admin-2 areas inherit the group of their parent Admin-1 province from the
current GeoRepo shapefile.

## Within-group allocation

The DHS 2007 regional U5MR estimates are not used as a second crisis weight.
They already inform the fitted non-crisis subnational mortality surface. Within
East and Rest, deaths are distributed using a non-crisis expected-death proxy:

`population for the age component * benchmarked non-crisis U5MR`

The age-zero WorldPop weight is used with national population age 0, and the
under-five WorldPop weight is used as the available proxy with national
population ages 1-4. The proxy is normalized separately by year, level, group,
and age component. It is an allocation basis, not an estimate of exact expected
deaths by age.

## Years

The source contains COD crisis deaths for 1996-2004. Current subnational
population weights and benchmarked fitted results begin in 2000, so the
production allocation covers 2000-2004. Source years 1996-1999 are validated
and recorded as excluded; the script does not silently extrapolate spatial
weights backward.

## Output and audit trail

The script writes `Data/Crisis_Adjustment/crisis_COD.rda` containing:

- `df_COD`: compatibility table with country, level, GeoRepo name, internal
  region, year, crisis deaths age 0, and crisis deaths ages 1-4.
- `cod_crisis_allocation_audit`: allocation group, model value, population
  proxies, allocation bases and shares, and national inputs.
- `cod_crisis_allocation_metadata`: source and model hashes, assumptions,
  included/excluded years, East crosswalk, and generation time.

The script must stop on missing or duplicate inputs, unmatched geography,
non-positive allocation bases, invalid weights, or failures of national-total
and 77/23 reconciliation.
