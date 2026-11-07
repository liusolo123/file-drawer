# 01: 应用骨架与菜单栏唤出空面板

Parent: `.scratch/file-drawer-v1/spec.md`

**What to build:** 一个从零到可双击运行的最小应用：一条构建命令产出 `.app`，启动后菜单栏出现常驻图标、Dock 中没有图标；从菜单栏打开一个位于屏幕顶部中央的空面板，Esc 或点击面板外可收起，菜单可退出。这张票同时证明「只有 Command Line Tools 也能构建并测试」这个全项目最大的未知。

**Blocked by:** 无（可立即开始）

**Status:** done

- [x] 仅用 Command Line Tools 和一条构建命令即可产出可运行的 `.app`，不需要完整 Xcode 或 `xcodebuild`
- [x] 启动后菜单栏有常驻图标，Dock 中无图标，也不出现在 Cmd+Tab 切换器里（`activationPolicy` 实测为 accessory）
- [x] 菜单栏「打开抽屉」在屏幕顶部中央展开面板；「退出」干净退出
- [x] 面板可用 Esc 与点击面板外收起
- [x] `swift test` 可无头运行，至少有一条冒烟测试（核心库可导入、应用可链接）
- [x] 核心库与 AppKit 外壳分属不同 target，外壳不承载业务规则

## Comments

### 2026-11-07 实现完成并人工验收

已落地：

- `Package.swift`：`FileDrawerCore`（纯逻辑）＋ `FileDrawerApp`（可执行）＋ 测试 target。
- `scripts/build-app.sh`：`swift build` 后组装 `dist/文件抽屉.app`，Info.plist 内联 `LSUIElement`，ad-hoc 签名。
- 面板定位逻辑放在核心库（顶部居中 + 可见区域夹取），由 4 条 Swift Testing 用例覆盖。
- 菜单栏项：打开抽屉 / 退出；面板为无边框 `NSPanel`，可成为键盘窗口，失去焦点即收起，Esc 走 `cancelOperation`。

验证记录：

- `swift build` 通过，无警告（仅链接器提示 CLT 下两个不存在的搜索路径，无害）。
- `swift test`：4/4 通过。
- `plutil -p` 确认 `LSUIElement = true` 与 `CFBundleExecutable = FileDrawer`。
- `codesign -dv` 确认 ad-hoc 签名有效。
- 启动后 `NSRunningApplication.activationPolicy` 为 accessory（无 Dock 图标、不进 Cmd+Tab）。
- 用户已手动确认：菜单栏图标、面板位置、Esc 与点击外部收起、菜单退出均正常。
