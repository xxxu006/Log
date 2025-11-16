extends HSlider
func _ready():
	# 创建滑动条

	self.min_value = 0.0
	self.step = 0.01
	self.max_value = 1.0
	self.value = 1.0  # 默认音量
	self.size.x = 300  # 设置宽度
	
	self.value = Loadmanager.get_sfx_volume()
	self.value_changed.connect(_on_sfx_volume_changed)
	
func _on_sfx_volume_changed(_value: float):
	Loadmanager.set_sfx_volume(_value)
