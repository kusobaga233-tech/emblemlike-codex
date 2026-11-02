# 右键撤销移动与待机提交 — 2026-10-29

## 用户确认覆盖规则

场内空地与敌/我/中立角色右键均撤销当前选中单位未提交的移动；鼠标点击待机后提交，不能再撤销；移除独立撤销按钮。该决策覆盖上一轮“角色右键不撤销”的未实施草案。

## 实现

BattleScene在未被UI消费的右键按下事件中，通过Camera3D投射射线到本场景角色层2和地块层1，命中角色不判断阵营。统一路由到既有BattleSession.undo_selected_move。保持当前角色选中、恢复移动预算，清理攻击/移动预览；返程使用原有移动Tween和镜头跟随。无待撤销移动时保持原有取消操作；场外/天空不操作。原格占据时拒绝并保留待撤销状态。忙碌表现、非我方阶段与终局阻止撤销。

删除UndoMove节点、按钮绑定及HUD专用undo_move命令入口，保留规则层API。HUD显示未提交/已完成状态和右键/待机说明。动画完成不自动设置acted；Wait鼠标点击仍走原有待机规则。

## 测试证据

- 旧场景用例因缺少右键路由先失败，新屏幕命中用例也先失败；实现后通过。修正测试的异步Tween终点采样，避免把动画首帧当作回退失败。
- 新tests/test_right_click_move.gd通过SubViewport.push_input发送鼠标右键按下，覆盖真实友方、敌方PickArea；中立为现有角色team改为neutral的表现fixture，不声称已有完整中立阵营玩法。
- 鼠标左键按下/抬起真实点击Wait按钮；验证travel完毕仍未acted，待机提交后再次右键不能回退。
- 空地射线、场外点击、预览中取消、移动中取消、原格占用拒绝并保留选中均覆盖。
- 完整验证27/27测试文件、18/18闸门通过；Chapter1通关/存档/E2E独立worker通过。build/qa/validation-right-click-move-20261029.log。
- capture工具改为新版右键入口与真实Wait点击，四帧在build/qa/right-click-move-20261029；查看移动与待机帧确认提示、按钮移除和行动后变暗。捕获exit0无错误/资源泄漏诊断。

## 本轮新构建

EXE: D:\godot-proj\star-ember-oath-godot\build\playable\right-click-move-20261029-170157\StarEmberOath.exe
SHA256: ced9a4e6b8ae859bf614eab91b88f9d13c386a3d2d231b2aab5dbeeaa87d827f
Windows导出/资源ZIP边界/EXE无头与窗口各120帧启动均exit0无错误诊断；EXE及四个运行时源文件hash与manifest一致。

## 限制

已有攻击/支援提交逻辑未改变，不实现伤害/治疗回滚；只有移动动画结束不算提交。右键的场地取消不覆盖UI拦截与场外天空。旧存档没有移动原格历史，读档后不能撤销存档前移动。角色表现问题继续延期，不重做资产。本轮启动检查不是完整人工通关，性能闸门是历史记录不是新测。
