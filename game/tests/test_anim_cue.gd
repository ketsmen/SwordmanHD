# SPDX-License-Identifier: GPL-3.0-only
extends "res://tests/test_base.gd"
## 剧情 anim_start (0x1A): 原版跳转 -> -> (槽位, 帧): 只把动画槽定格到第 arg 帧并发该帧的声音,
## 不开显示标志、不推进后面的帧 (数据里 97 处用法的帧都没有部件, 纯音效触发; 关卡 13 的 Eanm_19 有 2 个有声帧, 关卡 20 / 21 的 Eanm_05 / Eanm_04 有 3 个)。
## 回归: 复刻原先把整段动画放出来, 后面几个帧的声音也响 (14 处多发声)。合成数据, 无原版资源也跑。


func _fake_ok() -> bool:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Assets") != null


func _fake_voiced(key: String, n: int) -> void:
	var A = (Engine.get_main_loop() as SceneTree).root.get_node("Assets")
	var frames := []
	for i in n:
		frames.append({"sound": 0, "time": 2, "hit": 0, "color": 0, "shake": 0, "unk4": 0, "parts": []})
	A._anims[key.to_lower()] = {"frames": frames, "action_counts": [], "textures": [], "sounds": [], "dir": key}
	A._index[(key + "/anim.json").to_lower()] = true


func _unfake(key: String) -> void:
	var A = (Engine.get_main_loop() as SceneTree).root.get_node("Assets")
	A._anims.erase(key.to_lower())
	A._index.erase((key + "/anim.json").to_lower())


func test_cue_plays_only_the_given_frame_sound_without_showing_or_playing():
	if not _fake_ok():
		check(true, "无资源, 跳过")
		return
	var key := "Stage/test_cue/Eanm_01"
	_fake_voiced(key, 3)
	var a := AnimPlayer.new()
	a.dir = key
	a.visible = false
	a.cue_frame_sound(0)
	eq(a.sfx_count, 1, "只响第 0 帧的一声 (不是 3 个有声帧全响)")
	a.cue_frame_sound(2)
	eq(a.sfx_count, 2, "定格到第 2 帧再响一声")
	check(not a.playing, "不推进 (没有开始播放)")
	check(not a.visible, "不改显示标志")
	eq(a.frame, -1, "不显示任何帧")
	a.free()
	_unfake(key)


func test_cue_without_animation_data_is_silent():
	if not _fake_ok():
		check(true, "无资源, 跳过")
		return
	var a := AnimPlayer.new()
	a.dir = "Stage/test_cue/NoSuchAnim"
	a.cue_frame_sound(0)
	eq(a.sfx_count, 0, "没有这份动画 (载入失败) 不报错不发声")
	a.free()
