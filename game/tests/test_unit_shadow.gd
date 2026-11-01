# SPDX-License-Identifier: GPL-3.0-only
extends "res://tests/test_base.gd"
## 战场单位脚下的影子 (engine/battle/unit_shadow.gd): 原版实测每个单位脚下一个黑色半透明椭圆 (32x14 原版像素, alpha 0.55), 位置跟格子不跟精灵。


## 合成动画: 站立 1 帧、行走 1 帧 (每方向); 帧 3 = 引擎站立画面, 有一个人物部件; extra 为这一帧追加的部件
func _data(extra := [], stand := 1) -> Dictionary:
	var frames := []
	for i in 3 + 4 * (stand + 1):
		frames.append({"sound": -1, "time": 2, "hit": 0, "color": 0, "shake": 0, "unk4": 0, "parts": []})
	frames[3]["parts"] = [{"tex": 0, "x": 143, "y": 82, "type": 0, "p8": 0, "p10": 0, "p12": 0}] + extra
	return {"frames": frames, "action_counts": [stand, 1, 0, 0, 0], "textures": [{"w": 40, "h": 50}, {"w": 28, "h": 8}], "sounds": []}


func test_has_picture_follows_the_stand_frame():
	check(UnitShadow.has_picture(_data()), "站立画面有部件 → 有影子")
	check(UnitShadow.has_picture(_data([], 0)), "没有站立帧的单位 (167 / 168 / 170) 也用帧 base, 有部件就有影子")
	var d := _data()
	d["frames"][3]["parts"] = []
	check(not UnitShadow.has_picture(d), "站立画面是空的 (163 头 / 165 黑龙): 原版没有影子")
	d["frames"][5]["parts"] = [{"tex": 0, "x": 10, "y": 20, "type": 0, "p8": 0, "p10": 0, "p12": 0}]
	check(not UnitShadow.has_picture(d), "不往后找别的帧 (原版实测头 / 黑龙没有影子)")
	check(not UnitShadow.has_picture({}), "没有动画数据不报错")


func test_glow_only_and_own_shadow_part_still_get_the_standard_shadow():
	var d := _data()
	d["frames"][3]["parts"] = [{"tex": 0, "x": 120, "y": 60, "type": 2, "p8": 8, "p10": 8, "p12": 0}]
	check(UnitShadow.has_picture(d), "站立画面只有发光部件 (紫焰妖灵等) 也有影子")
	check(UnitShadow.has_picture(_data([{"tex": 1, "x": 150, "y": 124, "type": 1, "p8": 8, "p10": 0, "p12": 0}])), "带 type 1 影子部件的 055: 标准影子照画 (原版两层叠加)")


func test_shape_matches_measured_ellipse():
	var t := UnitShadow.texture()
	var k := UnitShadow.SUPERSAMPLE
	eq([t.get_width(), t.get_height()], [UnitShadow.W * k, UnitShadow.H * k], "贴图 = 32x14 原版像素 x 放大倍数")
	var img := t.get_image()
	# 实测 (S1.2) 逐行 [起, 止): 第 12 行 8..22, 第 14 行 2..28, 第 16 行 0..30, 第 19 行 -1..31; 横向相对中心 15, 行相对中心 19
	var rows := {12: [8, 22], 14: [2, 28], 16: [0, 30], 19: [-1, 31]}
	for r in rows:
		var y := int((float(r) + 0.5 - (UnitShadow.CENTER.y - UnitShadow.H / 2.0)) * k)
		var lo := -1
		var hi := -1
		for x in t.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				if lo < 0:
					lo = x
				hi = x
		var x0 := UnitShadow.CENTER.x - UnitShadow.W / 2.0
		check(absf(lo / float(k) + x0 - rows[r][0]) <= 1.0 and absf((hi + 1) / float(k) + x0 - rows[r][1]) <= 1.0,
			"第 %d 行 [%.2f, %.2f) 应约 %s" % [r, lo / float(k) + x0, (hi + 1) / float(k) + x0, rows[r]])
	check(img.get_pixel(0, 0).a < 0.01 and img.get_pixel(t.get_width() - 1, t.get_height() - 1).a < 0.01, "四角透明")
	var soft := 0
	for x in t.get_width():
		var a := img.get_pixel(x, t.get_height() / 2 - 1).a
		if a > 0.05 and a < 0.95:
			soft += 1
	check(soft >= 2, "边缘有半透明过渡 (抗锯齿), 不是硬边色块")


func test_supersample_matches_the_layout_scale():
	eq(UnitShadow.SUPERSAMPLE, Assets.SCALE, "影子贴图倍数 = 布局放大倍数 (Assets.SCALE)")


func test_unit_gets_one_shadow_below_the_sprite_anchored_to_the_cell():
	var u := BattleUnit.new()
	u.info = {"name": "甲", "camp": 0, "sprite": 1}
	u.anim = AnimPlayer.new()
	u.anim.position = Vector2(-142, -110)
	u.add_child(u.anim)
	var d := _data()
	u._ensure_shadow(d)
	u._ensure_shadow(d)   # 再调不重复建
	var shadows := u.get_children().filter(func(n): return n is Sprite2D)
	eq(shadows.size(), 1, "只建一个影子")
	var sh: Sprite2D = shadows[0]
	eq(sh.position, UnitShadow.CENTER, "影子在格子里固定位置 (不随精灵部件, 不含动画偏移)")
	check(is_equal_approx(sh.modulate.a, UnitShadow.ALPHA), "alpha 0.55")
	check(u.get_child(0) == sh, "排在人物动画之下 (先画)")
	eq(sh.scale, Vector2.ONE / float(UnitShadow.SUPERSAMPLE), "缩回原版像素大小")
	u.free()
	var v := BattleUnit.new()
	v.anim = AnimPlayer.new()
	v.add_child(v.anim)
	var e := _data()
	e["frames"][3]["parts"] = []
	v._ensure_shadow(e)
	eq(v.get_children().filter(func(n): return n is Sprite2D).size(), 0, "站立画面为空的精灵不加")
	v.free()


## 当前显示帧没有部件时影子也不画 (部件数为 0 整个绘制跳过); 有部件的帧恢复
func test_shadow_hidden_on_empty_frame():
	var u := BattleUnit.new()
	u.info = {"name": "甲", "camp": 0, "sprite": 1}
	u.anim = AnimPlayer.new()
	u.add_child(u.anim)
	var d := _data()
	u.anim.data = d
	u._ensure_shadow(d)
	var sh: Sprite2D = u.get_children().filter(func(n): return n is Sprite2D)[0]
	u.anim.frame_shown.emit(4)   # 帧 4 无部件
	check(not sh.visible, "空帧: 影子隐藏")
	u.anim.frame_shown.emit(3)   # 帧 3 有人物部件
	check(sh.visible, "有部件的帧: 影子显示")
	u.free()
