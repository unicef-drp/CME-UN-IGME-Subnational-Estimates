# Liberia GeoRepo Boundary Exclusion Design

## Goal

Exclude GeoRepo's `Under National Administration` Admin-1 feature from Liberia's production boundary layers because it is not one of Liberia's 15 official counties. Keep the decision explicit, auditable, and reproducible in the country configuration.

## Country configuration

Add this optional field to `Info/Liberia_general_info.json`:

```json
"georepo_boundary_exclusions": [
  {
    "level": 1,
    "name": "Under National Administration",
    "reason": "GeoRepo feature is not an official Liberia county"
  }
]
```

Each exclusion identifies an administrative level, the exact normalized GeoRepo area name, and a human-readable reason. Countries without this field retain the current behavior.

## Boundary preparation behavior

`Rcode/2_download_georepo_shapefiles.R` will apply configured exclusions before writing normalized shapefiles, for both live GeoRepo downloads and materialization from an existing GeoRepo API pull.

For an Admin-1 exclusion, the preparation step will:

1. Match the configured name exactly against the normalized Admin-1 name.
2. Remove the matching Admin-1 feature.
3. Remove any Admin-2 features whose recorded Admin-1 parent name matches the excluded name, avoiding orphaned children.
4. Rebuild Admin-0 from the retained Admin-1 geometries.
5. Write the standard `georepo_<ISO3>_0`, `_1`, and `_2` layers.

The helper will stop with a clear error when a configured level is unsupported, the name or reason is empty, or a configured Admin-1 name is absent. This prevents a GeoRepo naming change from silently disabling the rule.

## Audit metadata

`georepo_download_metadata.json` will include the applied exclusion records and Admin-1/Admin-2 feature counts before and after exclusion. Liberia's expected Admin-1 count after filtering is 15.

## Tests

Extend `tests/test_georepo_shapefile_prep.R` first to cover:

- no configuration leaves layers unchanged;
- the Liberia rule removes the named Admin-1 feature;
- linked Admin-2 children are removed;
- unrelated Admin-1 and Admin-2 features remain;
- missing configured names fail clearly;
- metadata-ready counts report before and after values.

Extend `tests/test_info_config.R` to assert that Liberia records the approved exclusion with level, name, and reason.

After implementation, rerun the boundary-preparation tests and regenerate Liberia's normalized GeoRepo layers. Verify the written Admin-1 shapefile contains exactly the 15 official county names and does not contain `Under National Administration`.

## Scope

This change does not reassign the excluded geometry to Grand Cape Mount or Montserrado. It does not alter other countries unless they add their own exclusion records. Downstream Liberia products will use the regenerated 15-county layers when the pipeline resumes.
