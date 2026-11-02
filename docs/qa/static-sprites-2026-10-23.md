# 静态精灵与选择交互验证 — 2026-10-23

## 本轮实现

七类原创候选模型通过 Godot 离线渲染为透明 PNG，每张320x512、统一脚底基线500，资源及hash见 assets/production/sprites/units_v01/manifest.json。只是占位模型的静态化，不代表美术质量升级。运行时ProductionVisual改为Sprite3D，始终朝向镜头，不创建AnimationPlayer或Skeleton。保留世界位置平移、既有VFX、HP变化和死亡隐藏；移除可见角色动作和击破压扁。

地面选中圆环替代遮住身体的实体高亮；血条改为朝向镜头的短Quad，修复背景遮住填充的问题。unit_acted使精灵变暗，自己的下一阶段恢复。普通状态取消选中；行动预览时第一次Esc/右键退出预览，第二次取消选择；普通状态点空地取消。unit_deselected事件通知表现与HUD，清除镜头目标，不改变HP、移动/行动标记。

## 验证

tests/test_static_unit_sprites.gd先观察七个单位仍是模型和有AnimationPlayer导致失败，再实现；后续取消选择、血条排序、圆环高度、已行动标记也观察到失败并修复。历史角色动作断言按用户新要求改为无运行时动作，模型导入/源资产测试保留。

完整项目验证18/18闸门、23/23测试文件通过。Vulkan渲染采集三个角度；build/qa/static-sprites-20261023/contact.png和battle-view-1.png已目视检查。最初采集发现圆环埋入地形、血条背景遮填充，已重拍确认修复。默认静态外观仍粗糙，角色可能互相遮挡，尚未进行人工完整通关。

## 未完成

职业专用正式美术、悬停信息/敌方威胁查看、技能与道具交互、移动撤销、地图重整、第二三章仍待推进。本轮不将这些计划描述为完成。

## 本地实例

D:\godot-proj\star-ember-oath-godot\build\playable\static-sprites-20261023-152328\StarEmberOath.exe

SHA-256: 795dc98e111ff444d3b97034d4a501b6ef1ee92971cb54555b9e9ff02d15193c

Windows导出退出0；独立EXE无头与可视窗口120帧启动检查退出0。未进行人工完整关卡验收。
