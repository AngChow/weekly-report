---
name: weekly-report
description: 基于本周 git 提交记录自动生成个人周报，并在钉钉"周报"文件夹下新建一个以当前日期命名的钉钉文档保存。当用户要求"写周报"、"生成周报"、"本周工作总结"、"周报写到钉钉"时使用。流程：扫描本机所有 workspace 下的 git 提交 → 按项目分组并提炼为技术性话术 → 按周报模板格式编排 → 在钉钉"周报"文件夹下新建当日文档并写入内容。
---

# 周报生成 Skill

## 概述

从本机 git 仓库自动采集本周提交记录，按项目分组后用技术性话术改写，按固定模板编排为周报，最终在钉钉"周报"文件夹下新建一个以当前日期命名的钉钉文档并写入内容（每周一篇独立文档，便于后续管理）。

## 严格规则

### 话术改写规则（最基础）

将 git commit message 转化为周报条目时，**严禁**出现：
- 具体代码片段、变量名、函数名（如 `edit_online_doc_content`、`GPT_5.4_MINI_ENDPOINT`）
- 具体 commit hash
- 技术实现细节（如"在 xxx 函数里加了 try-catch"）

**必须**：
- 用"技术性话术"概括意图与效果（如"统一配置读取与兜底逻辑，解决因配置不一致导致的调用异常"）
- 每条 1–2 句，简洁但不空洞
- 涉及 bug 修复时，说"修复了 xxx 导致的 yyy 问题"，而非"把 flag 从 true 改成 false"
- 涉及新功能时，说"新增 xxx 能力"，点明业务价值
- 涉及重构时，说"清理/统一/简化 xxx，降低 yyy 风险"

### 合并规则

同一项目、同一方向的多个 commit 应合并为一条或多条有逻辑层次的条目，避免罗列每一笔 commit。

例：cinlyn 项目 5 条 tools 相关 fix → 合并为"在线文档编辑链路稳定性治理"一条，下设 3–4 个子要点。

### 数据源规则（最重要，决定输出下限）

**核心原则**：commit subject 不是唯一信息源，diff 才是事实。当 subject 信息不足时，**必须**回到代码变动反推意图。

1. **优先用 subject**：当 commit subject 已包含 type 前缀（feat/fix/refactor/docs 等）+ 具体描述时，subject 就是最权威的输入。
2. **subject 信息不足时必须看 diff**：满足以下任一条件即视为"信息不足"：
   - 脚本输出的 `QUALITY` 字段为 `LOW`（脚本已基于"垃圾词典 + 长度 + 字符特征"判定，并附 BODY/STAT/DIFF 摘要）
   - subject 命中如下黑名单（即便脚本判 HIGH 也要警惕）：`fix bug` / `update` / `wip` / `tmp` / `同步XX` / `更新XX` / `修复` / `调整` / `优化` / 长度 ≤ 6 字符的纯动词
   - subject 与脚本输出的 `FILES_CHANGED / INSERTIONS / DELETIONS` 严重不匹配（如 subject 写"修个小问题"但改了 500+ 行）
3. **看 diff 的优先顺序**（按成本由低到高）：
   1. 先看脚本已附带的 `[BODY]` / `[STAT]` / `[DIFF excerpt]` 块（LOW commit 自动有）
   2. 不够再 `git show --stat <hash>` 看改动文件分布
   3. 还不够再 `git show <hash>` 看具体 diff（限定关键文件，避免一次拉太多）
4. **严禁占位语**：以下表达**禁止**出现在周报条目里，因为它们等于没说：
   - "修复了若干 bug"
   - "日常优化"
   - "代码同步" / "文档同步"
   - "细节调整"
   - "杂项处理"
   如果只能写出这种话，说明 diff 还没看够，回去看。
5. **看 diff 后的产出标准**：要从 diff 里识别出"改了什么文件 / 改了什么行为 / 解决了什么问题"，至少给出"动作 + 对象 + 价值"三段式表述。例：
   - ❌ "修复 image_tools 的 bug"
   - ✅ "在图片生成返回结构中补齐 company_id 与上传 URL，便于下游链路定位资源归属"


## 周报模板

以下是钉钉文档中 0529 周报的格式，**新周报必须严格遵循此结构**：

```markdown
# **{MMDD}**

## **本周工作**

### **1、日常维护**

线上移动端问题值班

### **2、参与项目 or 技术事宜**

#### **{项目名} - {一句话概括}**
- {技术性话术条目1}
- {技术性话术条目2}
- ...

#### **{项目名}**
- {技术性话术条目1}
- ...

## **下周工作**

### **1、日常维护**

线上移动端问题值班

### **2、参与项目 or 技术事宜**

#### **{项目名}**
- {条目1}
- {条目2}
```

### 关键格式细节

1. 顶部日期标题 `# **MMDD**`（加粗，4 位月日）
2. 二级标题 `## **本周工作**` / `## **下周工作**`（加粗）
3. 三级标题 `### **1、日常维护**` / `### **2、参与项目 or 技术事宜**`（加粗、中文顿号）
4. 四级标题 `#### **项目名 - 概括**` 或 `#### **项目名**`（加粗）
5. 条目用 `- ` 开头（无序列表）
6. "日常维护"固定写"线上移动端问题值班"
7. "下周工作"部分由用户口述或留空占位，**不从 git commit 推断**
8. 同一项目多个方向可拆为多个四级标题（如"cinlyn - 链路稳定性治理"+"cinlyn - 权限体系治理"）

### 项目名映射

git 目录名 → 周报项目名：

| git 目录 | 周报项目名 |
|----------|-----------|
| `cinlyn` | cinlyn 项目 |
| `chatxrxs_v2` / `chatxrxs` | chatxrxs 项目 |
| `mobile_harmony` / `mobile-harmony` | HMOS App |
| `agent_batch_eval` | 自动化评测 |

