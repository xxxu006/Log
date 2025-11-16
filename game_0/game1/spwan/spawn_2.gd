extends Node2D

# 配置参数
@export var spawn_textures: Array[Texture2D]
@export var red_icon_chance: float = 0.3
@export var move_speed: float = 170.0

# 节点引用
@onready var path: Path2D = $SpawnArea1
@onready var cursor_area: Area2D = $Cursor
@onready var display_node: Node = $DisplayNode

# 图标管理
var icons: Array = []  # 存储所有图标数据 {node: PathFollow2D, is_red: bool, texture: Texture2D}
const ICON_SPACING = 400
var can_spawn = true
var path_length: float = 0.0
var current_displayed_icon: Area2D = null
# 游戏状态
var game_time = 0.0
var game_duration = 60  # 30秒游戏时间
var game_active = false

# 信号定义
signal _game_success
signal _game_failed

func _ready():
	# 计算路径长度
	if path and path.curve:
		path_length = path.curve.get_baked_length()
		print("路径长度: ", path_length)

	# 设置碰撞检测
	cursor_area.collision_layer = 2
	cursor_area.collision_mask = 2
	cursor_area.area_entered.connect(_on_cursor_area_entered)
	cursor_area.area_exited.connect(_on_cursor_area_exited) 
	# 开始游戏
	start_game()

func start_game():
	game_active = true
	game_time = 0.0
	can_spawn = true
	
	# 清空现有图标
	for icon_data in icons:
		icon_data.node.queue_free()
	icons.clear()
	
	print("游戏开始！坚持30秒获胜")

# 添加一个新变量
var spawn_timer = 0.0
var spawn_interval = 1.5  # 生成间隔（秒）

func _process(delta):
	if !game_active:
		return
	
	# 更新游戏时间
	game_time += delta
	
	# 检查游戏是否成功
	if game_time >= game_duration:
		game_success()
		return
	
	# 生成新图标 - 基于时间和最后一个图标的位置
	if can_spawn:
		if icons.size() == 0:
			# 如果没有图标，立即生成一个
			_spawn_icon()
		else:
			var last_icon = icons.back()
			var last_position = last_icon.node.progress
			
			# 只有当最后一个图标移动了足够远时才生成新图标
			if last_position >= ICON_SPACING:
				_spawn_icon()
	
	# 移动所有图标
	var to_remove = []  # 存储需要移除的图标的索引
	
	for i in range(icons.size()):
		var icon_data = icons[i]
		icon_data.node.progress += move_speed * delta
		
		# 检查是否到达终点
		if icon_data.node.progress_ratio >= 1.0:
			to_remove.append(i)
	
	# 从后往前移除图标，避免索引问题
	for i in range(to_remove.size() - 1, -1, -1):
		_handle_icon_reach_end(to_remove[i])
func _spawn_icon():
	if spawn_textures.is_empty():
		return
	
	# 随机选择纹理和颜色
	var texture = spawn_textures[randi() % spawn_textures.size()]
	var is_red = randf() < red_icon_chance
	
	# 创建路径跟随器
	var path_follow = PathFollow2D.new()
	path.add_child(path_follow)
	
	# 创建图标区域
	var area = Area2D.new()
	# 设置碰撞层和掩码，确保与 cursor_area 匹配
	area.collision_layer = 2
	area.collision_mask = 2
	path_follow.add_child(area)
	
	# 创建碰撞形状
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = texture.get_size() * 0.8  # 稍微缩小碰撞区域，确保更容易触发
	collision.shape = shape
	area.add_child(collision)
	
	# 创建精灵
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.name = "IconSprite"
	
	# 如果图像方向不正确，可以尝试翻转
	sprite.flip_v = true  # 如果需要垂直翻转
	sprite.flip_h = true  # 如果需要水平翻转
	
	# 如果是红色图标，添加红色叠加效果
	if is_red:
		# 只使用 modulate 添加红色色调，不使用 ColorRect 避免重叠
		sprite.modulate = Color(2.008, 0.0, 0.0, 0.867)  # 更明显的红色调
	
	area.add_child(sprite)
	
	# 设置初始位置
	path_follow.progress = 0.0
	
	# 设置元数据
	area.set_meta("is_red", is_red)
	area.set_meta("texture", texture)
	area.set_meta("hit_cursor", false)
	
	# 为红色图标添加点击检测
	if is_red:
		area.input_event.connect(_on_red_icon_clicked.bind(area))
		area.mouse_entered.connect(_on_icon_mouse_entered.bind(area))
		area.mouse_exited.connect(_on_icon_mouse_exited.bind(area))
		area.input_pickable = true
	
	# 添加到图标列表
	icons.append({
		"node": path_follow,
		"is_red": is_red,
		"texture": texture,
		"area": area
	})
	
	print("生成图标，红色: ", is_red, " 图标数量: ", icons.size(), " 游戏时间: ", game_time)
