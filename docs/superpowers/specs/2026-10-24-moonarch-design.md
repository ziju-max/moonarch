# MoonArch 全新实现设计规格

- 日期：2026-10-24
- 状态：设计已获用户确认，等待规格文件复核
- 目标版本：0.1.0 MVP

## 1. 目标与背景

MoonArch 是一个面向 MoonBit 多包工作区的架构边界检查 CLI。它读取 Moon 官方命令 `moon tree --package --json` 生成的包依赖图，或读取兼容的离线图 JSON；根据用户维护的严格 JSON 策略文件检查包依赖，并给出确定性违规路径、机器可读报告和适合 CI 使用的退出码。

本次实现从空目录开始。旧目录仅作为产品需求背景参考；不复制其源码、测试、构建产物、生成文件或 Git 历史，不从旧提交 cherry-pick。新项目所有来源和依赖均单独记录。

官网当前可检索说明允许 AI 参与代码、接口、测试和文档，但要求参赛者掌握项目目标、技术路径和质量并能解释选择。正式章程的飞书页面在本次查阅时不可访问，因此以官网为当前可读依据，正式章程细节提交前仍须复核。新实现的 AI 参与情况应如实披露，参赛者需能独立讲清架构、规则语义和验收结果。

## 2. 成功标准

0.1.0 MVP 应满足：

1. 支持实时工作区输入和离线 Moon tree 图 JSON 输入，两者汇入同一个规范化图模型。
2. 支持 `deny`、`allow_only`、`layer_direction`、`max_layer_jump` 四类策略规则。
3. 区分 normal、test、wbtest 依赖上下文；传递违规输出稳定的最短证据路径。
4. 支持严格配置校验、精确临时例外和版本化 baseline。
5. 生成 terminal、JSON、Markdown 三种确定性报告，提供文档化退出码。
6. 包含完整错误处理、核心和集成测试、可复现演示、清晰 README、OSI 认可的许可证，以及来源和第三方许可说明。
7. 本地 CI 定义覆盖格式检查、check、build、test 和演示验证；只做本地静态/命令级验证，不访问远程仓库。
8. 使用实施时最新官方稳定版 MoonBit 工具链，并记录实际版本和核验日期。
9. 目标为不少于 4,000 行有效手写 MoonBit 代码和不少于 11 个有意义的本地提交；行数、提交数均不得通过空提交、重复包装或无关功能凑数。若质量与数字目标冲突，保留质量并如实记录差异。

## 3. 非目标

0.1.0 不实现 MoonBit 源码解析器，不自行复刻 `moon.mod` / `moon.pkg` 工作区解析，不编辑源代码、配置或依赖；不提供 Web UI、编辑器插件、守护进程、GitHub API、推送、PR 或远程 CI 集成；不检查依赖许可证/版本健康度，不实现可编程插件系统或通用策略 DSL。

## 4. 架构选择

采用“纯图策略内核 + 双输入适配器”。工作区适配器以固定参数启动 `moon tree --package --json`；离线适配器读取用户提供的 JSON。两种输入均转换为同一规范图，然后由纯配置、选择器和策略模块处理。CLI/I/O 层不参与规则判断。

不选择将进程、规则和报告揉进 CLI 的单体实现，因为它会使核心规则难以隔离测试；不自行解析 MoonBit 源码或 manifest，因为会重复官方工具链的包发现和条件导入语义，带来兼容性风险。

## 5. 组件与依赖方向

- `graph`：包节点、带上下文边、索引、规范化、图输入不变量。
- `moon_tree`：Moon tree JSON schema 解码、兼容性检查和规范图转换。
- `config`：版本化 JSON 解码、字段/枚举/跨引用校验。
- `selector`：`*` 单段与 `**` 零段或多段 glob、scope 与 group 展开。
- `policy`：四类规则及其纯图求值。
- `witness`：分上下文的最短路径搜索和确定性 tie-break。
- `exception`：精确例外匹配、日期比较和未使用例外诊断。
- `baseline`：版本化指纹、载入、分类和原子创建。
- `diagnostic`：错误、违规、warning 和输入/运行摘要的共享模型。
- `report`：terminal、JSON、Markdown 渲染。
- `application`：输入、配置、策略、抑制与结果组装的用例层。
- `cli`：参数、进程/文件/标准流适配、输出和退出码映射。
- `cmd/main`：薄入口。

