# MoonArch

MoonArch checks package dependency boundaries in MoonBit workspaces. It uses
the official `moon tree --package --json` output for live workspaces or a
versioned offline graph fixture. Both inputs enter the same deterministic graph
and policy engine.

## Requirements

- The latest stable MoonBit CLI. This implementation was checked with the
  versions recorded in [TOOLCHAIN.md](TOOLCHAIN.md).
- A native C toolchain for the `moonbitlang/async` dependency when building the
  native executable. On Windows, use a working MSVC Build Tools installation.
- Internet access only when Moon resolves packages that are not cached locally.

The project uses `moonbitlang/async` 0.22.5 and `moonbitlang/x` 0.5.5. See
[SOURCES.md](SOURCES.md) for upstream and license details.

## Build and test

```sh
moon fmt --check
moon check --target native --deny-warn
moon build --target native --deny-warn
moon test --target native --deny-warn
```

`moon run cmd/main --target native -- --help` prints the CLI usage. When using
the native executable directly, pass the same commands and flags after it.

## Quick start: offline graph

The checked-in example contains all four rule types, one exact temporary
exception, and a baseline of known findings.

```sh
moon run cmd/main --target native -- config validate --config examples/offline/moonarch.json
moon run cmd/main --target native -- check --config examples/offline/moonarch.json --graph examples/offline/graph.json
```

The second command reports new findings and exits with code `1` by design.
Create a baseline and accept the current findings:

```sh
moon run cmd/main --target native -- baseline create --output examples/offline/baseline.json --config examples/offline/moonarch.json --graph examples/offline/graph.json
moon run cmd/main --target native -- check --config examples/offline/moonarch-baselined.json --graph examples/offline/graph.json --format json
```

The `examples/offline` baseline is checked in so the second command is
reproducible without first writing a file. Baseline paths in configuration are
resolved relative to that configuration file.

## Quick start: live workspace

This small MoonBit module has four packages with real imports. MoonArch starts
`moon tree --package --json` with a fixed argument list and reads its output:

```sh
moon run cmd/main --target native -- check --config examples/workspace/moonarch.json --workspace examples/workspace --format markdown
```

## Configuration and graph formats

Configuration is strict JSON with `schema_version: 1`. Unknown fields, repeated
JSON keys, malformed selectors, invalid references, ambiguous layer coverage,
and invalid exception dates are errors. The complete example configuration is
in `examples/offline/moonarch.json`.

Offline graphs use this schema:

```json
{
  "schema_version": 1,
  "packages": ["demo/ui", "demo/service"],
  "edges": [
    {"source": "demo/ui", "target": "demo/service", "kind": "normal"}
  ]
}
```

`kind` is `normal`, `test`, or `wbtest`. Every edge endpoint must appear in
`packages`; package IDs must be relative slash-separated paths without empty,
`.` or `..` segments. Duplicate edges are normalized away. Live graph
compatibility currently targets the schema version returned by
`moon tree --package --json` and rejects unknown edge kinds or unsupported
versions.

## Rules

- `deny` blocks direct or transitive dependencies between selected groups.
- `allow_only` restricts a source group's direct dependencies to selected
  allowed groups.
- `layer_direction` rejects a dependency from a lower numbered layer to a
  higher numbered layer. Higher layers may depend on the same or lower layers.
- `max_layer_jump` limits the downward layer distance on correctly directed
  edges. Reverse-direction violations are reported by `layer_direction`.
- `normal` considers source edges only. `test` and `wbtest` can traverse source
  edges plus their own test-edge kind and require a path to contain that kind.

Exceptions match an exact rule, source, target, and context. A valid exception
suppresses only that finding; expired exceptions remain failures, and unused
exceptions appear as notices. Baselines compare rule/source/target/context
fingerprints, so witness-path or message changes do not create new entries.
Groups referenced by rules but matching no in-scope package produce stable,
non-failing policy warnings in check reports. Groups with no rule reference are
left alone.

## Reports and exit codes

`--format` accepts `terminal`, `json`, or `markdown`; `--output FILE` writes a
report to a file. JSON and Markdown never include ANSI color codes. `--color
always` forces color for terminal output; `never` disables it. `auto` currently
uses plain output because this CLI does not yet detect whether stdout is a TTY.
If a success message cannot be written to stdout, the CLI returns output-error
exit code `3` instead of reporting success.
CLI errors, terminal reports, and Markdown reports flatten control characters
in untrusted input values.
Markdown reports also escape inline markup and choose code-span delimiters
based on their content, so package names and exception text cannot create extra
report blocks or terminal escape effects.

| Code | Meaning |
| --- | --- |
| `0` | No new findings and no expired exception |
| `1` | New findings or expired exception |
| `2` | CLI or configuration error |
| `3` | Graph, subprocess, baseline input, or file output error |
| `4` | Unexpected error |

Existing baseline findings and valid suppressed findings do not fail a check.
Resolved baseline fingerprints are included in the report but do not change the
exit code. Policy warnings also remain informational and do not change it.

## Local verification

On Windows, `./scripts/verify-demo.ps1` runs the formatting, check, build, test,
offline demo, baseline, report, and live-workspace commands. CI uses the same
core Moon commands; its workflow is in `.github/workflows/ci.yml`.

## Scope and limitations

MoonArch analyzes package dependency graphs; it does not parse MoonBit source or
rewrite manifests. It does not check third-party dependency health, licenses,
or version policy. `moon tree` schema changes require an adapter update.

## License

MoonArch is distributed under the Apache License 2.0; see [LICENSE](LICENSE).
