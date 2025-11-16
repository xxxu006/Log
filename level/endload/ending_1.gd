extends Control

@onready var ending_image: TextureRect =$HBoxContainer/TextureRect
@onready var ending_name: Label = $HBoxContainer/VBoxContainer/Label
@onready var locked_overlay: ColorRect = $LockedOverlay

# 添加自定义变量来跟踪解锁状态
var is_unlocked: bool = false

func setup(ending_data: Dictionary):
	# 设置结局图片
	var texture = load(ending_data["gallery_image"])
	if texture:
		ending_image.texture = texture
	
	# 设置结局名称
	ending_name.text = ending_data["name"]
	
	# 根据解锁状态设置显示
	is_unlocked = ending_data.get("unlocked", false)
	if is_unlocked:
		locked_overlay.hide()
		# 允许鼠标交互
		mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		locked_overlay.show()
		# 阻止鼠标交互
		mouse_filter = Control.MOUSE_FILTER_IGNORE

# 如果需要处理点击，添加一个信号
signal ending_selected

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and is_unlocked:
			ending_selected.emit()
			print("显示结局详情: ", ending_name.text)
