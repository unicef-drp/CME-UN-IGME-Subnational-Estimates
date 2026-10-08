# Ethiopia WorldPop Alignment Comparison Design

## Goal

Produce the same 2000-2025 national and Admin-1 U1/U5 comparison delivered for Nigeria, now for Ethiopia. Compare old Global 1 for 2000-2020, Global 1 aligned to the Global 2 grid for 2000-2015, and Global 2 R2025A for 2015-2025.

## Reuse and scope

Generalize the existing Nigeria comparison workflow by country instead of copying its roughly 1,000 lines into an Ethiopia-only script. Nigeria remains the default for backward compatibility; `--country=Ethiopia` selects `Info/Ethiopia_general_info.json`, the GeoRepo ETH layers, Ethiopia raw-data folders, plot titles, and output filenames.

The comparison remains isolated from production mortality weights. It must not overwrite `adm1_weights_u1.rda` or `adm1_weights_u5.rda`.

## Raw sources

All persistent country TIFFs live under:

```text
C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents/UN IGME Subnational/Worldpop data
```

### Old Global 1, 2000-2020

Download the four required unconstrained age-sex rasters for each year to:

```text
Global1_2000_2020/Ethiopia/eth_{sex}_{age}_{year}_1km.tif
```

Use the official URL pattern:

```text
https://data.worldpop.org/GIS/AgeSex_structures/Global_2000_2020_1km/unconstrained/{year}/ETH/eth_{sex}_{age}_{year}_1km.tif
```

### Aligned Global 1, 2000-2015

Use the already downloaded annual WorldPop archives and extracted country TIFFs. The archive source is:

```text
https://data.worldpop.org/repo/prj/Global_2000_2020/CN_aligned_G2/agesex_structures/f_m_0_1/{year}.zip
```

If a country TIFF is not yet extracted, extract only the four Ethiopia entries from the corresponding local annual archive and save them under:

```text
Global1_2000_2020_aligned/Ethiopia_extracted/{year}/ETH/eth_{sex}_{age}_{year}_constrained_1km.tif
```

Do not download the aligned archives as part of this comparison run. Treat missing aligned archives or country TIFFs as a pre-staging error after checking the consolidated root.

### Global 2 R2025A, 2015-2025

Read the four already available country rasters per year from:

```text
Global2_2015_2030/Ethiopia/eth_{sex}_{age2}_{year}_CN_1km_R2025A_UA_v1.tif
```

Their official source URL pattern is:

```text
https://data.worldpop.org/GIS/AgeSex_structures/Global_2015_2030/R2025A/{year}/ETH/v1/1km_ua/constrained/eth_{sex}_{age2}_{year}_CN_1km_R2025A_UA_v1.tif
```

Here age `00` is under one and age `01` is ages one through four.

Only old Global 1 is downloaded by the comparison workflow. Aligned Global 1 and Global 2 are pre-staged inputs and are validated for existence and raster readability before aggregation.

## Population construction and geography

- U1 = female age 0 + male age 0.
- U5 = female ages 0 and 1 + male ages 0 and 1.
- Use `georepo_ETH_0` and `georepo_ETH_1` from `Data/shapeFiles/georepo_ETH_shp`.
- Match ADM1 labels through `Ethiopia_Amat_Names.rda`.
- Sum Admin-1 zonal counts for the reported national value and independently calculate the ADM0 total as a closure diagnostic.

## Outputs

Write six files under `Data/Countries/Ethiopia/worldpop/comparison`:

1. `ethiopia_worldpop_input_manifest_2000_2025.csv`
2. `ethiopia_worldpop_national_u1_u5_2000_2025.csv`
3. `ethiopia_worldpop_admin1_u1_u5_2000_2025.csv`
4. `ethiopia_worldpop_old_vs_aligned_difference_2000_2015.csv`
5. `ethiopia_worldpop_national_u1_u5_2000_2025.pdf`
6. `ethiopia_worldpop_admin1_u1_u5_2000_2025.pdf`

The national PDF contains separate U1 and U5 facets. The Admin-1 PDF uses free upper scales but every facet starts at zero, with 20 regions per page and separate pages for U1 and U5.

## Validation

- Exactly 192 inputs: 84 old, 64 aligned, and 44 Global 2.
- Every manifest path exists under the consolidated root and opens with `terra`.
- Exactly 96 national rows.
- Every source/year/indicator has one row for every configured Ethiopia Admin-1 polygon.
- Counts are finite and nonnegative with no duplicate keys.
- ADM0 versus summed ADM1 closure is within 0.25%.
- All PDF pages render with readable titles, axes, facets, legends, and zero Admin-1 baselines.
- Existing Nigeria tests and outputs remain valid.
