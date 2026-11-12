# 09: 取用（二）：多选、拖出与复制

Parent: `.scratch/file-drawer-v1/spec.md`

**What to build:** Command 点击增减选择、Shift 连续选择；把选中的文件拖到 Finder、聊天软件或浏览器上传区，单文件和多文件都可用；拖出始终是复制语义；Command + C 把选中文件放到剪贴板，可在目标应用里粘贴；多选时右键菜单只保留可批量执行的项。

**Blocked by:** 08 取用（一）：预览与右键菜单

**Status:** ready-for-agent

- [ ] Command 点击增减选择，Shift 连续选择，选择状态在列表中可见
- [ ] 单文件拖入 Finder、聊天软件、浏览器上传区均成功
- [ ] 多选一次拖出携带全部 URL，目标收到多个文件
- [ ] 拖到目录时为复制而非移动，原文件位置不变
- [ ] Command + C 后可在目标应用粘贴文件
- [ ] 多选时右键菜单只保留可批量执行的项
- [ ] 拖放进行中不自动收起，结束后恢复
- [ ] 单测覆盖选择模型与菜单收敛规则；拖放本身按人工验收清单验证

## Comments

### 2026-11-12 实现完成，等待人工验收

核心库：

- `ContextMenuPolicy.isEnabled(_:for: [DirectoryEntry])`：多选时只保留可批量执行的动作——打开／预览／复制路径需要单选，Finder 中显示与复制到剪贴板支持多选。
- `SelectionPolicy.rowsAfterContextClick(row:currentSelection:)`：右键点在已选行上保留多选，否则只选该行。

应用层：

- 列表开启多选；Command 点选增减、Shift 连选由 `NSTableView` 原生处理，选中高亮沿用系统样式。
- 拖出：`pasteboardWriterForRow` 提供文件 URL，多选时系统会为每个选中行写入；拖放会话固定返回 `.copy`，原文件不动。
- Command + C 在列表内复制全部选中文件的 URL；搜索框中按 Command+C 仍复制文本。
- 右键菜单按当前选择收敛；拖放、右键菜单与预览共用同一个交互保持入口，避免操作中自动收起。

自动验证：`swift test` 68/68（新增 3 条：多选收敛、空选择、右键保留选择）。

待人工确认：多选、拖到 Finder／聊天／上传区、复制语义、Command+C 粘贴、多选右键菜单、拖放期间不自动收起。

