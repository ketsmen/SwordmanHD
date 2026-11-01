# SPDX-License-Identifier: GPL-3.0-only
extends "res://tests/test_base.gd"
## 范围格叠加: 原版是加色着色 (底 + 色 * (p8>>1)/8), 选中 / 目标范围蓝紫 0x401F p8 三角波脉动 (62 tick 一周), 悬停预览固定 p8=10 (敌方红);
## 依据: Windows 直读后缓冲实测 (见实测记录文档)。用假场景构建 BattleView。

class FakeScene:
	extends Node2D
	var units_node := Node2D.new()
	func _init() -> void:
		add_child(units_node)


const REQUIRES_TEST := {  # 个别方法的依赖 (run_tests.gd 头注), 缺则 SKIP: 建 BattleUi 要原版资源
	"test_move_range_is_additive_and_pulses": ["original"],
	"test_hover_preview_is_fixed_and_enemy_is_red": ["original"],
}


func _view() -> BattleView:
	var scene := FakeScene.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	var ui := BattleUi.new(scene)
	scene.add_child(ui)  # 挂进假场景, 一起释放 (BattleUi 是 Node, 不挂树就是孤儿)
	var v := BattleView.new(scene, ui)
	scene.add_child(v)  # 触发 _ready
	return v


func test_pulse_sequence_matches_original():
	var seq := []
	for i in 62:
		seq.append(BattleView.pulse_p8(i))
	var want := []
	for k in range(1, 17):
		want.append(k)
	for k in range(14, -1, -1):
		want.append(k)
	want.append_array(want.duplicate())
	eq(seq, want, "p8: 1..16, 14..0, 1.. (周期 31 步)")
	eq(BattleView.range_weight(16), 1.0, "p8=16 满权重")
	eq(BattleView.range_weight(10), 0.625, "p8=10 (悬停预览) = 5/8")
	eq(BattleView.range_weight(1), 0.0, "p8=1 -> k=0")


func test_move_range_is_additive_and_pulses():
	var v := _view()
	v.show_range([Vector2i(3, 4), Vector2i(4, 4)], BattleView.RANGE_MOVE)
	eq(v._range_node.get_child_count(), 2, "两个范围格")
	check((v._range_node.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "加色混合 (地形透出)")
	var m0 := v._range_node.modulate
	v._process(0.08 * 15.5)   # 第 15 步: p8 = 16 峰值
	var m1 := v._range_node.modulate
	check(m1.b > m0.b + 0.5, "峰值比起点亮 (脉动)")
	check(is_equal_approx(m1.b, 1.0) and is_equal_approx(m1.r, 16.0 / 31.0), "峰值 = 蓝紫 0x401F 满权重")
	v._process(0.08 * 8)   # 第 23 步: p8 = 7
	check(v._range_node.modulate.b < m1.b, "过了峰值往回落")
	v.get_parent().free()


func test_hover_preview_is_fixed_and_enemy_is_red():
	var v := _view()
	v.show_range([Vector2i(1, 1)], BattleView.RANGE_HOVER)
	var a := v._range_node.modulate
	v._process(1.0)
	eq(v._range_node.modulate, a, "悬停预览不脉动")
	near(a.b, 0.625, 0.001, "p8=10 权重 5/8")
	v.show_range([Vector2i(1, 1)], BattleView.RANGE_ENEMY)
	var r := v._range_node.modulate
	check(r.r > 0.6 and r.g == 0.0 and r.b == 0.0, "敌方 / 友军预览红色")
	v.get_parent().free()
