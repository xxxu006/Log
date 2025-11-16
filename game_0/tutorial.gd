# tutorial.gd
extends Control

# =========================
# 信号
# =========================
signal tutorial_finished

# =========================
# 节点引用
# =========================
@onready var drag_layer: CanvasLayer = $DragLayer
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var target_slots: HBoxContainer = $MarginContainer/VBoxContainer/TargetSlots
@onready var card_container: HBoxContainer = $MarginContainer/VBoxContainer/CardContainer

# =========================
# 常量与资源
# =========================
enum CARD_TYPE { DAY = 1, MEAL = 2, NIGHT = 3 }
var CARD_TEXTURES := {
	CARD_TYPE.DAY:   load("res://asset/画片/tian/49f25176f8bf1df4784ec4ef0cdf2ae5.png"),
	CARD_TYPE.MEAL:  load("res://asset/画片/47a3e790905de68bcf1133eb04c4d5be.png"),
	CARD_TYPE.NIGHT: load("res://asset/画片/tian/2be2a52d6149c5d6345bb69835659f33.png"),
}
const CORRECT_ORDER: Array[int] = [CARD_TYPE.DAY, CARD_TYPE.MEAL, CARD_TYPE.NIGHT]
var tutorial_audio = load("res://asset/音效/剪辑音.mp3")

# =========================
# 状态变量
# =========================
var card_nodes: Array[Control] = []
var slot_nodes: Array[Control] = []
var slots_content: Array[Control] = []
var auto_play_enabled := true   # true=自动播放，false=手动点击
# 拖拽相关状态
var is_dragging: bool = false
var dragged_card: Control = null
var drag_offset: Vector2
var original_parent: Control # 存储卡片被拖动前的父节点
var original_position: Vector2 # 存储卡片被拖动前的位置

# =========================
# 生命周期
# =========================
func _ready() -> void:
	_setup_slots()
	_setup_cards()
	_reset_cards()

# =========================
# 初始化设置
# =========================
func _setup_slots():
	for i in range(target_slots.get_child_count()):
		var slot = target_slots.get_child(i)
		slot_nodes.append(slot)
		
		# 设置槽位样式
		var style_box = StyleBoxFlat.new()
		style_box.border_width_left = 3
		style_box.border_width_right = 3
		style_box.border_width_top = 3
		style_box.border_width_bottom = 3
		style_box.border_color = Color.WHITE
		style_box.bg_color = Color(0.467, 0.513, 0.516, 0.5)
		slot.add_theme_stylebox_override("panel", style_box)

	slots_content.resize(slot_nodes.size())

func _setup_cards():
	var card_types = [CARD_TYPE.DAY, CARD_TYPE.MEAL, CARD_TYPE.NIGHT]
	
	for i in range(card_types.size()):
		var ctype = card_types[i]
		var texture = CARD_TEXTURES.get(ctype)
		
		var card = TextureRect.new()
		card.texture = texture
		card.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		card.custom_minimum_size = Vector2(270, 200)
		card.set_meta("card_type", ctype)
		# 【修复】使用 Godot 4 的枚举语法
		card.mouse_filter = Control.MouseFilter.MOUSE_FILTER_PASS
		
		card.gui_input.connect(_on_card_gui_input.bind(card))
		
		card_nodes.append(card)
		card_container.add_child(card)

# =========================
# 游戏逻辑
# =========================
func _reset_cards():
	# 【修复1】在重置时，强制清除任何进行中的拖拽状态
	# 这可以防止在拖拽过程中失败导致的状态混乱
	is_dragging = false
	dragged_card = null

	# 清空槽位，并将所有卡片送回卡片容器
	for i in range(slots_content.size()):
		if slots_content[i]:
			# 【修复2】使用 reparent() 而不是 add_child()
			# reparent() 会自动处理从旧父节点（如槽位或DragLayer）的移除
			# 从而彻底避免 "already has a parent" 错误
			slots_content[i].reparent(card_container)
		slots_content[i] = null

	# 打乱卡片顺序
	var shuffled_cards = card_nodes.duplicate()
	shuffled_cards.shuffle()
	
	# 将打乱后的卡片放回容器
	for card in shuffled_cards:
		# 同样，使用 reparent() 更安全
		card.reparent(card_container)
		
	status_label.text = "请将下方的卡片拖拽到上方，按顺序排列：白天 -> 吃饭 -> 晚上"

