# 明确攻击确认 — 2026-11-02

## 本轮实现

悬停仅预测，点击敌军锁定并显示名称/确认攻击/取消。重复点击不执行规则；锁定后指针离开和经过其他单位不清空/替换，左键另一合法敌军才换目标。普通命中HP预测加不确定性说明。确认仍由session.confirm_attack重新验证并消费行动，规则伤害/随机数/事件时序未改。

CombatForecastPanel按attack/support确认类型路由，隐藏/清除预测重置类型；隐藏按钮发出信号不执行过期行动。治疗确认兼容，公共取消不消费行动。右键仍优先撤销未提交移动、保持角色选中并清理锁定；角色已行动后不可撤销伤害。

本轮没有敌方威胁图、AI、地图或新反击结算。既有can_counter字段保持，不等于新反击系统验收。

## 证据

新增test_attack_confirmation.gd先因缺少attack_confirmed接口失败，再实现转绿。覆盖悬停、锁定、重复点、指针越界预览保持、换目标、取消、失效目标重校验、右键移动撤销、鼠标按下/抬起确认、忙碌重复信号无额外伤害、显示HP在cue更新、攻击切治疗后不会误路由。Support与RightClick用例回归通过。

E2E更新：敌军点击只显示锁定预览，必须真实鼠标点击确认按钮才进入最后一击和结果场景。独立E2E通过，未用直接规则结算替代UI步骤。

完整validator：29/29测试文件、18/18闸门，通过Chapter1通关/存档/E2E独立worker、解析与启动。日志build/qa/validation-attack-confirmation-20261102.log。

capture_attack_confirmation.gd输出四帧至build/qa/attack-confirmation-20261102，已查看1280x800及720x1280预测，文字与按钮可读且不与HUD重叠。人工摆放角色且固定100命中/0暴击用于确定性捕获，不代表正常关卡概率设定或全流程人工验收；捕获exit0无错误/泄漏诊断。

## 新版本

EXE: D:\godot-proj\star-ember-oath-godot\build\playable\attack-confirmation-20261102-132718\StarEmberOath.exe
SHA256: edb4dea5111f0686bbe63c4150dc6297c939c182de05790805a3872d35e65cb0
Windows导出、ZIP资源边界与EXE无头/窗口各120帧启动均退出0无错误诊断；布局JSON保留；EXE及四个运行时源文件hash已核对。未整体提交或清理工作区已有内容。

## 范围限制与后续

角色方案继续冻结。旧存档不保留可撤销移动原格。极窄视口仍待统一UI改造，已验证720/1280宽。性能为历史benchmark不代表本轮新测或目标设备认证。启动检查不代表全章人工通关。后续先做敌方威胁展示与第一章地图/目标/教学闭环，再扩展章节。
