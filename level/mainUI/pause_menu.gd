# pause_menu.gd
extends Control

signal resume_requested
signal settings_requested
signal main_requested

var confirm_dialog

# 节点引用
@export var panel: Panel  # 设置面板
@export var mask: ColorRect   # 遮罩层

# 动画参数
var slide_speed: float = 0.3
var panel_visible_position: Vector2
var panel_hidden_position: Vector2

@onready var continue_button = %ContinueButton
@onready var settings_button = %SettingsButton
@onready var main_button = %MainButton

func _ready():
	initialize_panel_positions()
	# 使用 call_deferred 确保在合适的时机执行
	call_deferred("hide")
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	panel.position = panel_hidden_position
	panel.visible = false
	mask.visible = false
	
	# 加载弹窗场景
	var dialog_scene = preload("res://level/mainUI/CustomConfirmDialog.tscn")
	confirm_dialog = dialog_scene.instantiate()
	add_child(confirm_dialog)
	
	# 确保弹窗默认隐藏
	confirm_dialog.hide()
	
	# 连接弹窗信号
	confirm_dialog.confirmed.connect(_on_dialog_confirmed)
	confirm_dialog.cancelled.connect(_on_dialog_cancelled)
	
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
	if main_button:
		main_button.pressed.connect(_on_main_button_pressed)

func _on_continue_button_pressed():
	resume_requested.emit()

func _on_settings_button_pressed():
	settings_requested.emit()

func _on_main_button_pressed():
	# 显示确认弹窗
	confirm_dialog.show_dialog()

func _on_dialog_cancelled():
	# 用户选择继续游戏，不需要做任何事
	pass

func _on_dialog_confirmed():
	# 用户确认离开，发出主界面请求
	main_requested.emit()

func initialize_panel_positions():
	# 获取面板的原始位置（可见位置）
	panel_visible_position = panel.position if panel else Vector2.ZERO
	
	# 计算隐藏位置（屏幕下方）
	var screen_height = get_viewport_rect().size.y
	panel_hidden_position = Vector2(
		panel_visible_position.x,
		screen_height
	)

func show_menu():
	show()
	get_tree().paused = true
	# 显示遮罩和面板
	mask.visible = true
	panel.visible = true
	
	# 创建遮罩淡入动画
	var mask_tween = create_tween()
	mask_tween.set_ease(Tween.EASE_OUT)
	mask_tween.set_trans(Tween.TRANS_CUBIC)
	mask.modulate.a = 0  # 初始完全透明
	mask_tween.tween_property(mask, "modulate:a", 1.0, slide_speed/2)
	
	# 创建面板滑动动画
	var panel_tween = create_tween()
	panel_tween.set_ease(Tween.EASE_OUT)
	panel_tween.set_trans(Tween.TRANS_CUBIC)
	panel_tween.tween_property(panel, "position", panel_visible_position, slide_speed)
	print("显示暂停面板成功")
	
func hide_menu():
	print("触发隐藏暂停面板")
	# 创建面板滑动动画
	var panel_tween = create_tween()

	panel_tween.set_ease(Tween.EASE_IN)
	panel_tween.set_trans(Tween.TRANS_CUBIC)
	panel_tween.tween_callback(func(): print("   panel 动画开始")).set_delay(0)
	panel_tween.tween_property(panel, "position", panel_hidden_position, slide_speed)
	
	# 创建遮罩淡出动画
	var mask_tween = create_tween()
	mask_tween.set_ease(Tween.EASE_IN)
	mask_tween.set_trans(Tween.TRANS_CUBIC)
	mask_tween.tween_property(mask, "modulate:a", 0.0, slide_speed/2)
	mask_tween.tween_callback(func(): print("   mask 动画完成"))
	# 动画完成后隐藏面板和遮罩
	panel_tween.tween_callback(_hide_elements)
	
func _hide_elements():
	if panel:
		panel.visible = false
		print("隐藏成功")
	if mask:
		mask.visible = false
	hide()
	get_tree().paused = false