# =========================
# 拖拽逻辑 (最终统一坐标系版)
# =========================

func _on_card_gui_input(event: InputEvent, card: Control) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			# 【修改】不再传递坐标参数，在函数内部统一获取
			_start_dragging(card)
		else:
			_stop_dragging()

func _start_dragging(card: Control) -> void:
	if is_dragging:
		return
	
	# 保存原始状态
	original_parent = card.get_parent()
	original_position = card.position
	
	# 将卡片移动到 DragLayer
	card.reparent(drag_layer)
	
	is_dragging = true
	dragged_card = card
	card.z_index = 100
	
	# 【关键修复】在 reparent 之后，用统一的 get_global_mouse_position() 计算偏移
	# 此时 card.global_position 已经稳定，并且和 get_global_mouse_position() 在同一坐标系
	drag_offset = card.global_position - get_global_mouse_position()

func _stop_dragging() -> void:
	if not is_dragging or not dragged_card:
		return
	
	dragged_card.z_index = 0
	is_dragging = false
	
	var target_slot = _get_slot_under_mouse()
	
	if target_slot != -1:
		_place_card_in_slot(dragged_card, target_slot)
	else:
		# 返回原始父节点
		dragged_card.reparent(original_parent)
		# 注意：对于 HBoxContainer，position 会被自动管理，所以这里不需要设置
	
	dragged_card = null

func _input(event: InputEvent) -> void:
	if not is_dragging or not dragged_card:
		return
	
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		# 【关键修复】统一使用 get_global_mouse_position()
		var current_pos = get_global_mouse_position()
		dragged_card.global_position = current_pos + drag_offset


# =========================
# 辅助函数
# =========================
func _get_slot_under_mouse() -> int:
	var mouse_pos = get_global_mouse_position()
	for i in range(slot_nodes.size()):
		if slot_nodes[i].get_global_rect().has_point(mouse_pos):
			return i
	return -1

func _place_card_in_slot(card: Control, slot_index: int) -> void:
	var slot_node = slot_nodes[slot_index]
	
	# 【修复4】简化交换逻辑
	# 如果槽位已有卡片，则将其送回主卡片容器
	if slots_content[slot_index]:
		var old_card = slots_content[slot_index]
		old_card.reparent(card_container)
	
	# 将新卡片放入槽位
	card.reparent(slot_node)
	card.position = Vector2.ZERO
	slots_content[slot_index] = card
	
	_check_win_condition()

func _check_win_condition():
	# 检查所有槽位是否都已填满
	for content in slots_content:
		if content == null: return
	
	# 检查顺序是否正确
	for i in range(CORRECT_ORDER.size()):
		if slots_content[i].get_meta("card_type") != CORRECT_ORDER[i]:
			_on_tutorial_fail()
			return
			
	_on_tutorial_success()

func _on_tutorial_success():
	print("教程成功！")
	status_label.text = "顺序正确！"
	Loadmanager.play_sfx(tutorial_audio)
	
	# 禁用所有卡片的交互
	for card in card_nodes:
		card.mouse_filter = Control.MouseFilter.MOUSE_FILTER_IGNORE

		
	await get_tree().create_timer(1.0).timeout
	
	tutorial_finished.emit()
	queue_free()

func _on_tutorial_fail():
	print("教程失败！")
	status_label.text = "顺序不对，请重新尝试！"
	await get_tree().create_timer(1.5).timeout
	_reset_cards()
