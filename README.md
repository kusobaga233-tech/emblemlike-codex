# 星烬誓约

《星烬誓约》是一个使用 Godot 4.6 和 Forward+ 渲染器构建的战术角色扮演游戏项目。

## 环境

- Godot 4.6.3 stable
- 默认视口：1920 × 1080

## 运行测试

在项目根目录中打开 PowerShell 并执行（`godot` 需已加入 PATH）：

```powershell
godot --headless --path . --script res://tests/run_all.gd
```

测试运行器会发现 `tests` 目录中的 `test_*.gd` 测试脚本，并在任一测试失败时以退出码 1 结束。