依赖方向从 CLI/application 指向纯策略模块；`graph`、`selector`、`policy`、`witness` 不依赖文件系统、进程、终端或 CLI。MoonBit 是生产逻辑、CLI、测试和报告的主要实现语言；少量脚本只承担本地审计/演示编排。

## 6. 图与上下文语义

每个图节点以完整 MoonBit 包名为 ID。每条有向边保存来源、目标和精确导入上下文：`normal`、`test` 或 `wbtest`。重复完全相同的边规范化时折叠；空包名、悬空引用和不支持的边类型是输入错误。scope 外部节点不得成为内部规则目标。

上下文可达性定义如下：

- normal 路径只能包含 normal 边。
- test 路径可包含 normal/test 边，且至少包含一条 test 边。
- wbtest 路径可包含 normal/wbtest 边，且至少包含一条 wbtest 边。

传递路径使用广度优先搜索。等长路径按目标包名、再按边类型排序，保证同一输入产生相同 witness 和报告。配置 scope 命中且未排除的包才应用内部架构规则；外部依赖不作为内部 group/rule 目标。

## 7. 配置与规则

默认配置文件名为 `moonarch.json`，顶层含 `schema_version: 1`。配置使用严格 JSON：未知字段、重复 ID、无效 glob、非法值、缺失的引用对象和不一致层级均拒绝并给出 JSON 字段路径。`scope.include`、groups、rules 必填；`scope.exclude`、exceptions 可省略为空；layers 在不使用分层规则时可省略。

scope 使用包名 glob。普通 groups 允许重叠；参与 layer 分组的包必须恰好命中一个 layer。被规则引用但无包命中的 group 产生 warning。层级号从 0 开始连续递增，数值越大表示层级越高。

- `deny`：禁止 from group 依赖 to group；支持 direct 与 transitive。
- `allow_only`：限制 from group 的直接依赖目标必须属于允许 group。
- `layer_direction`：高层可依赖同层或低层，低层依赖高层为违规；检查直接边。
- `max_layer_jump`：只检查合法方向上的直接边，限制 source 与 target 层级差；反向依赖由 `layer_direction` 报告，避免重复。

规则须显式声明非空 contexts。对多个 selector 同时命中的同一来源/目标/规则/上下文进行去重。

## 8. 例外与 baseline

例外必须精确指定 rule ID、source 包、target 包和非空上下文，并提供非空理由、负责人文本和 ISO 日期。例外不接受 glob。匹配的有效例外标记为 suppressed；过期例外不压制违规并产生失败级诊断；未使用例外产生 warning。日期由调用方显式传入；CLI 使用 UTC 日历日，避免机器本地时区导致报告不确定。

Baseline 是独立版本化 JSON。违规指纹由 rule ID、source、target、context 构成，不依赖路径和文案。当前 findings 分类为 new、existing、resolved：new 导致违规退出码，existing 展示但接受，resolved 产生 warning。Baseline 不得压制配置、输入、I/O、进程或内部错误，也不得压制过期例外。创建 baseline 时只写入当前未抑制违规；先写同目录临时文件，再原子替换目标，验证失败不得覆盖旧文件。

## 9. CLI、报告与错误处理

命令：

```text
moonarch check [--config FILE] [--graph FILE | --workspace DIR]
               [--format terminal|json|markdown] [--color auto|always|never]
               [--output FILE] [--moon EXECUTABLE]
moonarch config validate [--config FILE]
moonarch baseline create --output FILE [check options]
```

