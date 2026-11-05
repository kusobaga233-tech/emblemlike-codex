# 悬停敌人属性 — 2026-11-02

## 交付

新增独立EnemyInspectionPanel，以只读字典快照渲染敌军名称、兵种、可见生命/上限、攻击/类型、防御/抗性、移动/离散射程、基础命中/暴击、行动状态。悬停不调用规则命令，不选敌、不动相机或移动/攻击覆盖层，未提交移动可继续右键撤销。UI全层mouse-ignore，不消耗鼠标点击。

BattleScene管理当前属性对象ID，老对象退出不会关新对象。空地/友军/当前对象退出/窗口退出/模式变化/重建/播放开始清理。攻击与治疗模式始终优先预测/确认，不叠加或覆盖。生命来自GreyboxUnit.visual_hp；播放期间隐藏。可见伤害/击破事件及时刷新/清理，不用未来逻辑HP冒充显示血量。

## 测试

新增test_enemy_inspection.gd，先因缺少面板失败，再实现。覆盖只读状态快照相等、待回退移动、近战/远程数值与离散射程、命中暴击、行动状态、快速切换退出、友军/空地/死亡清理、移动覆盖层保持、攻击与治疗锁定优先、timeline隐藏、可见HP边界、事件更新、重建/窗口退出。

实际鼠标运动通过SubViewport.push_input送至敌人PickArea并移至空地。最初测试未收到SubViewport鼠标进入通知；正确启用physics_object_picking并调用notify_mouse_entered后，通过真实物理悬停验证，不以直接调用hover代替该路径。

完整回归曾失败于场景子节点owner不符合既有约定，按其他UI组件加入递归归属修正。最终tools/validate_project.ps1输出30/30文件、18/18闸门通过，含独立Chapter1通关/存档/E2E与启动。日志build/qa/validation-enemy-inspection-20261102.log。

可视capture_enemy_inspection.gd使用真实鼠标运动，未摆放/改变敌人属性，正常移动我方角色后查看三类敌人；输出5帧在build/qa/enemy-inspection-20261102。查看Boss横屏1280x800与弓手竖屏720x1280，所有数值可读，无HUD重叠。捕获exit0无错误/泄漏诊断。

## 本地新版

EXE: D:\godot-proj\star-ember-oath-godot\build\playable\enemy-inspection-20261102-144823\StarEmberOath.exe
SHA256: 68436995ffaeece0ec7797d2c283957a157935b332a1a0be4b71ac5f4c3ba60f
Windows导出/真实ZIP边界/独立EXE无头及窗口各120帧启动通过且无错误诊断。ZIP检查新属性脚本/场景及layouts.json保留；EXE和五个运行时文件hash与manifest一致。

本轮改动保留本地工作区，没有自动提交/推送；远程仍是之前用户要求上传时的版本。

## 限制与后续

仅属性，不是完整移动后敌方威胁范围。鼠标需命中现有角色PickArea，静态精灵重叠遮挡限制依旧；极窄视口未验收。角色方案继续冻结，尚无新AI/地图/第二三章。旧存档不保存移动回退历史。启动非完整人工通关；性能闸门使用历史样本非新目标设备认证。后续重点第一章地图、目标与教学闭环，再考虑敌方威胁展示。
