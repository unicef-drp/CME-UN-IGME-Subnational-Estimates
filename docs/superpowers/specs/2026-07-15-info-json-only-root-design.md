# Info JSON-Only Root Design

## Goal

Keep checked-in country JSON files as the only files directly under `Info` and
move all legacy country-info generators and serialized country-info artifacts
to the existing `Info/Archive` directory.

## Scope

The cleanup covers:

- all 37 top-level `Info/*_create_info.R` scripts;
- the top-level Ethiopia and Nigeria `*_general_info.Rdata` files;
- active README guidance that still directs users to `_create_info.R`; and
- a focused regression test for the `Info` directory layout.

The 37 top-level `*_general_info.json` files remain in place and unchanged.
Archived files retain their original names and contents, including existing
uncommitted edits in the Laos, Madagascar, and Nigeria generator scripts.

## Directory Layout

After the cleanup, `Info` has this contract:

```text
Info/
├── Archive/
│   ├── <Country>_create_info.R
│   └── <Country>_general_info.Rdata
└── <Country>_general_info.json
```

The root may contain the `Archive` directory, but every root-level file must
have a `.json` extension. No generator or Rdata file will be deleted.

## Active Behavior

The active pipeline continues to resolve country configuration only from
`Info/<Country>_general_info.json`. Moving legacy artifacts does not add an
archive fallback and does not change the JSON loader.

`README.md` will tell users to document special boundary handling directly in
the country JSON configuration. Historical generator scripts remain available
under `Info/Archive` for reference only.

## Error Prevention and Testing

Add `tests/test_info_directory_json_only.R` before moving files. The test will
fail while non-JSON files remain at the `Info` root, then verify that:

- every root-level file is JSON;
- exactly 37 country JSON files remain at the root;
- all 37 generator scripts exist in `Info/Archive`;
- the Ethiopia and Nigeria Rdata artifacts exist in `Info/Archive`; and
- no root-level generator or Rdata files remain.

After the move, run the new layout test, existing JSON configuration tests, the
country-info loader test, the active-pipeline JSON contract test, and a scoped
diff check.

## Working-Tree Safety

Before moving files, resolve and verify that the source and destination paths
are both inside the repository's `Info` directory. Use same-filesystem moves so
file contents and timestamps are preserved. Do not stage or commit the cleanup
implementation unless explicitly requested.
