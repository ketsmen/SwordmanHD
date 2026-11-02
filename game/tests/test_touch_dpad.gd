# SPDX-License-Identifier: GPL-3.0-only
extends "res://tests/test_base.gd"
## 手机虚拟键的十字键样式 (设定「触屏键样式」touch_pad = dpad; 2026-11-03 网友反馈圆形摇杆容易斜着输入):
## 手指在哪条臂上就是哪个方向, 两臂之间的斜角保持原方向; 缺省仍是圆形摇杆; 设定行只在有虚拟键时列。

func _pad():
	var pad = load("res://engine/input/touch_pad.gd").new()
	(Engine.get_main_loop() as SceneTree).root.add_child(pad)
	return pad


func test_default_is_stick():
	eq(SettingsSchema.row("touch_pad").get("def"), "stick", "缺省圆形摇杆")
	var pad = _pad()
	eq(pad.style(), "stick")
	pad.free()


func test_dpad_arm_decides_direction():
	var pad = _pad()
	pad.set_style("dpad")
	var c: Vector2 = pad._stick_c
	var r: float = pad._stick_r
	var half: float = r * pad.DPAD_ARM * 0.5
	eq(pad.stick_dir(c + Vector2(r * 0.1, 0)), UiAction.NONE, "中心没有方向")
	eq(pad.stick_dir(c + Vector2(r * 0.8, 0)), UiAction.RIGHT, "右臂")
	eq(pad.stick_dir(c + Vector2(-r * 0.8, 0)), UiAction.LEFT, "左臂")
	eq(pad.stick_dir(c + Vector2(0, -r * 0.8)), UiAction.UP, "上臂 (屏幕 y 向下为正)")
	eq(pad.stick_dir(c + Vector2(0, r * 0.8)), UiAction.DOWN, "下臂")
	pad.stick_dir(c + Vector2(r * 0.8, 0))
	eq(pad.stick_dir(c + Vector2(r * 0.8, half * 0.9)), UiAction.RIGHT, "还在右臂宽度里: 右")
	eq(pad.stick_dir(c + Vector2(r * 0.6, r * 0.9)), UiAction.RIGHT, "滑进右下斜角 (下比右还多): 保持右, 不跳成下")
	eq(pad.stick_dir(c + Vector2(half * 0.9, r * 0.9)), UiAction.DOWN, "完全进了下臂才换成下")
	pad.stick_release()
	eq(pad.stick_dir(c + Vector2(r * 0.9, r * 0.6)), UiAction.RIGHT, "刚按下就在斜角: 取主方向")
	pad.free()


func test_dpad_style_switch_resets_direction():
	var pad = _pad()
	var c: Vector2 = pad._stick_c
	pad.stick_dir(c + Vector2(pad._stick_r * 0.8, 0))
	pad.set_style("dpad")
	eq(pad._stick_dir, UiAction.NONE, "换样式时松开方向")
	pad.set_style("bogus")
	eq(pad.style(), "stick", "非法值按摇杆")
	pad.free()


func test_setting_row_only_with_touch():
	var args = DebugArgs.current()
	var old: bool = args.touch
	args.touch = false
	var keys := SettingsSchema.shown_rows("controls").map(func(r): return r["key"])
	check(Platform.is_mobile() or not keys.has("touch_pad"), "桌面没开 --touch 不列")
	args.touch = true
	keys = SettingsSchema.shown_rows("controls").map(func(r): return r["key"])
	check(keys.has("touch_pad"), "有虚拟键时在控制器设置里列")
	args.touch = old
