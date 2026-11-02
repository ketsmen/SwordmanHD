# SPDX-License-Identifier: GPL-3.0-only
extends "res://tests/test_base.gd"
## 设定「成长」(复刻新增): 我方升级时五项属性 / HP / MP 的随机项, 随机 (原版 0..N 随机) / 最大 (恒取上限) / 最小 (恒取 0)。
## 行与校验在 SettingsSchema, 生效在 Params.apply_growth_setting (战斗开始时 BattleRules.battle_start 取设定), 缺省随机 = 与原版一致。
const REQUIRES_TEST := {"test_setting_drives_level_up_results": ["data"]}

const Growth = preload("res://engine/rules/growth.gd")


class FakeSt:
	extends RefCounted
	var width := 2
	var height := 2
	func cell(_x: int, _y: int) -> Dictionary:
		return {"move": 0}


class FakeScene:
	extends RefCounted
	var st := FakeSt.new()
	var units: Array = []


## 设定值走到战斗的规则参数: 战斗开始时读一次, 之后设定再改不影响这场
func _battle_growth(setting) -> String:
	var gc := GameContext.current()
	var old = gc.settings.get("growth")
	if setting == null:
		gc.settings.erase("growth")
	else:
		gc.settings["growth"] = setting
	var r := BattleRules.new(FakeScene.new())
	var mode: String = r.ctx.params.growth_mode
	gc.settings["growth"] = "min" if setting != "min" else "max"   # 开战后再改设定
	eq(r.ctx.params.growth_mode, mode, "开战后改设定不影响这场")
	if old == null:
		gc.settings.erase("growth")
	else:
		gc.settings["growth"] = old
	return mode


func test_setting_row_defaults_and_options():
	var r := SettingsSchema.row("growth")
	check(not r.is_empty(), "有成长项")
	eq(SettingsSchema.defaults()["growth"], "random", "缺省随机 (原版)")
	var opts := SettingsSchema.options_of(r)
	eq(opts.map(func(o): return o["v"]), ["random", "max", "min"])
	eq(opts.map(func(o): return o["t"]), ["随机", "最大", "最小"])
	var main := SettingsSchema.shown_rows().map(func(x): return x["key"])
	check(not main.has("growth"), "主菜单里不直接列, 收在「特色功能」里")
	var feature := SettingsSchema.shown_rows("feature").map(func(x): return x["key"])
	check(feature.has("growth"), "「特色功能」二级菜单里列出")
	check(main.has("feature"), "主菜单有「特色功能」入口")


func test_setting_validation_and_step():
	eq(SettingsSchema.sanitize({"growth": "max"})["growth"], "max", "合法值保留")
	eq(SettingsSchema.sanitize({"growth": "min"})["growth"], "min")
	for bad in ["", "MAX", "normal", 1, null]:
		eq(SettingsSchema.sanitize({"growth": bad})["growth"], "random", "非法值回退随机: %s" % str(bad))
	eq(SettingsSchema.sanitize({})["growth"], "random", "旧设定文件里没有这个键 = 随机")
	eq(SettingsSchema.step("growth", "random", 1), "max", "右键: 随机 -> 最大")
	eq(SettingsSchema.step("growth", "max", 1), "min")
	eq(SettingsSchema.step("growth", "min", 1), "random", "到头循环")


## 「随机」不碰内容包 rules.json 自己设的 growth_mode; 最大 / 最小才覆盖
func test_apply_growth_setting_maps_to_params():
	var p = Params.new()
	eq(p.growth_mode, "random")
	p.apply_growth_setting("random")
	eq(p.growth_mode, "random", "随机 = 原版")
	p.apply_growth_setting("max")
	eq(p.growth_mode, "max")
	p.apply_growth_setting("min")
	eq(p.growth_mode, "min")
	var q = Params.new({"growth_mode": "max"})
	q.apply_growth_setting("random")
	eq(q.growth_mode, "max", "内容包自己设的最大成长不被「随机」冲掉")
	q.apply_growth_setting("bogus")
	eq(q.growth_mode, "max", "未知值不动")


