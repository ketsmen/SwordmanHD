# SPDX-License-Identifier: GPL-3.0-only
class_name FacePacks
extends RefCounted
## 头像包: mod/ 里的包只要带 res://mod/<包内名>/Face/<头像目录>/tN.webp 就是头像包, 设定「头像风格」里自动多一项 (包内名 = 风格 id), 可以装任意多个。
## 缺哪一张头像就退回经典头像 (Assets._face_alt_file); 只在高清画质下生效。包可带 res://mod/<包内名>/info.json {"name": "显示名"} 给设定里的选项起名, 没有就用文案表 settings.face_style.opt.<id>, 再没有就显示包内名。
## 风格值: "classic" 经典 / "auto" (缺省) 第一个头像包, 一个都没装就是经典 / 某个头像包的 id。旧版设定存的 "hk" 等同 face_hk。

const MOD_ROOT := "res://mod"
const CLASSIC := "classic"
const AUTO := "auto"
const LEGACY := {"hk": "face_hk"}   # 旧风格值 -> 包 id
const FIRST := "face_hk"            # 自动选包时排第一 (官方港漫头像包), 其余按名字排

static var dirs := {}   # 已装头像包: id -> 目录 (含 Face/); 开发版 face_hk 可由环境变量 TDJ_FACE_HK 指到目录


## 扫描已挂载的 mod 包 (Assets 启动时调一次); dev_dir = 开发版额外的 face_hk 目录 (没挂包时用), 没有传 ""
static func scan(dev_dir := "") -> void:
	dirs = {}
	var md := DirAccess.open(MOD_ROOT)
	if md != null:
		for n in md.get_directories():
			if not reserved(String(n)) and DirAccess.dir_exists_absolute(MOD_ROOT.path_join(n).path_join("Face")):
				dirs[String(n)] = MOD_ROOT.path_join(n)
	if dev_dir != "" and not dirs.has(FIRST) and DirAccess.dir_exists_absolute(dev_dir.path_join("Face")):
		dirs[FIRST] = dev_dir


## 保留的风格值不能当包 id (classic / auto / 旧值 hk 在 normalize 里另有含义, 同名的包永远选不中, 扫描时直接不收)
static func reserved(id: String) -> bool:
	return id == CLASSIC or id == AUTO or LEGACY.has(id)


static func available() -> bool:
	return not dirs.is_empty()


## 已装头像包 id: face_hk 在前, 其余按名字排
static func ids() -> Array:
	var out := dirs.keys()
	out.sort()
	if out.has(FIRST):
		out.erase(FIRST)
		out.push_front(FIRST)
	return out


## 设定里存的值 -> 合法的风格值 (classic / auto / 已装包 id); 不合法 (不是字符串、包没装) 返回 ""
static func normalize(v) -> String:
	if not v is String:
		return ""
	var s := String(v)
	if s == CLASSIC or s == AUTO:
		return s
	s = String(LEGACY.get(s, s))
	return s if dirs.has(s) else ""


## 风格值实际用哪个: 包 id 或 classic (auto 取第一个包; 包没装也当经典)
static func resolve(style: String) -> String:
	if style == AUTO:
		var all := ids()
		return String(all[0]) if not all.is_empty() else CLASSIC
	var s := String(LEGACY.get(style, style))
	return s if dirs.has(s) else CLASSIC


## 风格值对应的头像目录; 经典 / 没装返回 ""
static func dir_of(style: String) -> String:
	return String(dirs.get(resolve(style), ""))


## 包自带的显示名 (info.json); 没有返回 ""
static func title_of(id: String) -> String:
	var f := String(dirs.get(id, "")).path_join("info.json")
	if not FileAccess.file_exists(f):
		return ""
	var j = JSON.parse_string(FileAccess.get_file_as_string(f))
	return String(j.get("name", "")) if j is Dictionary else ""
