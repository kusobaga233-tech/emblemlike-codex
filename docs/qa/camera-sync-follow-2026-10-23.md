# 镜头同步跟随

取代同日200ms延迟方案。移除轨迹历史和延迟计算，按角色当前世界位置计算位移，保持原观察偏移并限制焦点在地图内。渲染前再采样一次，以匹配SceneTree tween在_process之后的更新。

测试先观察同步位移断言失败，再修改实现并通过tests/test_camera_movement_follow.gd；覆盖首帧、终点、无残余跟随、视角/距离保持及手动/选中变更取消跟随。完整验证18/18闸门、22/22测试文件通过；Windows导出退出0，无头/可视120帧启动检查退出0。未作人工完整通关或体感验收。

实例：D:\godot-proj\star-ember-oath-godot\build\playable\camera-sync-follow-20261023-142429\StarEmberOath.exe

SHA256：375f095d61ff1cd060c3cbab7ac559c1cf4a557c37a5479d52f53bca72e4bf69
