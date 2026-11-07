# 01: 应用骨架与菜单栏唤出空面板

Parent: `.scratch/file-drawer-v1/spec.md`

**What to build:** 一个从零到可双击运行的最小应用：一条构建命令产出 `.app`，启动后菜单栏出现常驻图标、Dock 中没有图标；从菜单栏打开一个位于屏幕顶部中央的空面板，Esc 或点击面板外可收起，菜单可退出。这张票同时证明「只有 Command Line Tools 也能构建并测试」这个全项目最大的未知。

**Blocked by:** 无（可立即开始）

**Status:** ready-for-agent

- [ ] 仅用 Command Line Tools 和一条构建命令即可产出可运行的 `.app`，不需要完整 Xcode 或 `xcodebuild`
- [ ] 启动后菜单栏有常驻图标，Dock 中无图标，也不出现在 Cmd+Tab 切换器里
- [ ] 菜单栏「打开抽屉」在屏幕顶部中央展开面板；「退出」干净退出
- [ ] 面板可用 Esc 与点击面板外收起
- [ ] `swift test` 可无头运行，至少有一条冒烟测试（核心库可导入、应用可链接）
- [ ] 核心库与 AppKit 外壳分属不同 target，外壳不承载业务规则
