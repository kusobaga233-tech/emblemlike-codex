# Windows 资源包范围验证

日期：2026-10-21。范围：开发资源排除、正式资源保留和引擎载入导出 ZIP；不代表 Windows EXE 发布验收。

## 问题与修改

旧 preset 使用 all_resources，仅排除 tests/evidence、tools 和 docs，导致参考归档、试验角色、QA 场景、测试脚本、build 截图进入实际导出包。

export_presets.cfg 现在排除 tests、tools、docs、build、src/qa、assets/test、assets/production/concepts。生产模型、环境和正式章节保留。源资源与 QA 测试仍留在开发工程，不删除或移动。

## 实际验证

- 修改前导出 ZIP 退出 0，但包检查退出 1：209 个条目，含开发资源；RED 证据在 build/qa/release-boundary-20261021/red.json。
- 修改后导出 ZIP 退出 0，80 个条目；检查器报告没有禁止路径、缺失启动/第一章/战斗场景或失效 remap/import 路径。
- 对被排除目录的 .import sidecar 逐一解析，未发现对应 .godot/imported 转换文件泄漏。
- 从独立 build/qa 目录使用 --main-pack 加载 after.zip，运行 120 帧退出 0，无 stderr；避免从源码工程补足缺失资源。
- 这是实际包的启动检查，尚未通过部署、战斗、胜负和恢复流程；不将其描述为完整发布测试。

## 重现

在主工程执行以下命令，输出到新的 ZIP 文件（不要覆盖历史证据）：

```powershell
& 'D:/godot-proj/Godot_v4.6.3-stable_win64.exe' --headless --path . --export-pack 'Windows x64 Release' 'build/qa/release-boundary-20261021/after.zip'
python tools/verify_release_archive.py build/qa/release-boundary-20261021/after.zip
& 'D:/godot-proj/Godot_v4.6.3-stable_win64.exe' --headless --path 'build/qa/release-boundary-20261021' --main-pack 'after.zip' --quit-after 120
```

build 目录被 Git 忽略，日志与 ZIP 为本机证据，不承诺随仓库分发。后续仍需重新构建 Windows EXE、记录版本/hash、确认无头与可视通关，并完成干净用户环境验证。
