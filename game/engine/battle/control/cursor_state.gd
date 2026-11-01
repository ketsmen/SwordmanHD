# SPDX-License-Identifier: GPL-3.0-only
class_name CursorState
extends BattleState
## 2.1 光标自由移动 (无选中单位), 依据 GameBattleInput.updateCursor:
##   确认: 格上有我方未行动单位 -> 选中 (移动范围); 敌方 / 友军 / 已行动 -> 直接弹大属性窗 (悬停已显示预览范围); 空地 -> 系统菜单。
##   取消: 光标跳到下一个未行动的我方单位 (从上次行动/巡视的单位往后找, 循环)。**不结束回合**。
##   菜单 (屏幕按钮 / M): 打开系统菜单 (扩展, 等同在空地确认)。


func _init() -> void:
	cursor_mode = true


func enter() -> void:
	resume()


func resume() -> void:
	c.sel = null
	c.show_cursor()
	c.hover_resume()   # 取消选中后停留计数还在, 约 6 tick 预览又出现 (原版实测 R1-5)


func confirm() -> void:
	var u: BattleUnit = c.rules.unit_at(c.cur)
	if u == null:
		c.push(SystemMenuState.new())
	elif u.controllable and c.rules.can_start_action(u):
		c.select_unit(u)   # 我方未行动: 选中 (移动范围, 之后行动菜单)
	else:
		# 敌方 / 友军 / 已行动 / 不能行动的单位: 确认直接弹大的属性窗 (玩家反馈 2026-11-01); 悬停时已经显示了它的移动范围预览, 不再多一步选中
		c.hover_clear()
		c.open_detail(u)


func cancel() -> void:
	c.cycle_next_unit()


func on_menu() -> void:
	c.push(SystemMenuState.new())


## 原版 F2 (状态 0): 战场地图 (MAP_VIE), 与系统菜单「地圖」同一窗口
func on_f2() -> bool:
	c.push(WindowState.new(WindowState.MAP))
	return true
