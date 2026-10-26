# MoonBit toolchain

The executable was checked locally on 2026-10-27 after running the official
stable-channel `moon upgrade` command. The installation completed, and
`moon version --all` confirmed the resulting component versions below.

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

The official updater and [MoonBit download page](https://www.moonbitlang.com/download)
are the stable-channel provenance used for this check.
See the [MoonBit CLI command reference](https://docs.moonbitlang.com/en/stable/toolchain/moon/commands.html)
and [official release notes](https://www.moonbitlang.com/updates/2026/09/21/index).
No development or nightly toolchain was selected. Re-run the commands above
before release because the stable channel changes over time.
