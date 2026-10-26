# MoonArch 本地自查记录

检查日期：2026-10-26。范围为当前 `moonarch-clean` 本地目录和本机工具链；未访问 GitHub
仓库、远程分支或远程 CI。经用户授权，只通过当前 GitHub CLI 身份核验 `ziju-max` 并读取生成
noreply 地址所需的 ID 与创建日期；未读取邮箱列表、令牌或全局 Git 身份。这是工程自查记录，
不是赛事审核结论。

## 结构与来源

- `moon.mod` 包命名空间为 `ziju-max/moonarch`，目标为 native；模块依赖固定为
  `moonbitlang/async@0.22.5` 与 `moonbitlang/x@0.5.5`。
- MoonBit 包划分为 graph、selector、config、moon_tree、witness、policy、exception、
  baseline、report、application、cli 和 `cmd/main`。图策略内核与文件/进程适配器分离。
- 根目录有 README、完整 Apache-2.0 LICENSE、SOURCES、工具链记录和本地验收记录。
  来源说明区分了原创实现、官方 `moon tree` 接口、运行依赖和 CI-only actions。
- `examples/offline` 是自包含的图与策略演示；`examples/workspace` 是可由
  `moon tree --package --json` 检查的真实多包 MoonBit 模块。
- `.gitignore` 排除了 `_build`、`.mooncakes`、临时输出和二进制产物。当前工作树状态只显示
  预期的项目源文件/文档待加入本地 Git；未发现构建产物进入项目目录。
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

`moon version --all` 于 2026-10-26 的实际输出：`moon 0.1.20261023`、
`moonc v0.10.17+d971670cd`、`moonrun 0.1.20261023`。此前同日运行官方
`moon upgrade`，结果为 stable 已是最新。详见 [TOOLCHAIN.md](../TOOLCHAIN.md)。

| 命令 | 结果 |
| --- | --- |
| `moon fmt --check` | 通过，退出码 0 |
| `moon check --target native --deny-warn` | 通过，退出码 0 |
| `moon info --target native` | 通过，退出码 0；复核生成的公开接口后隐藏了测试专用日期/注入函数 |
| `moon build --target native --deny-warn` | 通过，退出码 0；依赖 C 文件仍有 MSVC `EINVAL` 宏重定义 warning |
| `moon test --target native --deny-warn` | 55 项通过，0 失败 |
| `scripts/verify-demo.ps1` | 通过，退出码 0；包含新发现/配置错误/图错误的预期退出码、baseline 一致性、报告与 live 模式，并单独检查/构建 live 示例模块 |
| `scripts/audit-source.ps1` | 43 个 MoonBit 源文件；生产非空非行注释物理行 2,930；测试 1,266；总计 4,196，独立排除任意层级 `_build`/`.mooncakes` |
| 文本文件空白检查 | 通过，无行尾空白；`git diff --check` 退出码 0（本仓库尚无提交，项目文件仍为未跟踪状态） |

源码审计计数是物理源文件行数，包含测试中的多行 fixture 字符串；它不是代码复杂度、独立逻辑语句数
或比赛方 LOC 工具的承诺值。

## Git 与远程状态

- 本地分支为 `main`；当前没有提交（0 commits），没有配置 remote。
- 远程默认分支因此无法核实；本次没有读取远程仓库内容、提交历史、凭据或令牌。
- 通过当前 CLI 身份核验得到了 `ziju-max` 的 ID 型 noreply 邮箱；仓库级 Git 作者配置尚未写入，
  仍无提交。没有伪造历史，也没有读取全局 Git 身份。
- workflow 文件已加入 `.github/workflows/ci.yml` 并按本地命令审阅；GitHub 托管 runner 上的 CI 尚未执行。

## 待处理与赛事边界

- 这是本地 MVP 自查，不代表可立即完成远程提交或赛事验收。若要形成真实提交历史，仍需用户明确本地 Git
  提交作者名与邮箱；远程操作必须继续等待用户明确指示。
- Mooncakes 发布状态与远程默认分支均未检查。是否为 2026 年 10 月黑客松硬性要求，应以该期官方说明为准，
  不套用其他赛事/往期 hackathon 规则。
- [2026 年 10 月黑客松官网](https://moonbitlang.github.io/Hackathon2026/) 与
  [正式章程](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd) 是赛事规则复核入口。
  本地自查不验证报名、申报书格式、发布/开源时点或验收截止口径。
- 申报书按此前要求单独保存，不放入本仓库。
