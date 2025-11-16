extends Control

# 节点引用
@export var panel: Panel  # 设置面板
@export var mask: ColorRect   # 遮罩层
@export var close_button: Button   # 关闭按钮

# 动画参数
var slide_speed: float = 0.3
var panel_visible_position: Vector2
var panel_hidden_position: Vector2

	
func _ready():
	# 使用 call_deferred 确保在合适的时机执行
	initialize_panel_positions()
	call_deferred("hide")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	panel.position = panel_hidden_position
	panel.visible = false
	mask.visible = false
	
	
	
func initialize_panel_positions():
	# 获取面板的原始位置（可见位置）
	panel_visible_position = panel.position if panel else Vector2.ZERO
	
	# 计算隐藏位置（屏幕下方）
	var screen_height = get_viewport_rect().size.y
	panel_hidden_position = Vector2(
		panel_visible_position.x,
		screen_height
	)
func hide_setting():
	# 如果没有必要的节点，使用简单的隐藏
	if not panel or not mask:
		hide()
		return
	
	
	# 创建面板滑动动画
	var panel_tween = create_tween()
	panel_tween.set_ease(Tween.EASE_IN)
	panel_tween.set_trans(Tween.TRANS_CUBIC)
	panel_tween.tween_property(panel, "position", panel_hidden_position, slide_speed)
	
	# 创建遮罩淡出动画
	var mask_tween = create_tween()
	mask_tween.set_ease(Tween.EASE_IN)
	mask_tween.set_trans(Tween.TRANS_CUBIC)
	mask_tween.tween_property(mask, "modulate:a", 0.0, slide_speed/2)
	
	# 动画完成后隐藏面板和遮罩
	panel_tween.tween_callback(_hide_elements)
	
func show_setting():
	# 如果没有必要的节点，使用简单的显示
	if not panel or not mask:
		show()
		return
	
	show()
	
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

func _hide_elements():
	if panel:
		panel.visible = false
	if mask:
		mask.visible = false
	hide()

func _on_button_pressed():
	hide_setting()
