# SPDX-License-Identifier: GPL-3.0-only
class_name WalkStyle
extends RefCounted
## 走路的位置画法: 内置开关 (不放进设定面板)。
##   SMOOTH = true  (缺省): 位置匀速滑动 (用户 2026-11-01 嫌原版那种一步一顿不舒服)
##   SMOOTH = false: 原版步进, 位置随行走帧分 3 步跳 (原版实测: 横向每帧 +10、竖向每帧 +8 原版像素)
## 只改看到的位置, 不改节拍 (战场每格 6 tick / 城镇每格 10 tick)、每格用时和逻辑坐标。
const SMOOTH := true

## 测试用: 0 / 1 强制平滑 / 原版步进 (-1 = 用 SMOOTH); 用完要还原成 -1
static var override := -1


static func smooth() -> bool:
	if override >= 0:
		return override == 0
	return SMOOTH
