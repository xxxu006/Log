extends Sprite2D

# 定义信号
signal area_clicked(area_name)
signal following_cancelled 
signal non_bug_clicked
@onready var glass = $Glass

# 控制变量
var is_dragging = false
var touch_mode = false
var drag_offset = Vector2.ZERO

# 手机触摸相关变量
var current_touch_index = -1

func _ready():
	hide()
	set_process_input(false)

func _input(event):
	# --- 手机触摸处理 ---
	if event is InputEventScreenTouch:
		handle_touch_event(event)
	elif event is InputEventScreenDrag:
		handle_drag_event(event)
	
	# --- 鼠标处理 ---
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 鼠标按下，开始拖拽
			if not is_dragging:
				start_dragging(get_viewport().get_mouse_position())
		else:
			# 鼠标松开，进行点击判定
			if is_dragging:
				handle_click_at_position(get_viewport().get_mouse_position())
	
	# 鼠标移动时更新位置
	elif event is InputEventMouseMotion and is_dragging:
		position = event.position + drag_offset

# 处理触摸事件
func handle_touch_event(event):
	if event.pressed:
		# 触摸开始，开始拖拽
		if not is_dragging:
			current_touch_index = event.index
			start_dragging(event.position)
	else:
		# 触摸结束，进行点击判定
		if is_dragging and event.index == current_touch_index:
			handle_click_at_position(event.position)

# 处理拖拽事件
func handle_drag_event(event):
	# 只有在拖拽状态下，并且是当前跟踪的手指，才更新位置
	if is_dragging and event.index == current_touch_index:
		position = event.position + drag_offset

# 开始拖拽
func start_dragging(start_pos: Vector2):
	is_dragging = true
	
	# 计算拖拽偏移量 - 这是关键！
	# 让放大镜保持在点击的相对位置
	drag_offset = position - start_pos
	
	show()
	set_process_input(true)
	
	print("开始拖拽放大镜")

# 处理点击判定（通用函数）
func handle_click_at_position(click_pos):
	# 停止拖拽
	stop_dragging()
	
	# 使用 Glass 节点的中心位置进行检测，而不是点击位置
	var detection_pos
	if is_instance_valid(glass):
		# 使用 Glass 节点的全局位置
		detection_pos = glass.global_position
		print("使用 Glass 节点中心检测，位置: ", detection_pos)
	else:
		# 备用：使用原始点击位置
		detection_pos = click_pos
		print("Glass 节点无效，使用点击位置检测: ", detection_pos)
	
	# 坐标转换！
	# detection_pos 是视口坐标，物理检测需要世界坐标
	var world_pos = get_viewport().canvas_transform.affine_inverse() * detection_pos
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos # 使用转换后的世界坐标
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1 # 确保 BugArea 的 collision layer 与此 mask 匹配
	var result = space_state.intersect_point(query, 1)
	
	if result.size() > 0:
		var clicked_area = result[0].collider
		if clicked_area.name.begins_with("BugArea"):
			# 找到了BUG,发出信号停止
			print("Magnifier: 找到BUG: ", clicked_area.name)
			area_clicked.emit(clicked_area.name)
			get_viewport().set_input_as_handled()
			return
	
	# 点击到非BUG区域或空白处
	print("Magnifier: 点击到非BUG区域")
	following_cancelled.emit()
	non_bug_clicked.emit()
	get_viewport().set_input_as_handled()

# 停止拖拽
func stop_dragging():
	if not is_dragging:
		return
	
	is_dragging = false
	current_touch_index = -1
	drag_offset = Vector2.ZERO
	hide()
	
	set_process_input(false)
	
	print("停止拖拽放大镜")

func start_following():
	var viewport_size = get_viewport().get_visible_rect().size
   
	global_position = Vector2(viewport_size.x - 325, 290)
	show()
	set_process_input(true)

func stop_following():
	stop_dragging()

# 设置触摸模式
func set_touch_mode(enabled):
	touch_mode = enabled
