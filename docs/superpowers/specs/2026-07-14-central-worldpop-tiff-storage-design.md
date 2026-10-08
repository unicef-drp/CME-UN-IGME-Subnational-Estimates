# Central WorldPop TIFF Storage Design

## Goal

Store WorldPop TIFF files outside individual country working directories while retaining country-specific model products in the repository.

## Target layout

Raw WorldPop age/sex TIFFs will live at:

```text
C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents/UN IGME Subnational/Worldpop data/Global1_2000_2020/<Country>/
```

Derived U1, U5, and total-population TIFFs will live at:

```text
C:/Users/yanliu/OneDrive - UNICEF/Child Mortality - Documents/UN IGME Subnational/Worldpop data/Population/<Country>/
```

Only `.tif` files move. Administrative weight `.rda` files, comparison `.csv` files, and diagnostic `.pdf` files remain under `Data/Countries/<Country>/worldpop/`.

## Path architecture

`Rcode/_supporting_scripts/project_paths.R` will define one configurable WorldPop data root and focused helpers for the raw and derived country folders. The default root will resolve to the requested `Worldpop data` directory relative to the repository hierarchy. An environment variable will override the default for other machines or checkout locations.

All active code will use these helpers instead of constructing country-local TIFF directories. Weight-output paths will continue to use the country working directory explicitly, preventing TIFF storage from being confused with downstream model artifacts.

## Migration

A repository migration script will scan every directory below `Data/Countries`. For each country, it will move:

- `Data/Countries/<Country>/worldpop/*.tif` into `Global1_2000_2020/<Country>/`;
- `Data/Countries/<Country>/Population/*.tif` into `Population/<Country>/`.

The migration will create destination directories as needed. It will not overwrite a different destination file. If the same filename already exists with identical content, it will remove the redundant source after verifying hashes. Any differing collision will stop with an error naming both files.

The migration is idempotent: running it again after a successful migration performs no destructive work.

## Code consumers

`5_Admin_Weights_sf.R` will download raw age/sex TIFFs to the raw helper directory and write/read derived U1/U5 TIFFs through the population helper directory. Its `.rda`, `.csv`, and `.pdf` outputs remain country-local.

`7b_UR_thresholding_sf.R` will download and read total-population and derived U1/U5 TIFFs through the population helper directory.

Specific-task scripts that read the old country-local population TIFF directory will use the same shared helper. Archived scripts are historical references and will not be changed.

## Safety and verification

Tests will be added before implementation to establish the new path contract, ensure TIFF and weight paths remain separate, and validate collision-safe migration behavior. Verification will include:

- path-helper tests with an isolated temporary WorldPop root;
- source-contract tests for active scripts;
- migration tests using temporary country fixtures;
- the relevant existing R test suite;
- pre/post migration counts and SHA-256 hashes;
- confirmation that no TIFFs remain in country-local `worldpop` or `Population` directories.

The migration will not modify raster contents.
