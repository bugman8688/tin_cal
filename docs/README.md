# tin_cal 文档导航

| 版本号 | 变更主体 | 作者 | 变更日期 |
|--------|----------|------|----------|
| v1.0.0 | 初版：按 Diátaxis 四分类建立 docs 体系 | hanbing | 2026-11-26 |

> 本目录是项目设计文档的唯一入口。`AGENTS.md` 只保留「AI 不知道就会犯错」的硬约束与关键坑，详细内容都在这里。
> 单次需求的落地记录不在此处，见 `.trae/specs/`。

## 按任务找文档

| 我想 | 读 |
| --- | --- |
| 从零跑起来 / 授权提醒事项 | [getting-started.md](getting-started.md) |
| 加功能、改面板、改数据源、跑测试 | [development-guide.md](development-guide.md) |
| 打包、签名、安装、发版 | [deployment.md](deployment.md) |
| 看懂模块职责与数据流 | [architecture/overview.md](architecture/overview.md) |
| 知道某个设计为什么这么做 | [architecture/adr/](architecture/adr/) |
| 查设置项、Info.plist、脚本参数 | [reference/configuration.md](reference/configuration.md) |
| 查编码约定 | [reference/coding-standards.md](reference/coding-standards.md) |

## 分类约定

- **Tutorial**：`getting-started.md` —— 第一次跑通。
- **How-to**：`development-guide.md`、`deployment.md` —— 干活时的步骤。
- **Reference**：`reference/` —— 事实清单（配置项、编码约定），只写现状不带理由。
- **Explanation**：`architecture/` —— 架构总览与 ADR，讲「为什么」。

## 与其他文档的关系

| 文档 | 职责 |
| --- | --- |
| `AGENTS.md` | AI 快速上手：构建命令、硬约束、关键坑、文档索引 |
| `docs/`（本目录） | 项目整体设计思路的长期沉淀，随架构演进维护 |
| `.trae/specs/<change-id>/` | 单次需求的三件套（spec / tasks / checklist），由 talk2 技能在验收阶段同步 |
