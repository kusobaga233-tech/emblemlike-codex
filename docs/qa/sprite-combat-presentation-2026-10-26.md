# 静态精灵攻击表现 — 2026-10-26

## 已实现

整张静态Sprite3D仍是唯一角色图层；通过SpriteCombatPresentation和SpriteCombatFx实现预备、整图前冲/回位、近战斩击、突刺、弓箭飞行、法术光环、治疗脉冲、命中闪白、伤害/治疗数字和击破隐藏。没有拆分2D骨骼，没有角色AnimationPlayer，没有改BattleSession结算结果。CombatVfxDirector继续提供Boss/resonance/终局等非时序特效。

规则事件批次先被表现队列消费：逻辑HP/状态结算保持原确定性；damage/heal等显示事件在表现时点通知Unit/HUD。攻击表现期间BattleScene屏蔽拾取与HUD命令，战斗结果等待playback_finished。多段/反击事件串行排队。

## 测试

新增 tests/test_sprite_combat_presentation.gd，先观察场景缺少表现组件失败，再实现并通过24/24完整断言。覆盖首帧预备、整图位移而非逻辑根位移、melee impact、箭矢、治疗、反击排队、输入锁、状态不被表现改写、精灵回位和清理。

Windows导出退出0；独立EXE无头/可视窗口120帧启动检查退出0。实例：D:\godot-proj\star-ember-oath-godot\build\playable\sprite-combat-presentation-20261026-182521\StarEmberOath.exe
SHA256：fce55426e21d9774adb967a9347d38aa878ef7ce8088b53224adf7ea72aaaf5e

历史诊断更正（2026-10-29）：此前将失败直接归因于2.5D QA资源泄漏并不准确。E2E worker被过短帧数上限提前终止，未完成表现队列与正常退出。已恢复所有QA测试、延长内部worker上限并要求显式PASS，E2E改用确定性推进。当前结果请看2026-10-29 QA记录；旧EXE及其构建清单保留作历史记录，不代表新版本。
