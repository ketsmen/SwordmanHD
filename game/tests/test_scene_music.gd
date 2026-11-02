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


## 过场视频: 放的时候静音, 放完在响的通道接着放 (原版视频不碰音乐通道; 第 30 幕蚩尤视频后剧本不发「继续」, 战斗曲要自己回来)
func test_movie_resumes_music_that_was_playing():
	var t := _make()
	var m: SceneMusic = t[1]
	var p: AudioStreamPlayer = t[2]
	var held := m.stop_all()
	check(not p.playing, "放视频时音乐停")
	eq(held, [0], "记下在响的通道")
	m.resume_held(held)
	check(p.playing and not p.stream_paused, "视频放完接着放")
	m.pause(0, true, 0)
	held = m.stop_all()
	eq(held, [], "剧本暂停着的通道不算在响")
	m.resume_held(held)
	check(not p.playing, "视频放完也不自己响")
	m.pause(0, false, 0)
	check(p.playing, "剧本「继续」照旧从停下处接着放")
	t[0].free()


func test_movie_does_not_resume_channel_fading_out():
	var t := _make()
	var m: SceneMusic = t[1]
	var p: AudioStreamPlayer = t[2]
	m.pause(0, true, 1)   # 剧本先淡出暂停再放视频 (第 19 幕)
	var held := m.stop_all()
	eq(held, [], "淡出暂停中的通道不接着放")
	t[0].free()
