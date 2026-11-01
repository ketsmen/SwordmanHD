# SPDX-License-Identifier: GPL-3.0-only
extends "res://tests/test_base.gd"
## 常驻远景图层 (BattleStage.auto_bg_layers): 原版第 4 幕悬崖外的云海 (map04-1, 图层 2, 尺寸参数 2x2) 一直显示, 没有事件加载它; 被事件加载的远景图仍由事件决定。


func _layer(id: int, u4: int, u5: int) -> Dictionary:
	return {"id": id, "u4": u4, "u5": u5, "z": 0, "layer": -1}


func _op(layer_id: int) -> Dictionary:
	var d := PackedByteArray()
	d.resize(2)
	d.encode_s16(0, layer_id)
	return {"type": 0x23, "data": d}


func test_unreferenced_far_background_is_always_on():
	var s := BattleStage.new()
	s.layers0 = [_layer(1, 10, 8), _layer(2, 2, 2)]
	s.events = [[{"type": 0x16, "data": PackedByteArray()}]]
	eq(s.auto_bg_layers(), [2], "第 4 幕: 云海 (图层 2) 常驻")


func test_event_loaded_background_stays_event_driven():
	var s := BattleStage.new()
	s.layers0 = [_layer(1, 10, 8), _layer(2, 10, 8), _layer(3, 2, 2)]
	s.events = [[_op(2), _op(3)]]
	eq(s.auto_bg_layers(), [], "事件加载的图层 (第 23 幕等) 不常驻")


func test_main_layers_and_layers_with_objects_are_not_auto():
	var s := BattleStage.new()
	s.layers0 = [_layer(1, 10, 8), _layer(1, 2, 2), _layer(2, 10, 8), _layer(3, 2, 2)]
	s.layers1 = [{"id": 3}]
	s.events = []
	eq(s.auto_bg_layers(), [], "主图层 1 本身、10x8 主图、带物件的图层都不算")
