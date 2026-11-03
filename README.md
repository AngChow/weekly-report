# weekly-report

> 一个 [Codex](https://github.com/openai/codex) Skill，基于本机多个 workspace 的本周 git 提交记录生成个人技术周报，并写入钉钉「周报」文件夹。每周会创建一份独立文档，方便归档和回看。

## 安装

对 CodeX 说：

**帮我安装 [AngChow/weekly-report](https://github.com/AngChow/weekly-report) 这个 skill**

CodeX 会自动拉取仓库并识别 `SKILL.md` 中的执行流程。

## 快速开始

配置好钉钉文档目录（见 [配置](#配置)）后，对 CodeX 说：

- **帮我写本周周报**
- **生成本周工作总结，写入钉钉**
- **扫描 2026-05-25 到 2026-05-29 的提交，生成周报**

CodeX 会扫描 git 提交、按项目分组并改写成技术总结，然后创建 `周报-YYYYMMDD` 钉钉文档。

## 工作流程

1. 运行 `scripts/scan_week_commits.sh` 扫描本机常用 workspace 下的 git 提交。
2. 按 remote URL 去重仓库，按 commit hash 去重提交。
3. 对信息量不足的 commit 附带 body、stat 和 diff 摘要，帮助模型回到代码变动反推意图。
4. 按项目和方向合并提交，改写成不带代码细节的技术话术。
5. 按 `本周工作 / 下周工作` 模板编排周报。
6. 在钉钉「周报」文件夹下创建当日独立文档并写入内容。

## 前置条件

| 依赖 | 说明 |
|------|------|
| zsh / git / Python 3.8+ | 运行提交扫描脚本 |
| 本机 git 仓库 | 默认扫描 `~/workspace_codex`、`~/workspace`、`~/workspace_claude`、`~/workspace_harmony`、`~/workspace_ios`、`~/workspace_trae`、`~/DevEcoStudioProjects`、`~/PycharmProjects` |
| `dws` CLI | 创建和写入钉钉文档，需要已完成认证 |

## 配置

默认写入个人主页下的「周报」文件夹。如果目录不同，修改 `SKILL.md` 中的配置：

| 配置 | 说明 |
|------|------|
| 父文件夹 nodeId | 钉钉个人主页中的「周报」文件夹 |
| workspaceId | 钉钉个人主页 workspace |
| 文档命名 | `周报-YYYYMMDD`，日期取本周五；周六和周日取刚过去的周五 |

扫描根目录和作者名可直接修改 `scripts/scan_week_commits.sh`。作者默认匹配 `zhouang` 和 `周昂`。

## 输出质量

Skill 不会直接罗列 commit：

- 不输出 commit hash、函数名、变量名或具体代码片段。
- 不接受“修复若干 bug”“日常优化”“细节调整”这类空话。
- 同一项目、同一方向的多个提交会合并成有层次的业务/技术总结。
- commit subject 信息不足时，必须结合 body、stat、diff 反推真实改动和价值。

「下周工作」不从 git 提交推断，由用户口述；用户没有提供时会保留“待确认”占位。

## 文件结构

```
weekly-report/
├── SKILL.md                        # CodeX 运行时读取的完整指令
├── README.md                       # 本文档
├── agents/openai.yaml              # OpenAI 兼容接口显示信息
└── scripts/
    └── scan_week_commits.sh        # 扫描本周/指定时间段的 git 提交
```

## 完整文档

提交质量判定、话术改写规则、合并规则、钉钉文档上传流程和完整周报模板，见 [SKILL.md](SKILL.md)。

## License

MIT
