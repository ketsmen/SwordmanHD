# SPDX-License-Identifier: GPL-3.0-only
extends "res://tests/test_base.gd"
## 部件 type 3~6 与 type 2 的 p10=0 (/, 静态观察 动画对照_静态观察.md 第 2 节)。


func test_rgb555_and_weights():
	eq(AnimPlayer.rgb555(0x7FFF), Color(1, 1, 1), "白")
	eq(AnimPlayer.rgb555(0x7C00), Color(1, 0, 0), "红")
	eq(AnimPlayer.rgb555(15855), Color(15 / 31.0, 15 / 31.0, 15 / 31.0), "15855 = 0x3DEF 是 (15,15,15) 的灰")
	eq(AnimPlayer.rgb555(-32768 + 0x7FFF) , AnimPlayer.rgb555(0xFFFF), "p12 是带符号 int16, 按无符号取 5-5-5 位 (最高位忽略)")
	eq(AnimPlayer.tint_weight(16), 1.0, "p=16 全权重")
	eq(AnimPlayer.tint_weight(8), 0.5, "p=8 一半")
	eq(AnimPlayer.tint_weight(1), 0.0, "p=1 -> k=0 (camp09 的黑色剪影)")
	eq(AnimPlayer.tint_weight(0), 0.0)


func test_tint_materials():
	var m3 = AnimPlayer._tint_material(3, 8, 16, 0x7FFF)
	eq(m3.get_shader_parameter("src_k"), 0.0, "type 3 不用源图颜色")
	eq(m3.get_shader_parameter("dst_keep"), 1.0, "type 3: 底 * p10/16")
	eq(m3.get_shader_parameter("col_k"), 0.5, "type 3: 色 * p8/16")
	var m4 = AnimPlayer._tint_material(4, 0, 1, 0)
	eq(m4.get_shader_parameter("dst_keep"), 0.0, "type 4 覆盖底")
	eq(m4.get_shader_parameter("src_k"), 0.0, "p10=1 -> k=0")
	eq(m4.get_shader_parameter("col_k"), 0.0, "p8=0: 纯黑剪影")
	var m4b = AnimPlayer._tint_material(4, 16, 16, 0x7C00)
	eq(m4b.get_shader_parameter("src_k"), 1.0, "type 4: 源 * p10/16")
	check(AnimPlayer._tint_material(3, 8, 16, 0x7FFF) == m3, "同参数共用材质")
	check(AnimPlayer._invert_material(true) != AnimPlayer._invert_material(false), "type 5 / 6 用不同材质")