func test_setting_drives_level_up_results():
	var tb := {"hp_rand": 5, "mp_rand": 5, "str": {"base": 3, "rand": 3}, "int": {"base": 1, "rand": 4},
		"avg": {"base": 0, "rand": 0}, "vit": {"base": 2, "rand": 2}, "luk": {"base": 1, "rand": 1}, "skills": []}
	var gains := {}
	for mode in ["max", "min"]:
		var c = ctx_data(null)
		c.params.apply_growth_setting(mode)
		var r := Growth.level_up(c, unit({"lv": 10, "vit": 20, "int": 20}), tb)
		gains[mode] = r.gains
	eq(gains["max"]["str"], 6, "最大: 3 + 3")
	eq(gains["min"]["str"], 3, "最小: 基础 3 + 随机项 0")
	eq(gains["max"]["int"], 5)
	eq(gains["min"]["int"], 1)
	check(gains["max"]["hp"] > gains["min"]["hp"], "HP 上限也随之变化")
	check(gains["max"]["mp"] > gains["min"]["mp"], "MP 上限也随之变化")


func test_battle_uses_growth_setting_at_start():
	eq(_battle_growth(null), "random", "设定里没有 = 随机 = 原版")
	eq(_battle_growth("random"), "random")
	eq(_battle_growth("max"), "max")
	eq(_battle_growth("min"), "min")


## 成长模式在战斗开始时定 (录像要对得上), 战斗里改了也不会生效: 战斗中这一行照列 (显示当前值) 但灰显锁定, 选中时说明解释原因; 别的行照常能改
func test_row_locked_in_battle_but_still_listed():
	var gc := GameContext.current()
	var old := gc.in_battle
	var r := SettingsSchema.row("growth")
	gc.in_battle = true
	var shown := SettingsSchema.shown_rows("feature").map(func(x): return x["key"])
	var locked_in := SettingsSchema.is_locked(r)
	var speed_locked := SettingsSchema.is_locked(SettingsSchema.row("game_speed"))
	gc.in_battle = false
	var locked_out := SettingsSchema.is_locked(r)
	gc.in_battle = old
	check(shown.has("growth"), "战斗中这一行仍显示")
	check(locked_in, "战斗中锁定")
	check(not locked_out, "不在战斗时可改")
	check(not speed_locked, "别的行 (游戏速度) 战斗中照样能改")


## 面板的改值入口 (左右键 / 翻页 / 点箭头都走 _change): 锁定的行不动设定
func test_panel_change_ignores_locked_row():
	var gc := GameContext.current()
	var old_battle := gc.in_battle
	var old_val = gc.settings.get("growth")
	gc.settings["growth"] = "random"
	gc.in_battle = true
	var panel := SettingsPanel.new()
	panel.gc = gc
	var rows := SettingsSchema.shown_rows()
	panel._n = rows.size()
	panel._sel = rows.map(func(x): return x["key"]).find("growth")
	panel._change(1)
	eq(gc.settings["growth"], "random", "战斗中按右键不改成长")
	gc.in_battle = old_battle
	if old_val == null:
		gc.settings.erase("growth")
	else:
		gc.settings["growth"] = old_val
	panel.free()


## 「还原预设」(主菜单 / 二级菜单) 不动灰显锁定的行: 战斗中按了不能把成长悄悄改回随机; 不在战斗时照常还原
func test_reset_skips_locked_row_in_battle():
	var gc := GameContext.current()
	var old_battle := gc.in_battle
	var old_saved = gc.settings_saved.get("growth")
	var old_eff = gc.settings.get("growth")
	for how in ["all", "group"]:
		gc.in_battle = true
		gc.settings_saved["growth"] = "max"
		gc.settings["growth"] = "max"
		if how == "all":
			SettingsSchema.reset_all(gc)
		else:
			SettingsSchema.reset_group(gc, "feature")
		eq(gc.settings["growth"], "max", "战斗中还原预设 (%s) 不动成长" % how)
		eq(gc.settings_saved["growth"], "max", "存盘层也不动 (%s)" % how)
		gc.in_battle = false
		gc.settings_saved["growth"] = "max"
		gc.settings["growth"] = "max"
		if how == "all":
			SettingsSchema.reset_all(gc)
		else:
			SettingsSchema.reset_group(gc, "feature")
		eq(gc.settings["growth"], "random", "不在战斗时还原回随机 (%s)" % how)
	gc.in_battle = old_battle
	gc.settings_saved["growth"] = old_saved if old_saved != null else "random"
	gc.settings["growth"] = old_eff if old_eff != null else "random"
