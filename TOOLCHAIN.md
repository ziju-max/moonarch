# MoonBit toolchain

The executable was checked locally on 2026-10-26 after running the official
`moon upgrade` command. The updater reported that it was up to date.

| Component | Installed stable version | Build date |
| --- | --- | --- |
| `moon` | `0.1.20261023` | 2026-10-23 |
| `moonc` | `v0.10.17+d971670cd` | 2026-10-23 |
| `moonrun` | `0.1.20261023` | 2026-10-23 |

Verification commands:

```powershell
moon --version
moonc -v
moonrun --version
moon upgrade
```

The official updater is the stable-channel provenance used for this check.
See the [MoonBit CLI command reference](https://docs.moonbitlang.com/en/stable/toolchain/moon/commands.html)
and [official release notes](https://www.moonbitlang.com/updates/2026/09/21/index).
No development or nightly toolchain was selected. Re-run the commands above
before release because the stable channel changes over time.
