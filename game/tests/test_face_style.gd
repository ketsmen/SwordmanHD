# SPDX-License-Identifier: GPL-3.0-only
extends "res://tests/test_base.gd"
## 头像风格 (设定 face_style + FacePacks 头像包): 设定行只在装了包时列、选项 = 经典 + 全部已装包、缺省 auto、旧值 hk 兼容、非法值回退;
## Assets 只在风格选了某个头像包且包里有这一帧时才改读包里的头像, 其余 (经典 / 没有这一帧 / 非头像 / 原版画质) 一律用 hd4x。

var _old_dirs := {}
var _old_style := ""
var _old_gfx := ""
var _tmp := []


## 测试运行器没有 before/after 钩子: 每个测试开头 _save(), 末尾 _restore()
func _save() -> void:
	_old_dirs = FacePacks.dirs
	_old_style = Assets.face_style
	_old_gfx = Assets.gfx


func _restore() -> void:
	FacePacks.dirs = _old_dirs
	Assets.face_style = _old_style
	Assets.gfx = _old_gfx
	for p in _tmp:
		_rm(p)
	_tmp = []


func _rm(p: String) -> void:
	for f in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))
	for d in DirAccess.get_directories_at(p):
		_rm(p.path_join(d))
	DirAccess.remove_absolute(p)


