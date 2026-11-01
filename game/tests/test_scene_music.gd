# SPDX-License-Identifier: GPL-3.0-only
extends "res://tests/test_base.gd"
## 场景音乐通道的暂停 / 继续 / 淡入 (原版 0x2D / 0x2E / 0x2C 的 arg: 0 = 硬暂停 / 立即继续, 1 = 25/127 <-> 满音量 2.08 秒线性渐变; 静态观察 S0)。


func _make() -> Array:
	var host := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var m := SceneMusic.new(host)
	var p := AudioStreamPlayer.new()
	p.stream = AudioStreamGenerator.new()
	host.add_child(p)
	p.play()
	m._players[0] = p
	return [host, m, p]


func test_hard_pause_and_resume_are_immediate():
	var t := _make()
	var m: SceneMusic = t[1]
	var p: AudioStreamPlayer = t[2]
	m.pause(0, true, 0)
	check(p.stream_paused, "arg=0 硬暂停立即生效")
	m.pause(0, false, 0)
	check(not p.stream_paused, "arg=0 立即继续")
	check(is_equal_approx(p.volume_db, 0.0), "继续是全音量")
	t[0].free()


func test_fade_pause_keeps_playing_until_the_fade_ends():
	var t := _make()
	var m: SceneMusic = t[1]
	var p: AudioStreamPlayer = t[2]
	m.pause(0, true, 1)
	check(not p.stream_paused, "arg=1 淡出期间还在播, 淡出完才真暂停")
	check(p.has_meta("fade_tween"), "起了淡出渐变")
	p.stream_paused = true   # 假装淡出完了
	m.pause(0, false, 1)
	check(not p.stream_paused, "继续")
	check(is_equal_approx(p.volume_db, linear_to_db(SceneMusic.FADE_LOW)), "arg=1 继续从 25/127 起淡入")
	t[0].free()


func test_fade_constants_match_original_steps():
	eq(SceneMusic.FADE_SECS, 26 * 2 * 0.04, "26 步 x 2 tick x 0.04 秒")
	check(is_equal_approx(SceneMusic.FADE_LOW, 25.0 / 127.0), "低音量 25/127")
