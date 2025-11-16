extends CheckButton
# 1 = 自动播放开，0 = 关
signal auto_play_toggled(enabled: bool)

func _toggled(button_pressed: bool) -> void:
	# CheckButton 的 toggled 信号自带参数：true=按下(开)
	auto_play_toggled.emit(button_pressed)
	print("按钮：自动播放", "开" if button_pressed else "关")
