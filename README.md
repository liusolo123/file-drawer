# 文件抽屉

在其他应用工作时，随时唤出常用文件夹，找到文件直接拖走。

菜单栏常驻，没有 Dock 图标；鼠标移到屏幕顶部中央（刘海处）或按 `⌃⌥F` 即可展开，鼠标移开自动收起。

## 下载

体验包在 [`release/文件抽屉-0.1.0.dmg`](release/文件抽屉-0.1.0.dmg)。

- 系统要求：macOS 14 及以上
- 芯片：Apple Silicon（M 系列）
- 当前为 ad-hoc 签名，首次打开需要右键 →「打开」，或到「系统设置 → 隐私与安全性」点「仍要打开」

安装：打开 DMG，把「文件抽屉.app」拖到 Applications。

## 功能

- 添加／排序／移除常用文件夹，移除不会动原目录
- 文件夹优先、按名称或修改时间排序，每个入口独立记忆
- 在常用文件夹内递归搜索，结果显示相对路径
- 空格预览、双击打开、右键菜单
- 多选后拖到聊天软件、浏览器上传区或 Finder（复制语义）
- 悬停唤出、快捷键唤出、自动收起、焦点交还
- 显示隐藏文件、登录启动、自定义快捷键、面板尺寸记忆
- 目录变化自动刷新；失效入口可重试／重新选择／移除

## 默认快捷键

`Control + Option + F`，可在菜单栏「设置…」中修改或禁用。

## 从源码构建

需要 Command Line Tools（Swift 6+）：

```bash
./scripts/build-app.sh      # 产出 dist/文件抽屉.app
./scripts/package-dmg.sh    # 产出 dist/文件抽屉-0.1.0.dmg
./scripts/test.sh           # 运行测试
```

图标：`./scripts/generate-icon.sh`

## 测试

```bash
./scripts/test.sh
```

当前 83 条测试全部通过。

## 已知限制

- 多屏行为尚未完整验证
- 只有 Apple Silicon 版本
- 登录启动需要应用位于 Applications 下
- 没有自动更新

## 卸载

退出应用，删除「文件抽屉.app」。
如需清除设置，删除 `~/Library/Application Support/com.liusolo.filedrawer`。

## 目录

```
Sources/FileDrawerCore   领域逻辑与测试缝
Sources/FileDrawerApp    AppKit 外壳
Tests/                   单元测试
scripts/                 构建、测试、图标、打包
video/                   介绍片工程
```

## 介绍片

制作计划与工程在 [`video/`](video/PLAN.md)。
