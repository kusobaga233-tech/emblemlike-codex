# 4头身卡通精灵及地块中心对齐

日期：2026-10-23。用户要求：4头身、日式卡通效果、战术大小看清细节、修复角色在地块站歪。

## 资产处理

使用 myimage-gen / Right Code Draw，gpt-image-2，请求1024x768、medium；实际返回1448x1086 RGBA。两轮候选和失败/重做过程保留于 D:/CODEX-PROJ/common/outputs/imagegen/star-ember-chibi4-sprites-20261023-v01。第一轮将身体拉长导致过瘦，已弃用。最终采用 proportion-revision 批次，人工标注头顶/下巴/左右鞋底，保留头部像素，仅收短过长下身至3个头高，以4头身标尺归一化；不把metadata当作独立视觉证明。最终联系表、原始/验证清单、提示词、处理脚本完整保留。

## 对齐修复

上一版按不透明外框底部统计中心，易受武器/披风影响；Sprite3D脚底还比选中圆环低0.25世界单位。本版 layouts.json 给每个角色单独记录 foot_anchor_pixels 与 soles_pixels；Sprite3D.offset 将人工鞋底中点精确映射到本地(0,0)，Sprite3D与圆环使用相同BOARD_GROUND_Y=-0.45，角色根仍维持格子中心(x,0.7,z)，不改规则坐标与移动路径。

测试覆盖七角色纹理集/尺寸/4头身数据、脚底像素到pivot的映射零误差、水平位置无偏移、与圆环同平面，以及原有选择/取消/行动状态。先观察新断言失败，再实现后通过。

## 验证与视觉证据

完整验证23/23测试文件、18/18闸门。Vulkan截图 build/qa/cartoon4-alignment-20261023：默认、旋转战场和七个角色在无装饰地块(3,6)的两个角度。alignment.json记录七个角色脚底pivot与圆环世界坐标距离均为0；all-unit-centers.png已逐个目视检查。脚底中心对齐不表示每只脚都落在格中心，两脚应位于中心两侧。

独立视觉复核 PASS WITH NOTES：约4头身的卡通轮廓、描线和色块符合方向，无明显压缩接缝或关节塌陷；兜帽角色的严格解剖头身比不能仅凭外轮廓认证。孤立Fenn脚底位于环/格中心。暗敌细节、拥挤站位遮挡和血条压人物仍待打磨。整图细节与场景/UI成品质量不能由此直接推导。

## 实例

D:\godot-proj\star-ember-oath-godot\build\playable\cartoon-four-head-aligned-20261023-175130\StarEmberOath.exe

SHA-256: 10a1181e66039271a0541e67a16c29625c714c0035a6d670d3b1b593243661ac

导出退出0、无头/可视120帧启动退出0；未人工完整通关。
