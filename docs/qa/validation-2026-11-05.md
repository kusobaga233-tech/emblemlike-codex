# 2026-11-05 复跑验证记录

## 对象

- 提交：`2c98a02fffcf92fe3e08a53de38b310f871b7493`（在 `7e0efb1` 之上加入 2026-11-02 悬停敌人属性整批改动）
- 引擎：Godot 4.6.3 stable（`D:\godot-proj\Godot_v4.6.3-stable_win64.exe`）
- 平台：Windows x64，本机开发环境

## 命令与结果

命令：

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate_project.ps1 -GodotPath 'D:\godot-proj\Godot_v4.6.3-stable_win64.exe'
```

结果：退出码 `0`，**18/18 闸门通过**。其中：

- 完整测试套件 `30/30` 文件通过（显式输出 `Ran 30 test file(s): 30 passed, 0 failed.`）。
- 独立 worker：`test_chapter_one_playthrough.gd`、`test_save_service.gd`、`test_e2e_scene_flow.gd` 均显式 PASS。
- 解析/资源 smoke 与 120 帧启动 smoke 无锚定错误、无泄漏诊断。
- 静态闸门（UTF-8、JSON、资产登记、提示词登记、阶段门槛、发布资源边界、`git diff --check`）全部通过。
- 性能闸门读取历史开发基准（avg=1.044ms、p95=1.256ms、重复性 0.86%），不是本次重新采样，也不是目标硬件认证。

日志：`build/validate-2026-11-05-fullaccess.log`（`build/` 被 Git 忽略，为本机证据）。

## 首次失败及根因

首次以工作区写权限运行同一命令，退出码 `1`，仅 `12/18` 通过。6 个运行时闸门全部以 `signal 11` 崩溃失败，日志首行为：

```
ERROR: Failed to open 'user://logs/godot2026-11-05T14.02.14.log'.
   at: copy (core/io/dir_access.cpp:423)
```

定位过程：

1. `user://` 指向 `C:\Users\Admin\AppData\Roaming\Godot\app_userdata\星烬誓约`，当时该目录写入被环境拒绝。
2. 将 `APPDATA` 重定向到工作区后，Godot 可正常启动（退出码 0，成功写出日志），但沙箱仍使根证书读取报错，会触发锚定诊断闸门。
3. 在完整文件权限下复跑原始命令，同一工作区、同一提交全部通过。

结论：首次失败是 DSH 工作区沙箱拒绝 `user://` 写入导致的环境问题，不是工程回归；但该环境下的校验结果无效，不得记为通过。今后运行该校验必须允许 Godot 写入 `user://` 日志与存档。

## 结论边界

- 本记录只证明自动化测试、解析与无头启动通过。
- 本轮**没有**重新进行人工完整通关，也没有新的可视截图；2026-11-02 的三类敌人截图与描述仍属该次证据。
- 角色美术仍冻结；静态精灵只作玩法基线，2.5D cutout 仍为 `ART_REVIEW_REJECT`。
- 悬停属性不等于移动后的敌方威胁范围，后者仍是后续工作。
