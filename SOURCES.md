# Sources and third-party notices

## Project code and examples

The MoonArch graph model, selector, strict configuration decoder, policy
engine, witness search, exception and baseline handling, CLI, reports, tests,
and examples were created for this repository. The example graph and workspace
are synthetic and do not copy a third-party project's source.

The live graph adapter consumes the public output of `moon tree --package
--json`; MoonArch invokes the installed MoonBit CLI and does not vendor or
reimplement Moon's dependency discovery. See the [MoonBit CLI reference](https://docs.moonbitlang.com/en/stable/toolchain/moon/commands.html)
and the [official MoonBit download and toolchain page](https://www.moonbitlang.com/download).
The installed stable versions and local verification date are recorded in
[TOOLCHAIN.md](TOOLCHAIN.md).

## Runtime dependencies

| Dependency | Version | Use | License/source |
| --- | --- | --- | --- |
| `moonbitlang/async` | `0.22.5` | Native file I/O, subprocess, and standard streams | Apache-2.0; [Mooncakes package](https://mooncakes.io/docs/moonbitlang/async) |
| `moonbitlang/x` | `0.5.5` | Path and process exit helpers | Apache-2.0; [Mooncakes package](https://mooncakes.io/docs/moonbitlang/x) |
| MoonBit core | Bundled with the installed toolchain | JSON, collections, strings, and runtime APIs | Apache-2.0; [MoonBit core repository](https://github.com/moonbitlang/core) |

Dependency source is declared in `moon.mod`. The CI-only
[`hustcer/setup-moonbit`](https://github.com/hustcer/setup-moonbit) action is
licensed under MIT and is not linked into the application. GitHub's
[`actions/checkout`](https://github.com/actions/checkout) is also an MIT
licensed CI-only action. The workflow currently uses release `v7.0.0`.

The Apache-2.0 license text is available from the
[Apache Software Foundation](https://www.apache.org/licenses/LICENSE-2.0.txt).

## License

MoonArch is licensed under Apache-2.0. The complete license text is in
[LICENSE](LICENSE). No source files from the runtime dependencies are copied
into the tracked project tree; local dependency caches are ignored.
