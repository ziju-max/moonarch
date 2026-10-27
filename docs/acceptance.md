# MoonArch 本地自查记录

检查日期：2026-10-27。本文记录 `moonarch-clean` 的本地工程验收及用户授权后的 GitHub 发布核验。
推送前只核验当前 GitHub CLI 登录名为 `ziju-max`；未读取其他账号、凭据、令牌或全局 Git 身份。
这是工程自查记录，不是赛事审核结论。

## 结构与来源

- `moon.mod` 包命名空间为 `ziju-max/moonarch`，目标为 native；模块依赖固定为
  `moonbitlang/async@0.22.5` 与 `moonbitlang/x@0.5.5`。
- MoonBit 包划分为 graph、selector、config、moon_tree、witness、policy、exception、
  baseline、report、application、cli 和 `cmd/main`。图策略内核与文件/进程适配器分离。
- 根目录有 README、完整 Apache-2.0 LICENSE、SOURCES、工具链记录和本地验收记录。
  来源说明区分了原创实现、官方 `moon tree` 接口、运行依赖和 CI-only actions。
- `examples/offline` 是自包含的图与策略演示；`examples/workspace` 是可由
  `moon tree --package --json` 检查的真实多包 MoonBit 模块。
- `.gitignore` 排除了 `_build`、`.mooncakes`、临时输出、二进制产物和本地实施计划。未发现
  构建产物进入初始快照。
- 本地许可证文件为 Apache-2.0。示例为新写的合成数据；没有把旧 MoonArch 目录或其 Git 历史
  带入新目录。

## 功能覆盖

- 输入支持严格版本化离线 JSON，以及固定参数启动 `moon tree --package --json` 的工作区模式。
- 四类规则均由纯图策略核实现；支持 normal/test/wbtest、确定性最短证据路径、精确例外、
  过期/未使用例外通知、版本化 baseline 和 JSON/Markdown/terminal 报告。
- Markdown 与 terminal 报告会压平不可信字段中的控制字符；Markdown 还会对代码跨度动态选
  分隔符、转义普通文本中的 Markdown 标记，避免配置和图字段改变报告结构或触发终端控制序列。
- 应用层将配置、图、策略、baseline、进程与输出错误分别映射到 CLI 错误类别。受控场景已检查
  配置错误返回 2、图输入错误返回 3、策略新增发现返回 1、baseline 接受后返回 0。
- AI 参与了实现、测试、示例和文档；[开发说明](development-notes.md) 记录了这点和参赛者需要
  能独立解释的部分。

## 工具链与本地命令

`moon version --all` 于 2026-10-27 的实际输出：`moon 0.1.20261023`、
`moonc v0.10.17+d971670cd`、`moonrun 0.1.20261023`。同日运行官方稳定通道
`moon upgrade` 并完成安装；安装后复核版本仍为上述构建。详见 [TOOLCHAIN.md](../TOOLCHAIN.md)。

| 命令 | 结果 |
| --- | --- |
| `moon fmt --check` | 通过，退出码 0 |
| `moon check --target native --deny-warn` | 通过，退出码 0 |
| `moon info --target native` | 通过，退出码 0；复核生成的公开接口后隐藏了测试专用日期/注入函数 |
| `moon build --target native --deny-warn` | 通过，退出码 0；依赖 C 文件仍有 MSVC `EINVAL` 宏重定义 warning |
| `moon test --target native --deny-warn` | 65 项通过，0 失败；覆盖无匹配规则组的稳定警告、报告可见性、warning 不提升退出码，Moon tree 子进程无效 UTF-8 拒绝，selector 与图规范化拒绝点路径段，以及离线图错误保留非法包名和悬空边端点 |
| `scripts/verify-demo.ps1` | 通过，退出码 0；关闭 CLI 子进程 stdout 管道验证校验提示写入失败返回 3；含恶意换行字段名的配置错误保持单行；baseline 与 report 输出目录缺失时均返回 3 且不创建目录；包含策略/配置/图错误预期退出码、baseline 一致性、报告与 live 模式，并单独检查/构建 live 示例模块 |
| `scripts/audit-source.ps1` | 43 个 MoonBit 源文件；生产非空非行注释物理行 3,074；测试 1,476；总计 4,550，独立排除任意层级 `_build`/`.mooncakes` |
| 文本文件空白检查 | 通过，无行尾空白；`git diff --check` 退出码 0 |

源码审计计数是物理源文件行数，包含测试中的多行 fixture 字符串；它不是代码复杂度、独立逻辑语句数
或比赛方 LOC 工具的承诺值。

## Git 与远程状态

- 本地分支为 `main`，跟踪 `origin/main`；GitHub 仓库为公开的 [ziju-max/moonarch](https://github.com/ziju-max/moonarch)，远程默认分支为 `main`。最新推送提交为 `1a2caacd1d2a1d58fa29c2137449ab133efd96e2`，与远程 `main` 一致。
- 最新提交含 12 次真实提交，作者唯一为 `ziju-max <186978669+ziju-max@users.noreply.github.com>`。本次验收文档更新提交后将为 13 次；每次提交对应真实功能、测试或文档工作。
- 首次 GitHub Actions 运行 `40439877183` 在依赖解析阶段失败：干净 runner 尚未更新 MoonBit registry 索引。workflow 加入 `moon update` 后，运行 `40440161275` 于 36 秒完成并通过，覆盖格式、check/build/test、离线配置与报告、report 输出失败以及实时 workspace 示例。运行链接：[MoonArch CI](https://github.com/ziju-max/moonarch/actions/runs/40440161275)。
- 受限本机直接运行 `moon update` 时，registry 更新目录锁返回 access denied；这不影响本地缓存下的完整验收。GitHub runner 上同一 workflow 命令已实际通过。
- 远程检查只针对 `ziju-max/moonarch`；没有查询其他账号或仓库。申报书在仓库目录外，没有包含在推送内容中。

## 待处理与赛事边界

- 本地 MVP 和首次远程发布已完成，不代表赛事审核通过。继续远程操作仍须按用户明确指示执行。
- Mooncakes 发布状态尚未检查。是否为 2026 年 10 月黑客松硬性要求，应以该期官方说明为准，
  不套用其他赛事/往期 hackathon 规则。
- [2026 年 10 月黑客松官网](https://moonbitlang.github.io/Hackathon2026/) 与
  [正式章程](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd) 是赛事规则复核入口。
  本地自查不验证报名、申报书格式、发布/开源时点或验收截止口径。
- 申报书按此前要求单独保存，不放入本仓库。