## 造一个头像包目录 (含 Face/Face05/t0.webp), 返回目录
func _pack(name: String, info := "") -> String:
	var dir := OS.get_user_data_dir().path_join("test_face_%s_%d" % [name, Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(dir.path_join("Face/Face05"))
	var fa := FileAccess.open(dir.path_join("Face/Face05/t0.webp"), FileAccess.WRITE)
	fa.store_8(0)
	fa = null   # 关文件: 只需要它存在
	if info != "":
		var fi := FileAccess.open(dir.path_join("info.json"), FileAccess.WRITE)
		fi.store_string(info)
		fi = null
	_tmp.append(dir)
	return dir


func test_setting_default_and_sanitize():
	_save()
	var a := _pack("a")
	var b := _pack("b")
	FacePacks.dirs = {"face_hk": a, "face_b": b}
	eq(SettingsSchema.defaults()["face_style"], "auto", "头像风格缺省 auto (装了包就用第一个包, 没装则经典)")
	eq(SettingsSchema.sanitize({"face_style": "face_b"})["face_style"], "face_b", "已装的包合法")
	eq(SettingsSchema.sanitize({"face_style": "hk"})["face_style"], "face_hk", "旧版存的 hk = face_hk")
	eq(SettingsSchema.sanitize({"face_style": "classic"})["face_style"], "classic", "经典合法")
	eq(SettingsSchema.sanitize({"face_style": "xxx"})["face_style"], "auto", "没装的包 / 非法值回退缺省")
	eq(SettingsSchema.sanitize({"face_style": 3})["face_style"], "auto", "类型不对回退缺省")
	eq(SettingsSchema.sanitize({})["face_style"], "auto", "旧设定文件没有这个键: 取缺省")
	_restore()


func test_row_listed_only_with_a_pack():
	_save()
	check(not SettingsSchema._need_ok("face_pack", false, false, false), "没装头像包不列")
	check(SettingsSchema._need_ok("face_pack", false, false, true), "装了头像包才列")
	eq(String(SettingsSchema.row("face_style").get("needs", "")), "face_pack", "行声明了 needs face_pack")
	FacePacks.dirs = {}
	check(not FacePacks.available(), "没装")
	FacePacks.dirs = {"face_x": "res://x"}
	check(FacePacks.available(), "装了一个")
	_restore()


func test_options_list_every_installed_pack():
	_save()
	FacePacks.dirs = {"zz_last": _pack("z", '{"name": "尾包"}'), "face_hk": _pack("h"), "aa_other": _pack("o")}
	var ids := []
	for o in SettingsSchema.options_of(SettingsSchema.row("face_style")):
		ids.append(o["v"])
	eq(ids, ["classic", "face_hk", "aa_other", "zz_last"], "经典 + 全部已装包 (face_hk 在前, 其余按名字排)")
	eq(SettingsSchema.text_of("face_style", "face_hk"), "港漫", "官方包的名字来自文案表")
	eq(SettingsSchema.text_of("face_style", "zz_last"), "尾包", "没有文案的包取包自带的 info.json")
	eq(SettingsSchema.text_of("face_style", "aa_other"), "aa_other", "什么名字都没有显示包 id")
	eq(SettingsSchema.text_of("face_style", "auto"), "港漫", "auto 显示成它实际指的那项")
	eq(SettingsSchema.step("face_style", "classic", 1), "face_hk", "右键: 经典 -> 第一个包")
	eq(SettingsSchema.step("face_style", "zz_last", 1), "classic", "最后一个包右键回到经典")
	eq(SettingsSchema.step("face_style", "classic", -1), "zz_last", "左键: 经典 -> 最后一个包")
	eq(SettingsSchema.step("face_style", "auto", 1), "aa_other", "auto 先当成它指的那个包再换")
	_restore()


func test_resolve():
	_save()
	FacePacks.dirs = {"face_b": "res://b", "face_a": "res://a"}
	eq(FacePacks.resolve("auto"), "face_a", "没有 face_hk 时 auto 取名字排第一的包")
	eq(FacePacks.resolve("hk"), "classic", "旧值 hk 但 face_hk 没装: 经典")
	FacePacks.dirs["face_hk"] = "res://h"
	eq(FacePacks.resolve("auto"), "face_hk", "有 face_hk 时 auto 取它")
	eq(FacePacks.resolve("hk"), "face_hk", "旧值 hk")
	eq(FacePacks.resolve("face_b"), "face_b", "指定包")
	eq(FacePacks.resolve("gone"), "classic", "指定的包没装: 经典")
	FacePacks.dirs = {}
	eq(FacePacks.resolve("auto"), "classic", "一个包都没装: 经典")
	eq(FacePacks.dir_of("auto"), "", "没有目录")
	_restore()


func test_reserved_ids_are_not_packs():
	_save()
	for id in ["classic", "auto", "hk"]:
		check(FacePacks.reserved(id), id + " 是保留的风格值")
	check(not FacePacks.reserved("face_hk") and not FacePacks.reserved("my_faces"), "普通包名不保留")
	_restore()


func test_scan_dev_dir():
	_save()
	var dev := _pack("dev")
	FacePacks.scan(dev)
	check(FacePacks.dirs.get("face_hk", "") == dev or FacePacks.dirs.get("face_hk", "").begins_with("res://mod/"), "没挂 face_hk 包时开发目录算 face_hk")
	FacePacks.scan("")
	check(FacePacks.dirs.get("face_hk", "") != dev, "不传开发目录不算")
	_restore()


func test_assets_reads_alt_face_only_when_available():
	_save()
	var a := _pack("a")
	var b := _pack("b")
	FacePacks.dirs = {"face_hk": a, "face_b": b}
	Assets.gfx = "hd"
	Assets.face_style = "face_b"
	eq(Assets._face_alt_file("Face/Face05/t0.png"), b.path_join("Face/Face05/t0.webp"), "选了包且包里有: 读那个包的 webp")
	Assets.face_style = "auto"
	eq(Assets._face_alt_file("Face/Face05/t0.png"), a.path_join("Face/Face05/t0.webp"), "auto: 读第一个包")
	Assets.face_style = "hk"
	eq(Assets._face_alt_file("Face/Face05/t0.png"), a.path_join("Face/Face05/t0.webp"), "旧值 hk: 读 face_hk")
	eq(Assets._face_alt_file("Face/Face05/t1.png"), "", "包里没有这一帧: 回退经典")
	eq(Assets._face_alt_file("Stage/Stage01/map01.png"), "", "不是头像: 不碰")
	Assets.gfx = "orig"
	eq(Assets._face_alt_file("Face/Face05/t0.png"), "", "原版画质: 不读")
	Assets.gfx = "hd"
	Assets.face_style = "classic"
	eq(Assets._face_alt_file("Face/Face05/t0.png"), "", "经典风格: 不读")
	Assets.face_style = "face_b"
	FacePacks.dirs = {}
	eq(Assets._face_alt_file("Face/Face05/t0.png"), "", "没有头像包: 回退经典")
	_restore()
