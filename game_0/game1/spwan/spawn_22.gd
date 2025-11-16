extends Node2D

# 配置参数
@export var spawn_textures: Array[Texture2D]
@export var move_speed: float = 170.0
@export var min_spawn_interval: float = 3.0  # 最小生成间隔（秒）
@export var max_spawn_interval: float = 6.0  # 最大生成间隔（秒）

# 节点引用
@onready var path: Path2D = $SpawnArea1
@onready var cursor_area: Area2D = $Cursor

# 图标管理
var icons: Array = []  # 存储所有图标数据 {node: PathFollow2D, texture: Texture2D, area: Area2D}
var can_spawn = true
var path_length: float = 0.0

# 游戏状态
var game_time = 0.0
var game_duration = 60  # 60秒游戏时间
var game_active = false

# 生成计时器
var spawn_timer = 0.0
var next_spawn_time = 0.0

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
	
	# 开始游戏
	start_game()

func start_game():
	game_active = true
	game_time = 0.0
	can_spawn = true
	spawn_timer = 0.0
	next_spawn_time = _get_random_spawn_interval()
	
	# 清空现有图标
	for icon_data in icons:
		icon_data.node.queue_free()
	icons.clear()
	
	print("游戏开始！坚持60秒获胜")

func _get_random_spawn_interval() -> float:
	return randf_range(min_spawn_interval, max_spawn_interval)

func _process(delta):
	if !game_active:
		return
	
	# 更新游戏时间
	game_time += delta
	
	# 检查游戏是否成功
	if game_time >= game_duration:
		game_success()
		return
	
	# 生成新图标 - 基于随机时间间隔
	if can_spawn:
		spawn_timer += delta
		if spawn_timer >= next_spawn_time:
			_spawn_icon()
			spawn_timer = 0.0
			next_spawn_time = _get_random_spawn_interval()
	
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
	
	# 随机选择纹理（所有图标都是红色的）
	var texture = spawn_textures[randi() % spawn_textures.size()]
	
	# 创建路径跟随器
	var path_follow = PathFollow2D.new()
	path.add_child(path_follow)
	
	# 创建图标区域
	var area = Area2D.new()
	# 设置碰撞层和掩码，确保与 cursor_area 匹配
	area.collision_layer = 2
	area.collision_mask = 2
	area.add_to_group("red_icons")
	
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
	
	# 所有图标都是红色的
	sprite.modulate = Color(2.008, 0.0, 0.0, 0.867)  # 红色调
	
	area.add_child(sprite)
	
	# 设置初始位置
	path_follow.progress = 0.0
	
	# 设置元数据
	area.set_meta("texture", texture)
	
	# 为图标添加点击检测（所有图标都需要被点击）
	area.input_event.connect(_on_icon_clicked.bind(area))
	area.mouse_entered.connect(_on_icon_mouse_entered.bind(area))
	area.mouse_exited.connect(_on_icon_mouse_exited.bind(area))
	area.input_pickable = true
	
	# 添加到图标列表
	icons.append({
		"node": path_follow,
		"texture": texture,
		"area": area
	})
	
	print("生成红色图标，图标数量: ", icons.size(), " 游戏时间: ", game_time)

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

func _on_icon_clicked(_viewport, event, _shape_idx, area):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 找到并移除图标
		for i in range(icons.size()):
			if icons[i].area == area:
				_remove_icon(i)
				print("成功消除红色图标")
				return

@warning_ignore("unused_parameter")
func _on_cursor_area_entered(area: Area2D):
	if !game_active:
		return
	
	# 只处理属于"red_icons"组的区域
	if area.is_in_group("red_icons"):
		# 红色图标到达检测区 - 游戏失败
		print("游戏失败！红色图标到达检测区")
		game_failed()
func _handle_icon_reach_end(index: int):
	if index < 0 or index >= icons.size():
		return
	
	# 红色图标到达终点 - 游戏失败
	print("游戏失败！红色图标到达终点")
	game_failed()

func game_success():
	game_active = false
	can_spawn = false
	
	# 清空所有图标
	for icon_data in icons:
		icon_data.node.queue_free()
	icons.clear()
	emit_signal("_game_success")

func game_failed():
	game_active = false
	can_spawn = false
	
	# 清空所有图标
	for icon_data in icons:
		icon_data.node.queue_free()
	icons.clear()
	emit_signal("_game_failed")

@warning_ignore("unused_parameter")
func _on_icon_mouse_entered(area: Area2D):
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

@warning_ignore("unused_parameter")
func _on_icon_mouse_exited(area: Area2D):
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
