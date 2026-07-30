# 星烬誓约

《星烬誓约》是一个使用 Godot 4.6 和 Forward+ 渲染器构建的战术角色扮演游戏项目。

## 环境

- Godot 4.6.3 stable
- 默认视口：1920 × 1080

## 运行测试

在 PowerShell 中执行：

```powershell
& 'D:\godot-proj\Godot_v4.6.3-stable_win64.exe' --headless --path 'D:\godot-proj\star-ember-oath-godot' --script res://tests/run_all.gd
```

测试运行器会发现 `tests` 目录中的 `test_*.gd` 测试脚本，并在任一测试失败时以退出码 1 结束。
