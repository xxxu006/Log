extends Button


# 节点引用
@export var panel: Panel   # 替换为你的Panel节点路径
@export var close_button: TextureButton   # 替换为你的关闭按钮路径
@export var mask:ColorRect 

# 动画参数
var slide_speed: float = 0.3  # 滑动动画时长（秒）
var panel_visible_position: Vector2  # 面板可见时的位置
var panel_hidden_position: Vector2  # 面板隐藏时的位置

func _ready():
	# 初始化面板位置
	initialize_panel_positions()
	add_to_group("interactive_ui")
	# 连接按钮信号
	pressed.connect(_on_open_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)

func initialize_panel_positions():
	# 获取面板的原始位置（可见位置）
	panel_visible_position = panel.position
	
	# 计算隐藏位置（屏幕下方）
	var screen_height = get_viewport_rect().size.y
	panel_hidden_position = Vector2(
		panel_visible_position.x,
		screen_height
	)
	
	# 初始状态：面板隐藏
	panel.position = panel_hidden_position
	panel.visible = false
	mask.visible = false

func _on_open_button_pressed():
	# 显示面板
	panel.visible = true
	mask.visible = true
	
	# 创建遮罩淡入动画
	var mask_tween = create_tween()
	mask_tween.set_ease(Tween.EASE_OUT)
	mask_tween.set_trans(Tween.TRANS_CUBIC)
	mask.modulate.a = 0  # 初始完全透明
	mask_tween.tween_property(mask, "modulate:a", 1.0, slide_speed/2)
	
	# 创建滑动动画
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "position", panel_visible_position, slide_speed)

func _on_close_button_pressed():
	# 创建滑动动画
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "position", panel_hidden_position, slide_speed)
	
	# 创建遮罩淡出动画
	var mask_tween = create_tween()
	mask_tween.set_ease(Tween.EASE_IN)
	mask_tween.set_trans(Tween.TRANS_CUBIC)
	mask_tween.tween_property(mask, "modulate:a", 0.0, slide_speed/2)
	
	# 动画完成后隐藏面板
	tween.tween_callback(_hide_panel)

func _hide_panel():
	panel.visible = false
	mask.visible = false
