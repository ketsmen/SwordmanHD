# SPDX-License-Identifier: GPL-3.0-only
class_name KeyRepeat
extends RefCounted
## 方向键按住连发 (纯逻辑, 便于无头测试)。节拍取原版 实测 (差异): 战场光标与营地主菜单按住方向键时,
## 第一格立即走, 之后每 5 个游戏 tick (0.2 秒, 25 tick/秒) 一格, 没有初始延迟 (间隔稳定 0.20 秒)。原先取自重制版 (按住 0.5 秒后 0.1 秒一格, GameBattleInput.cs:150-167) 与原版不符。
## 同时按住多个方向时以最后按下的为准, 松开它后回到仍按住的上一个方向 (重新计时)。
## press()/release() 返回本次要发出的动作 (首次按下发一次, 非 echo); tick(dt) 返回到点的连发动作 (echo)。

const HOLD := 0.2     # 按下后第一次连发的等待 (= 一个 5 tick 节拍)
const REPEAT := 0.2   # 之后每格的间隔
const MAX_PER_TICK := 2   # 一帧最多补发几次: 窗口被拖住/卡顿后一次 dt 很大时, 不能一口气连发几十下 (光标飞走、对白连翻)

var _held: Array = []   # 按下顺序的方向动作 (UiAction.UP...)
var _age := {}          # 方向动作 -> 已按住的秒数 (tick 的 dt 累加, 调用方传真实时间就是真实按住时长)
var _ids := {}          # 方向动作 -> 这一次按下的序号 (每次 press 递增; 区分「还是同一次按住」与「松开后重新按」)
var _serial := 0
var _t := 0.0
var _repeating := false


func press(kind: int) -> Array:
	if kind in _held:
		return []
	_held.append(kind)
	_serial += 1
	_ids[kind] = _serial
	_age[kind] = 0.0
	_t = 0.0
	_repeating = false
	return [kind]


func release(kind: int) -> void:
	var was_top: bool = not _held.is_empty() and _held[-1] == kind
	_held.erase(kind)
	_ids.erase(kind)
	_age.erase(kind)
	if was_top:
		_t = 0.0
		_repeating = false


func clear() -> void:
	_held.clear()
	_ids.clear()
	_age.clear()
	_t = 0.0
	_repeating = false


## 当前按住的全部方向 (按下顺序)
func held() -> Array:
	return _held.duplicate()


## 这个方向已按住多少秒 (没按住 -1)。tick 传真实 dt 时就是真实按住时长: 城镇走路用它区分「点按」和「按住」(见 TownHeroGait.HOLD_GATE)
func age(kind: int) -> float:
	return float(_age.get(kind, -1.0))


## 这个方向当前这次按下的序号 (没按住 0); 松开再按序号变
func press_id(kind: int) -> int:
	return int(_ids.get(kind, 0))


## 当前按住的方向 (最后按下的); 没有为 UiAction.NONE
func current() -> int:
	return _held[-1] if not _held.is_empty() else UiAction.NONE


## 经过 dt 秒: 返回需要发出的连发动作 (都是 current() 方向)。
## interval = 本界面该方向的连发间隔 (秒): 缺省 0.2 (5 帧); 切人/换栏动作做完动画才再读键, 间隔更长
func tick(dt: float, interval := REPEAT) -> Array:
	if _held.is_empty():
		return []
	for k in _age:
		_age[k] += dt
	_t += dt
	var out: Array = []
	if not _repeating:
		if _t < interval:
			return out
		_repeating = true
		_t -= interval
		out.append(current())
	while _t >= interval and out.size() < MAX_PER_TICK:
		_t -= interval
		out.append(current())
	if _t >= interval:
		_t = 0.0  # 丢掉补不完的 (整段卡顿的余量不接着补; 用 fmod 会有浮点误差多补一次)
	return out
