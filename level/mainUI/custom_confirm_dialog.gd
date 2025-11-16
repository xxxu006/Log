# CustomConfirmDialog.gd
extends PopupPanel

signal confirmed
signal cancelled

@onready var continue_button = $MarginContainer/VBoxContainer/HBoxContainer/ContinueButton
@onready var confirm_button = $MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton

func _ready():
	# 连接按钮信号
	continue_button.pressed.connect(_on_continue_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	
	# 设置弹窗大小（通过容器控制）
	size = Vector2(400, 200)

func show_dialog():
	popup_centered()

func _on_continue_pressed():
	cancelled.emit()
	hide()

func _on_confirm_pressed():
	confirmed.emit()
	hide()
