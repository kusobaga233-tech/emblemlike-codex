# Aurelia 角色检验结果

日期：2026-10-22（Asia/Shanghai）
总体判定：**FAIL，不可接入正式战斗或作为商业角色资产。**
范围：已批准设定图、v01 可见像素切层、Godot Skeleton2D/SubViewport/3D Quad 技术样板、v03-v05 生图候选。此次只检验并记录，不改写已有角色层。

## 结论摘要

| 项目 | 判定 | 说明 |
|---|---|---|
| 权威 Aurelia 设定图 | PASS（参考基准） | 归档原图 hash 与资产登记一致；作为对照标准，不是游戏角色资源。 |
| v01 技术管线 | PASS（有限范围） | SubViewport、透明合成、脚底锚点、朝向和事件转发测试可通过。此项只证明引擎管线。 |
| 身份/服装一致性 | FAIL / Blocker | v01 从母图得到的切层重组，在 close capture 中呈现短黑色腰部件、暗色发和青橙后片；与批准图的红发、白金轻甲、珊瑚飘带和雾蓝/白长开衩衣片不一致。颜色与轮廓均影响角色身份。 |
| 图层完整性与关节 | FAIL / Blocker | v02 extraction manifest 明确声明肩、内肘、腕、发根、腰部重叠区没有隐藏像素；`layer_contact_sheet_v2.png` 可见头发/躯干、手腕、肩臂与衣片连接被切开或缺失。当前整体根节点小幅移动不能验证肢体关节形变。 |
| 武器与持握 | FAIL / Blocker | 武器图层实际是剑刃与手的裁片组合，但 QA 截图中剑未与手柄/手形成可信握持，idle 明显浮离，attack 仍偏置于身体侧边。 |
| 动作可读性 | FAIL / Major | 当前只定义并截取 idle、locomotion、attack_primary、hit；8 个生产动作中尚缺 attack_secondary、defeat、select、victory。attack_primary 主要由根位移和武器旋转构成，截图中身体/手臂姿态变化很弱，不能作为有力挥砍演出。 |
| Alpha/边缘 | FAIL / Major（现有重组） | 原始母图有软 alpha 和若干小连通组件；局部放大在头发、手腕、衣摆边缘能看到绿/黄残边或断续像素。RGBA 格式和透明通道存在不等同于边缘合格。自动色差计数仅作诊断，最终以正确合成截图和放大目视为准。 |
| v03-v05 重绘 | FAIL / 候选拒收 | v03 服装/轮廓漂移及杂边；v04 露腰短装、飘带/头发跨关节及杂边；v05 改成封闭长袍，与权威图不符。均有独立审核拒收记录，均不得导入运行时。 |

## 证据

- 设定基准：`assets/production/concepts/heroes/aurelia-model-sheets-v01/20260803-151947-gpt-image-2-japanese-anime-cel-shaded-produc.png`，SHA-256 `864ff111d5038f1f5b94539c582e5b90f74afb2dd634bfffe56d59fdad4b59bd`。
- 切层总览：`assets/test/cutout/aurelia_v01/layer_contact_sheet_v2.png`。
- 局部检查：`assets/test/cutout/aurelia_v01/qa-detail-face.png`、`qa-detail-right_arm_hand.png`、`qa-detail-waist_cloth.png`。这些是本轮生成的只读检查图，不是资产修改。
- 引擎捕获：`build/qa/cutout-2p5d-prototype/idle-default-3d.png`、`idle-close-3d.png`、`attack_primary-default-3d.png`、`attack_primary-close-3d.png`。
- 机器 alpha/连通域数据：`docs/qa/aurelia-character-inspection-2026-10-22.json`。其中软边 RGB 统计不是单独拒收门槛。
- 2D 层级/动作接口测试：`tests/test_cutout_character_2d.gd`；3D 合成与事件测试：`tests/test_cutout_character_billboard_3d.gd`。
- 独立审核检查了权威设定图、idle/attack 默认截图和层级总览；复核了 close capture 中的剑手连接和实际姿势差异。

## 通过边界

已证实的技术能力：角色场景可载入；`Skeleton2D` 中存在 root/body/head/weapon；四个 QA 动作可被请求；`attack_primary` 发出 `weapon_trail_on → impact → weapon_trail_off`；3D Quad 接收透明 SubViewport 纹理并可朝向相机。

没有通过的产品能力：不能证明八动作齐全、肢体真实分段、关节可变形、武器被握持、动作具有足够轮廓差异，也不能证明当前层切后的角色保持批准设定身份。因此技术 PASS 不改变总体 FAIL。

## 修复顺序

1. 重新确认源设定与角色层级；不能用当前从错误/低质量全身图抽取的部件继续叠加修补。
2. 以批准正面设定为唯一视觉基准，优先通过可用的参考图编辑流程重绘母图及被遮挡的肩、前后臂、手腕、发根与腰/衣片连接区；每张生成图先独立核对原图身份和衣装。
3. 切出可编辑分层文件，记录每层原图范围、枢轴、遮挡次序和隐藏延伸；先做重组对齐，再做每个主要关节 ±15 度试转和动作极限测试。
4. 重新建立独立 QA 角色；修好持剑手柄锚点，验证 idle、locomotion、两种攻击、hit、defeat、select、victory 八动作，记录事件帧和逐帧/录像证据。
5. 独立视觉复核必须同时检查原图、透明边缘浅/深底、默认/近景、持握和动作；所有 Blocker 清零后才允许进入正式战斗接入评审。

## 附注

参考图生成记录位于共享输出目录 `D:/CODEX-PROJ/common/outputs/imagegen/aurelia-reference-redraw-20261021-v01`，编辑接口返回 HTTP 403/1010，generations 路由返回 HTTP 502，未得到生成图。现有 v03-v05 候选只存于各自拒收目录，不属于项目交付资源。