如遇未列出的目录，根据 remote origin URL 和 commit 内容推断项目名。

## 执行流程

### Step 1: 扫描本周 git 提交

```bash
zsh {SKILL_DIR}/scripts/scan_week_commits.sh
```

脚本自动计算"本周一 ~ 今天"区间，扫描所有 workspace，按 remote URL 去重，输出结构化日志。

脚本输出特性（v3 起）：
- 头部包含 `REPORT_DATE=YYYYMMDD`（本周五；本周还没到周五则取今天），**直接用它做文件名**，不要再自己算
- 已按 (repo, commit hash) 去重，多个 author pattern 不会再重复匹配
- 每个仓库的 commit 按提交时间升序排列，方便按时间线梳理
- **每行 commit 的字段升级为 8 列**：`HASH|ISO_TIME|AUTHOR|SUBJECT|QUALITY|FILES_CHANGED|INSERTIONS|DELETIONS`
  - `QUALITY=LOW` 表示 subject 信息不足，脚本会自动在该 commit 下方附带 `[BODY]` / `[STAT]` / `[DIFF excerpt]` 块（diff 截断到 120 行内）。模型必须基于这些代码变动反推意图，不能直接照抄 subject。
  - `QUALITY=HIGH` 表示 subject 已足够清晰，可直接作为输入，但仍需结合 `FILES_CHANGED / INSERTIONS / DELETIONS` 估计改动量级，避免把"改了 500 行的大重构"写成"小修小补"。


如用户指定了具体日期，传参：
```bash
zsh {SKILL_DIR}/scripts/scan_week_commits.sh "2026-05-25 00:00:00" "2026-05-29 23:59:59"
```

### Step 2: 按项目分组 & 话术改写

1. 按项目分组 commit
2. 同方向 commit 合并
3. 每组提炼为 1 条四级标题 + 若干列表条目
4. 严格遵循话术改写规则

### Step 3: 编排周报 Markdown

按模板格式生成完整周报文本。

- 日期取本周五（或今天）的 MMDD
- "下周工作"部分：如用户未指定，填入占位提示（如"待确认"），**不要从本周 commit 推断**

### Step 4: 在钉钉"周报"文件夹下新建当日文档

**目标**：每次执行都在钉钉"周报"文件夹下**新建一份独立文档**，文件名为本周五（或今天）的日期，内容即新生成的周报 markdown。不再修改已有的"2026个人周报"汇总文档。

#### 4.1 命名规则

- 默认文件名：`周报-YYYYMMDD`（如 `周报-20260529`），**直接取 Step 1 脚本输出的 `REPORT_DATE`**（本周五；本周还没到周五则取今天；周六/周日则取刚过去的周五）。
- 若同名文档已存在，追加 `-v2` / `-v3` 后缀。**先**用 `dws doc list --folder <周报文件夹 nodeId> --format json` 确认是否重名。

#### 4.2 创建并写入文档（两步流程）

由于 `dws doc create` 只支持 `--markdown` 字面量参数（不支持 `--content-file`），且 shell 字面量传超长 markdown 容易踩到引号/换行转义坑，**推荐两步流程**：先创建空文档拿到 nodeId，再用 `dws doc update --content-file` 把 markdown 整体写入。

```bash
# 1. 创建空文档，记下返回的 nodeId
dws doc create \
  --name "周报-YYYYMMDD" \
  --folder 2Amq4vjg89gPLYnZcPxj4x3vV3kdP0wQ \
  --format json
# → 从输出中取 .nodeId

# 2. 用 update --mode overwrite 把 markdown 写入新文档
dws doc update \
  --node <NEW_DOC_ID> \
  --content-file /tmp/new_weekly_report.md \
  --mode overwrite \
  --format json --yes
```

> **注意**：`dws doc create` 的 `--markdown` 仅适合短文本（且需小心字面量 `\n` 反转义）。长文必须走 update + `--content-file`。
> `dws doc update` 的内容参数名为 `--content` / `--content-file`，**不是** `--markdown`。

#### 4.3 内容超长时

新周报一般 1000~3000 字符，远低于 10000 字符上限，**不需要分批**。
若极端情况下超 10000 字符：先 `update --mode overwrite` 写第一段，再 `update --mode append` 追加后续段（每段 < 10000）。

#### 4.4 输出给用户

执行完毕后，向用户报告：
- 新建的文档名称
- 文档 URL（从 `dws doc create` 返回的 `docUrl` 字段获取）
- 父文件夹位置（钉钉个人主页 → 周报）

### 钉钉文档信息

| 属性 | 值 |
|------|---|
| 父文件夹名 | 周报 |
| 父文件夹 nodeId | `2Amq4vjg89gPLYnZcPxj4x3vV3kdP0wQ` |
| workspaceId | `BpLmkZVrjrggX2gx`（个人主页） |
| 文档命名规则 | `周报-YYYYMMDD`（YYYYMMDD 取本周五或今天） |

> 历史汇总文档"2026个人周报"（nodeId `14lgGw3P8vveMkPwfvqvzpkY85daZ90D`）**不再写入**，仅作历史归档参考。

## 注意事项

- 下周工作内容**不从 commit 推断**，必须由用户提供或留占位
- 周报中不要出现 commit hash、变量名、函数名等代码级细节
- 同名仓库在多个 workspace 下只计一次（脚本已按 remote URL 去重）
- 扫描范围：~/workspace_codex、~/workspace、~/workspace_claude、~/workspace_harmony、~/workspace_ios、~/workspace_trae、~/DevEcoStudioProjects、~/PycharmProjects
