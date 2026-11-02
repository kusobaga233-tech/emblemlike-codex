# 移动镜头延迟跟随验证

延迟：200ms。读取角色表现节点实际世界位置并插值回放200ms前的轨迹，保持观察偏移/距离/45°倾角。角色当前移动180ms，不改变角色移动时长。手动平移、旋转、聚焦/重置或切换/释放目标取消旧跟随。

测试先因缺失 begin_movement_follow 失败，实现后测试通过。覆盖199ms静止、200ms边界、250ms对应50ms轨迹、终点追随、自由输入取消、释放目标安全，以及真实 BattleSession 移动命令/角色Tween与选择保持。

完整验证18/18闸门，22/22测试文件；本轮Windows导出退出0，EXE无头/可视窗口120帧启动检查退出0。启动检查不等同于完整关卡通关，也不是对延迟跟随的人工体感验收。

实例：D:\godot-proj\star-ember-oath-godot\build\playable\camera-follow-200ms-20261023-135706\StarEmberOath.exe

SHA-256：04d3e2580e289c041b60184ee70b1479eaec960cf87b0c1a8edf59566aa9c9cd