func _remove_icon(index: int):
	if index < 0 or index >= icons.size():
		return
	
	var icon_data = icons[index]
	
	# 播放消失动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(icon_data.area, "scale", Vector2.ZERO, 0.2)
	tween.tween_property(icon_data.area, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): 
		icon_data.node.queue_free()
		icons.remove_at(index)
	).set_delay(0.2)

func _on_red_icon_clicked(_viewport, event, _shape_idx, area):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 找到并移除红色图标
		for i in range(icons.size()):
			if icons[i].area == area:
				_remove_icon(i)
				print("成功消除红色图标")
				return

func _on_cursor_area_entered(area: Area2D):
	# 首先检查这个area是否有必要的meta数据
	if not area.has_meta("is_red") or not area.has_meta("hit_cursor"):
		return  # 如果不是图标区域，直接返回
	
	# 检查是否已经处理过这个区域
	if area.get_meta("hit_cursor", false):
		return
	
	# 获取精灵
	var sprite = area.get_node_or_null("IconSprite")
	if not sprite or not sprite.texture:
		return
	
	# 标记为已处理
	area.set_meta("hit_cursor", true)
	
	# 更新当前显示的图标
	current_displayed_icon = area
	
	# 将纹理传递给display_node并展示
	_display_texture(sprite.texture)
	
	# 检查是否是红色图标
	if area.get_meta("is_red"):
		# 红色图标到达检测区 - 游戏失败
		print("游戏失败！红色图标到达检测区111")
		game_failed()
	else:
		# 普通图标到达检测区 - 只显示，不移除
		print("普通图标到达检测区，显示但不移除")

		
func _display_texture(texture: Texture2D):
	if not display_node:
		return
	
	# 强制显示，确保可见
	if display_node is TextureRect:
		display_node.texture = texture
		display_node.visible = true
		print("显示纹理: ", texture.resource_path.get_file())
	elif display_node is Label:
		display_node.text = "显示: " + texture.resource_path.get_file()
		display_node.visible = true
		
func _on_cursor_area_exited(area: Area2D):
	# 检查是否是图标区域
	if not area.has_meta("is_red") or not area.has_meta("hit_cursor"):
		return
	
	# 如果离开的图标是当前显示的图标
	if area == current_displayed_icon:
		# 查找下一个在 area 内的图标
		var next_icon = null
		for icon_data in icons:
			var icon_area = icon_data.area
			if icon_area.has_meta("is_red") and icon_area.overlaps_area(cursor_area) and icon_area != area:
				next_icon = icon_area
				break
		
		if next_icon:
			# 显示下一个图标的纹理
			var sprite = next_icon.get_node_or_null("IconSprite")
			if sprite and sprite.texture:
				current_displayed_icon = next_icon
				_display_texture(sprite.texture)
		else:
			# 没有其他图标在 area 内，隐藏显示
			current_displayed_icon = null
			_hide_display()
func _hide_display():
	if not display_node:
		return
	
	if display_node is TextureRect:
		display_node.visible = false
		print("隐藏显示节点")
	elif display_node is Label:
		display_node.text = ""
		display_node.visible = false
		
func _handle_icon_reach_end(index: int):
	if index < 0 or index >= icons.size():
		return
	
	var icon_data = icons[index]
	
	# 检查是否是红色图标
	if icon_data.is_red:
		# 红色图标到达终点 - 游戏失败
		print("游戏失败！红色图标到达终点111")
		game_failed()
	else:
		# 普通图标到达终点 - 显示并移除
		_display_texture(icon_data.texture)
		_remove_icon(index)
			
			


func game_success():
	game_active = false
	can_spawn = false
	
	# 清空所有图标
	for icon_data in icons:
		icon_data.node.queue_free()
	icons.clear()
	current_displayed_icon = null
	_hide_display()
	emit_signal("_game_success")

func game_failed():
	game_active = false
	can_spawn = false
	
	# 清空所有图标
	for icon_data in icons:
		icon_data.node.queue_free()
	icons.clear()
	current_displayed_icon = null
	_hide_display()
	emit_signal("_game_failed")

func _on_icon_mouse_entered(area: Area2D):
	if area.get_meta("is_red"):
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_icon_mouse_exited(area: Area2D):
	if area.get_meta("is_red"):
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
