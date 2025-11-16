extends NinePatchRect

var last_viewport_size := Vector2.ZERO

func _process(delta: float) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	
	# 只有当视口尺寸发生变化时才更新背景
	if viewport_size != last_viewport_size:
		last_viewport_size = viewport_size
		
		# 将尺寸设置为视口的1.25倍
		self.size = viewport_size * 1
