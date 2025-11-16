extends Node

func _ready():
	Jsonload._ready()
	# 确保按钮状态正常
	_ensure_button_connections()

func _ensure_button_connections():
	# 检查按钮信号连接，如果没有连接则重新连接
	var button =$HBoxContainer/Button
	if button and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)
	
	var button2 = $HBoxContainer/Button2
	if button2 and not button2.pressed.is_connected(_on_button_2_pressed):
		button2.pressed.connect(_on_button_2_pressed)
	
	var button3 =$HBoxContainer/Button3
	if button3 and not button3.pressed.is_connected(_on_button_3_pressed):
		button3.pressed.connect(_on_button_3_pressed)


func _on_button_pressed() -> void:
	Jsonload.reset_game_state()
	Loadmanager.load_scene('res://level/scenes/exploration_hub.tscn')


func _on_button_2_pressed() -> void:
	get_node("setting").show_setting()


func _on_button_3_pressed() -> void:
		# 1. 保存游戏数据
	Gamemanager.quit_game()
