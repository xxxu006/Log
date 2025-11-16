extends PanelContainer

func _ready():
	# 确保可以接收鼠标事件
	# 初始状态下可能隐藏或禁用
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# 连接点击信号
	gui_input.connect(_on_gui_input)
	
# 当关键词收集完成时调用
func _on_keywords_collected():
	# 显示面板，允许玩家点击
	visible = true
func _on_gui_input(event):
	# 检测鼠标左键点击
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 检查关键词数量是否达到5个
		pass
