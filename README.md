# 星烬誓约

《星烬誓约》是一个使用 Godot 4.6 和 Forward+ 渲染器构建的战术角色扮演游戏项目。

## 环境

- Godot 4.6.3 stable
- 默认视口：1920 × 1080

## 克隆与启动

```powershell
git clone https://github.com/kusobaga233-tech/emblemlike-codex.git
cd emblemlike-codex
```

在 Godot 4.6.3 stable 中导入根目录 `project.godot`，等待资源首次导入后按 F5。默认使用 Forward+；需要支持 Vulkan 的显卡与驱动。无需 npm 或额外下载角色资产。

也可用本机 Godot 可执行文件运行：

```powershell
$Godot = 'C:\Tools\Godot_v4.6.3-stable_win64.exe' # 替换为实际路径
& $Godot --editor --path .
```

启动后：标题 → 开始 → 部署确认 → 战场。

## 当前可玩操作（2026-11-02）

- 选择我方角色 → 移动 → 点击高亮地块。移动不自动待机；右键点场地或任意阵营角色，撤销当前单位未提交移动；点击待机提交后不可撤销。
- 攻击：悬停查看预测、左键锁定敌军，再点击“确认攻击”；重复点击敌军不会直接出手。
- 治疗：艾利欧 → 治疗 → 点击相邻受伤友军 → 确认治疗，最多恢复8点且不超出缺失生命。
- 屏幕边缘平移镜头；滚轮每格围绕选中角色旋转30度；镜头随角色同步移动。
- 已提交的攻击/治疗不可回滚。旧存档不保存待撤销移动历史。

## 运行测试

在项目根目录中打开 PowerShell 并执行（`godot` 需已加入 PATH）：

```powershell
godot --headless --path . --script res://tests/run_all.gd
```

测试运行器会发现 `tests` 目录中的 `test_*.gd` 测试脚本，并在任一测试失败时以退出码 1 结束。

完整验证器接受本机 Godot 路径，避免依赖开发机盘符：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate_project.ps1 -GodotPath 'C:\Tools\Godot_v4.6.3-stable_win64.exe'
```

Windows 导出需要在 Godot 安装与版本匹配的 Export Templates：

```powershell
New-Item -ItemType Directory -Force build/windows | Out-Null
& $Godot --headless --path . --export-release 'Windows x64 Release' 'build/windows/StarEmberOath.exe'
```

## 仓库范围

包含主工程源码、运行资源、测试、开发工具与QA文档。`assets/test` 和概念图是测试/历史参考，导出预设会排除；不是本轮最终角色方案。`build/`、`.godot/`、Python缓存及本地密钥配置不上传。QA文档中的本地EXE/截图路径是开发机历史证据，不保证克隆后存在；截图可用 `tools/capture_*.gd` 重新生成。部分历史资产处理工具记录了开发机绝对路径，使用前需按本机位置调整，不影响运行游戏。

角色美术/动作方案仍待重选；第一章是开发中切片，不代表前三章成品或商业美术验收。完整测试结果与性能采样/人工通关验收分别记录，不混为一谈。

## 当前主线与整改计划

本目录是 Windows Godot 主工程；Phaser 浏览器原型不作为本工程三关验收依据。最终范围为主线前三关，先以第一章打通角色与场景生产流程。

- [产品整改路线](docs/superpowers/plans/2026-10-21-product-recovery-roadmap.md)
- [Aurelia 分层角色设计基准](docs/superpowers/specs/2026-10-21-aurelia-cutout-art-contract.md)

项目验证从本目录运行：`powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate_project.ps1`。历史通过结论须结合日期与源版本阅读；2.5D 技术样板尚未获得正式美术批准。