`--graph` 与 `--workspace` 互斥。实时模式用固定 argv `tree --package --json` 启动指定 moon 可执行文件，不经过 shell；子进程非零时不得解析其 stdout 为图。输出文件失败时不得报告为通过。机器报告不混入日志或 ANSI 控制符；运行日志写 stderr。配置路径默认相对当前工作目录；配置中的 baseline 路径相对配置文件所在目录。

所有渲染器消费同一个确定性诊断模型，按严重度、规则、source、target、context 稳定排序。terminal 支持颜色策略但颜色不可承载唯一信息；JSON/Markdown 包含 schema 版本、输入/日期摘要、计数和诊断详情。

退出码：0 无新增/未压制违规；1 有新增违规、未压制违规或过期例外；2 CLI 参数/配置错误；3 图、进程或文件错误；4 非预期内部错误。运行失败不得被误报成策略通过。

## 10. 测试与验收

测试覆盖：schema/未知字段/引用、glob 边界、图规范化和错误边、四规则边界、normal/test/wbtest 隔离、环路/菱形和多条等长最短路径、层级冲突、例外匹配/过期/未使用、baseline 新增/已知/解决分类、指纹稳定性、日期、三种报告 golden、CLI 参数/退出码/输出写入失败、Moon 子进程失败/非零/stderr 长度上限/无效 JSON。

使用离线 fixture 执行大多数测试，不依赖网络或系统安装 Moon；用受控假 moon 命令覆盖进程分支。提供可复制 demo，演示配置验证、零违规、一个新增违规及 baseline 接受路径，并记录每条命令的预期退出码。验收脚本在临时副本工作，不修改仓库内示例。

最终本地验收记录真实命令与结果：格式检查、`moon check`、`moon build`、`moon test`、示例成功/预期失败、三种输出、source LOC 审计、Git 提交数、CI YAML/命令核验和 `git diff --check`。尚未实际执行的命令不得写成通过；未验证的平台或远程行为明确列为限制。

## 11. 项目交付、来源与提交历史

使用 OSI 认可的 Apache-2.0 许可证。README 说明用途、安装、完整可复制配置、CLI、退出码、demo 和限制。`SOURCES.md` 记录原创范围、官方 Moon tree 接口、官方规则/文档链接、每个运行/开发依赖的版本与许可证、示例/fixture 来源；未直接复用其他源代码时明确说明。另附简短开发说明，记录 AI 在实现、测试和文档中的参与范围，以及人类参赛者需要掌握的架构和演示要点。

新仓库仅包含本次从空目录产生的历史；旧仓库的作者和提交元数据不迁移。首个提交之前必须显式设置新仓库的提交作者身份，不检查或继承机器全局旧 Git 身份；正式提交作者值待用户提供或在本地界面由用户确认。提交不少于 11 次，每次对应真实、可审阅的功能或质量里程碑；不做空提交、不伪造历史。当前阶段不访问、创建、配置或推送任何远程仓库。

## 12. 实施阶段建议

1. 新仓库骨架、许可证、工具链核验、图与错误模型。
2. Moon tree/离线双输入适配器和 selector/config 校验。
3. 四类策略与 witness 路径。
4. 例外、baseline 和确定性诊断。
5. 三种报告、CLI、进程与文件错误处理。
6. 集成演示、README、来源说明、本地 CI 和完整验收记录。

每个阶段先写或更新相应测试，再实现；模块间先用人工构造的小图验证纯逻辑，再接入真实 moon tree 数据。

## 13. 复核清单

- 旧实现与旧 Git 历史不进入新仓库。
- 两种图输入共享相同规范图和策略结果。
- 策略错误与运行/配置错误区分清楚，退出码稳定。
- baseline 和例外不能隐藏真实输入错误。
- 所有不确定的外部赛事口径与未实际执行的本地验收项均明确标注，不伪称确认或通过。
- 代码量、提交数以实质内容为依据，AI 参与如实说明。
