extends Node2D

# =========================
# 常量与资源
# =========================
enum CARD_TYPE { DAY = 1, MEAL = 2, NIGHT = 3 }

var CARD_TEXTURES := {
	CARD_TYPE.DAY:   load("res://asset/画片/tian/49f25176f8bf1df4784ec4ef0cdf2ae5.png") if ResourceLoader.exists("res://asset/画片/tian/49f25176f8bf1df4784ec4ef0cdf2ae5.png") else null,
	CARD_TYPE.MEAL:  load("res://asset/画片/47a3e790905de68bcf1133eb04c4d5be.png") if ResourceLoader.exists("res://asset/画片/47a3e790905de68bcf1133eb04c4d5be.png") else null,
	CARD_TYPE.NIGHT: load("res://asset/画片/tian/2be2a52d6149c5d6345bb69835659f33.png") if ResourceLoader.exists("res://asset/画片/tian/2be2a52d6149c5d6345bb69835659f33.png") else null,
}
# 轨道参数
@export var lane1_y: float = 0.0
@export var lane2_y: float = 150.0
@export var card_width: float = 300.0
@export var card_height: float = 225.0
@export var move_speed: float = 220.0
@export var spawn_interval_range := Vector2(0.8, 2.3)
@export var spawn_chance: float = 0.85
@export var max_cards_on_lane: int = 12
@export var right_margin: float = 200.0
@export var left_despawn_x: float = -600.0
@export var drag_follow_speed: float = 300.0  # 拖拽跟随速度
# 顺序校验：1->2->3 循环
var expected_next: int = CARD_TYPE.DAY

# 信号
signal _game_failed
signal _game_success

# 运行时变量
var spawn_timer := 0.0
var next_spawn_time := 1.5
var rng := RandomNumberGenerator.new()

# 游戏计时器
var game_timer := 0.0
var game_duration := 30.0  # 30秒胜利条件
var game_completed := false

# 牌组系统
var current_deck: Array = []  # 当前牌组
var deck_index := 0  # 当前牌组中的索引

# 拖拽相关 - 使用长按系统
var dragged_card: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var card_press_times := {}  # 存储卡牌按下时间 {card: press_time}
var drag_scale_tween: Tween

# 节点引用
@onready var spawn_path1: Path2D = $SpawnArea1
@onready var spawn_path2: Path2D = $SpawnArea2
@onready var cursor_area1: Area2D = $SpawnArea1/Cursor
@onready var cursor_area2: Area2D = $SpawnArea2/Cursor2

# 存储所有卡牌的数组
var all_cards: Array = []
var card_path_progress := {}
# 在_ready函数中添加光标区域检查
func _ready() -> void:
	rng.randomize()
	_generate_new_deck()
	_schedule_next_spawn()
	
	# 初始化两个光标区域
	_init_cursor_area(cursor_area1)
	_init_cursor_area(cursor_area2)
	
	# 连接光标区域的信号
	if is_instance_valid(cursor_area1):
		cursor_area1.area_entered.connect(_on_area_entered_cursor1)
	if is_instance_valid(cursor_area2):
		cursor_area2.area_entered.connect(_on_area_entered_cursor2)
# 初始化光标区域
func _init_cursor_area(cursor_area: Area2D) -> void:
	if is_instance_valid(cursor_area):
		# 检查是否有碰撞形状，如果没有则添加一个
		if cursor_area.get_child_count() == 0 or not (cursor_area.get_child(0) is CollisionShape2D):
			var collision_shape = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = Vector2(50, 50)  # 适当的大小
			collision_shape.shape = shape
			cursor_area.add_child(collision_shape)
			print("为光标区域添加碰撞形状")
		
		cursor_area.collision_layer = 4
		cursor_area.collision_mask = 2
		

# 生成新的牌组（只包含三张不同类型的卡牌）
func _generate_new_deck() -> void:
	current_deck.clear()
	deck_index = 0
	
	# 创建包含所有三种类型的数组
	var all_types = [CARD_TYPE.DAY, CARD_TYPE.MEAL, CARD_TYPE.NIGHT]
	
	# 只添加三种类型各一张
	current_deck = all_types.duplicate()
	
	# 随机打乱
	_shuffle_deck()
	
	print("生成新牌组: ", _get_deck_string())

# 从牌组中获取下一张卡牌
func _get_card_from_deck() -> int:
	# 如果牌组已用完，重新生成三张牌组
	if deck_index >= current_deck.size():
		_generate_new_deck()
		print("重新生成牌组: ", _get_deck_string())
	
	# 获取当前卡牌并移动到下一张
	var card_type = current_deck[deck_index]
	deck_index += 1
	
	print("从牌组取牌: ", _get_card_type_name(card_type), "，牌组剩余: ", current_deck.size() - deck_index)
	
	return card_type

# 随机打乱牌组
func _shuffle_deck() -> void:
	for i in range(current_deck.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = current_deck[i]
		current_deck[i] = current_deck[j]
		current_deck[j] = temp

# 获取牌组的字符串表示（用于调试）
func _get_deck_string() -> String:
	var result = []
	for card_type in current_deck:
		result.append(_get_card_type_name(card_type))
	return "[" + ", ".join(result) + "]"

func _process(delta: float) -> void:
	# 更新游戏计时器
	if not game_completed:
		game_timer += delta
		if game_timer >= game_duration:
			game_success()
	
	# 自动生成卡牌
	_handle_spawning(delta)
	
	# 处理长按拖拽检测
	_handle_long_press_drag()
	
	# 自动移动非拖拽卡牌
	_auto_move_cards(delta)
	
	# 处理拖拽
	_handle_dragging()
	
	# 清理离场卡牌
	_despawn_outside()

# =========================
# 卡牌生成 - 牌组系统
# =========================
func _handle_spawning(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= next_spawn_time:
		spawn_timer = 0.0
		_schedule_next_spawn()
		_try_spawn_card()

func _schedule_next_spawn() -> void:
	next_spawn_time = rng.randf_range(spawn_interval_range.x, spawn_interval_range.y)

func _try_spawn_card() -> void:
	if rng.randf() < 0.25:
		return
	
	# 从当前牌组获取卡牌类型
	var ctype: int = _get_card_from_deck()
	
	# 随机选择轨道
	var use_lane2 = rng.randf() < 0.4
	
	# 创建卡牌节点
	var card := _create_card_node(ctype, use_lane2)
	
	# 设置初始位置 - 使用路径信息
	var lane_info = _get_path_lane_info(use_lane2)
	
	if lane_info.use_path and lane_info.path:
		# 使用路径生成：将卡牌放在路径起点
		var curve = lane_info.path.curve
		var first_point = curve.get_point_position(0)
		card.global_position = lane_info.path.to_global(first_point)
		
		# 不设置初始旋转
		# 初始化路径进度
		card_path_progress[card] = 0.0
		print("使用路径生成卡牌，轨道: ", (2 if use_lane2 else 1), " 路径起点: ", card.global_position)
	else:
		# 回退到原来的生成逻辑
		var start_x = _calculate_spawn_position(lane_info, use_lane2)
		var y_on_lane = lane_info.y
		card.global_position = Vector2(start_x, y_on_lane)
		print("使用直线生成卡牌，轨道: ", (2 if use_lane2 else 1), " 位置: ", card.global_position)
	
	# 添加到场景和管理数组
	add_child(card)
	all_cards.append(card)


func _calculate_spawn_position(lane_info: Dictionary, use_lane2: bool) -> float:
	# 优先使用路径的最右点作为生成位置
	var base_x = lane_info.max_x
	
	# 如果同轨道上已经有卡牌，确保新卡牌生成在最右侧卡牌的右边
	var rightmost_x = -INF
	for card in all_cards:
		if card != dragged_card and card.get_meta("lane") == (2 if use_lane2 else 1):
			rightmost_x = max(rightmost_x, card.global_position.x)
	
	# 如果已有卡牌的最右侧位置比路径最右点更靠右，则使用卡牌位置+间距
	if rightmost_x != -INF and rightmost_x + card_width * 0.6 > base_x:
		return rightmost_x + card_width * 1.2
	
	# 否则使用路径最右点
	return base_x
func _create_card_node(ctype: int, use_lane2: bool) -> Node2D:
	var sprite := Sprite2D.new()
	sprite.texture = CARD_TEXTURES.get(ctype, null)
	sprite.centered = true
	sprite.name = "CardSprite"

	var area := Area2D.new()
	area.name = "CardArea"  # 给Area2D一个明确的名称
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(card_width, card_height)
	shape.shape = rect_shape
	area.add_child(shape)
	
	# 设置碰撞层和掩码，确保能与光标区域交互
	area.collision_layer = 2
	area.collision_mask = 2

	var holder := Node2D.new()
	holder.name = "Card"
	holder.add_child(sprite)
	holder.add_child(area)
	
	# 保存类型信息和轨道信息
	holder.set_meta("card_type", ctype)
	holder.set_meta("lane", 2 if use_lane2 else 1)
	
	# 连接输入事件
	area.input_event.connect(_on_card_input_event.bind(holder))
	area.mouse_entered.connect(_on_card_mouse_entered.bind(holder))
	area.mouse_exited.connect(_on_card_mouse_exited.bind(holder))
	
	return holder

# =========================
# 鼠标悬停效果
# =========================
func _on_card_mouse_entered(card: Node2D) -> void:
	# 鼠标进入卡牌区域时，变暗
	if card != dragged_card:
		card.modulate = Color(0.7, 0.7, 0.7)

func _on_card_mouse_exited(card: Node2D) -> void:
	# 鼠标离开卡牌区域，恢复颜色
	if card != dragged_card:
		card.modulate = Color(1, 1, 1)

# =========================
# 长按拖拽系统 - 修复节点引用问题
# =========================
func _on_card_input_event(_viewport: Object, event: InputEvent, _shape_idx: int, card: Node2D) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 记录按下时间
			card_press_times[card] = Time.get_ticks_msec()
		else:
			# 清除按下时间
			if card_press_times.has(card):
				card_press_times.erase(card)

func _handle_long_press_drag() -> void:
	var now := Time.get_ticks_msec()
	
	# 检查是否有卡牌达到长按时间
	for card in card_press_times.keys():
		var press_time = card_press_times[card]
		if now - press_time >= 150 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			# 开始拖拽
			_start_dragging(card)
			card_press_times.erase(card)
			break
	
	# 如果正在拖拽但鼠标左键已释放，停止拖拽
	if is_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_dragging()

# 修改 _start_dragging 函数
func _start_dragging(card: Node2D) -> void:
	if is_dragging:
		return
		
	is_dragging = true
	dragged_card = card
	
	# 抓取动画 - 轻微放大
	var tween = create_tween()
	tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.1)
	
	# 计算拖拽偏移
	var mouse_pos = get_global_mouse_position()
	drag_offset = card.global_position - mouse_pos
	
	# 提高层级确保在最上面
	card.z_index = 100
	
	# 尝试获取Area2D节点，如果获取不到则跳过碰撞检测设置
	var area_node = card.get_node_or_null("CardArea")
	if area_node and area_node is Area2D:
		area_node.monitorable = false
		area_node.monitoring = false
		area_node.collision_layer = 0  # 拖拽时禁用碰撞
	
	print("开始拖拽: ", _get_card_type_name(card.get_meta("card_type")), " 从轨道: ", card.get_meta("lane"))

func _stop_dragging() -> void:
	if not is_dragging or not dragged_card:
		return
	
	# 放下动画 - 恢复原大小
	var tween = create_tween()
	tween.tween_property(dragged_card, "scale", Vector2(1.0, 1.0), 0.15)
	
	# 重置层级
	dragged_card.z_index = 0
	
	# 尝试恢复碰撞检测
	var area_node = dragged_card.get_node_or_null("CardArea")
	if area_node and area_node is Area2D:
		area_node.monitorable = true
		area_node.monitoring = true
		area_node.collision_layer = 2
	
	# 检查卡牌最终位置，确定所在轨道
	var final_lane = _determine_lane_from_position(dragged_card.global_position.y)
	dragged_card.set_meta("lane", final_lane)
	
	# 如果卡牌被放回到有路径的轨道，重新绑定到路径
	var use_lane2 = (final_lane == 2)
	var lane_info = _get_path_lane_info(use_lane2)
	
	if lane_info.use_path and lane_info.path:
		# 计算卡牌在路径上的最近点
		var closest_progress = _find_closest_path_progress(lane_info.path, dragged_card.global_position)
		card_path_progress[dragged_card] = closest_progress
		print("拖拽后重新绑定到路径，进度: ", closest_progress)
	else:
		# 如果没有路径，确保卡牌回到正确的轨道Y坐标
		dragged_card.global_position.y = lane_info.y
		# 移除路径进度
		if card_path_progress.has(dragged_card):
			card_path_progress.erase(dragged_card)
			print("拖拽后移除路径进度，使用直线移动")
	
	# 检查是否与其他卡牌重叠，如果有则轻微调整位置
	_resolve_final_overlap(dragged_card)
	
	print("结束拖拽: ", _get_card_type_name(dragged_card.get_meta("card_type")), " 到轨道: ", final_lane)
	
	# 重要：清除拖拽状态
	is_dragging = false
	dragged_card = null
func _find_closest_path_progress(path: Path2D, world_pos: Vector2) -> float:
	var curve = path.curve
	var curve_length = curve.get_baked_length()
	
	var closest_progress = 0.0
	var min_distance = INF
	
	# 在路径上采样多个点，找到最近的点
	var sample_count = 20  # 减少采样点以提高性能
	for i in range(sample_count + 1):
		var progress = i / float(sample_count)
		var path_point = curve.sample_baked(progress * curve_length)
		var global_pt = path.to_global(path_point)
		var distance = global_pt.distance_to(world_pos)
		
		if distance < min_distance:
			min_distance = distance
			closest_progress = progress
	
	return closest_progress

# 根据Y坐标确定卡牌所在的轨道
func _determine_lane_from_position(y: float) -> int:
	var lane1_info = _get_path_lane_info(false)
	var lane2_info = _get_path_lane_info(true)
	
	# 计算到两条轨道的距离
	var dist_to_lane1 = abs(y - lane1_info.y)
	var dist_to_lane2 = abs(y - lane2_info.y)
	
	# 选择距离更近的轨道
	if dist_to_lane1 <= dist_to_lane2:
		return 1
	else:
		return 2

# 解决拖拽结束后的重叠问题
func _resolve_final_overlap(card: Node2D) -> void:
	var cards_on_same_lane = []
	for c in all_cards:
		if c != card and c.get_meta("lane") == card.get_meta("lane"):
			cards_on_same_lane.append(c)
	
	cards_on_same_lane.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	
	var card_idx := -1
	for i in range(cards_on_same_lane.size()):
		if cards_on_same_lane[i].global_position.x > card.global_position.x:
			card_idx = i
			break
	
	if card_idx == -1:
		card_idx = cards_on_same_lane.size()
	
	# 检查与左侧卡牌的重叠
	if card_idx > 0:
		var left_card = cards_on_same_lane[card_idx - 1]
		var overlap_left = (left_card.global_position.x + card_width * 0.5) - (card.global_position.x - card_width * 0.5)
		if overlap_left > 0:
			card.global_position.x += overlap_left + 5  # 轻微调整，避免刚好接触
	
	# 检查与右侧卡牌的重叠
	if card_idx < cards_on_same_lane.size():
		var right_card = cards_on_same_lane[card_idx]
		var overlap_right = (card.global_position.x + card_width * 0.5) - (right_card.global_position.x - card_width * 0.5)
		if overlap_right > 0:
			card.global_position.x -= overlap_right + 5  # 轻微调整，避免刚好接触

# 修改 _handle_dragging 函数
func _handle_dragging() -> void:
	if not is_dragging or not dragged_card:
		return
	
	var mouse_pos = get_global_mouse_position()
	# 直接设置位置，避免lerp在移动设备上的累积误差
	dragged_card.global_position = Vector2(
		mouse_pos.x + drag_offset.x,
		mouse_pos.y + drag_offset.y
	)
	## 使用平滑跟随而不是直接设置位置，让拖拽更自然
	#var target_position = Vector2(
		#mouse_pos.x + drag_offset.x,
		#mouse_pos.y + drag_offset.y
	#)
	#
	## 应用平滑跟随
	#dragged_card.global_position = dragged_card.global_position.lerp(target_position, drag_follow_speed * get_process_delta_time())

# =========================
# 卡牌移动和自动排列
# =========================
func get_card_nodes() -> Array:
	return all_cards.duplicate()

func get_card_count() -> int:
	return all_cards.size()

func _get_path_lane_info(use_lane2: bool) -> Dictionary:
	var spawn_path = spawn_path2 if use_lane2 else spawn_path1
	
	if not is_instance_valid(spawn_path) or spawn_path.curve.get_point_count() < 2:
		# 如果路径无效，回退到原来的逻辑
		var lane_y = lane2_y if use_lane2 else lane1_y
		var vy = global_position.y + lane_y
		return { 
			"path": null, 
			"y": vy, 
			"min_x": -INF, 
			"max_x": INF,
			"use_path": false
		}
	
	# 获取路径的起点和终点
	var curve = spawn_path.curve
	var start_point = spawn_path.to_global(curve.get_point_position(0))
	var end_point = spawn_path.to_global(curve.get_point_position(curve.get_point_count() - 1))
	
	return { 
		"path": spawn_path,
		"y": start_point.y, 
		"min_x": min(start_point.x, end_point.x),
		"max_x": max(start_point.x, end_point.x),
		"use_path": true
	}

func _auto_move_cards(delta: float) -> void:
	for card in all_cards:
		# 跳过正在拖拽的卡牌
		if card == dragged_card:
			continue
		
		var card_lane = card.get_meta("lane")
		var use_lane2 = (card_lane == 2)
		var lane_info = _get_path_lane_info(use_lane2)
		
		if lane_info.use_path and lane_info.path and card_path_progress.has(card):
			# 使用路径移动
			_move_card_along_path(card, use_lane2, delta)
		else:
			# 使用直线移动
			var speed_multiplier = 1.0
			if card_lane == 2:
				speed_multiplier = 1.0
			card.global_position.x -= move_speed * speed_multiplier * delta
	
	# 自动排列非拖拽卡牌，避免重叠
	_auto_arrange_cards()
func _move_card_along_path(card: Node2D, use_lane2: bool, delta: float) -> void:
	var spawn_path = spawn_path2 if use_lane2 else spawn_path1
	
	if not is_instance_valid(spawn_path) or not card_path_progress.has(card):
		return
	
	var progress = card_path_progress[card]
	var curve = spawn_path.curve
	
	# 检查曲线是否有足够的点
	if curve.get_point_count() < 2:
		print("路径点不足，使用直线移动")
		card_path_progress.erase(card)
		return
	
	var curve_length = curve.get_baked_length()
	
	if curve_length <= 0:
		print("路径长度为0，使用直线移动")
		card_path_progress.erase(card)
		return
	
	# 计算新的进度
	var distance_to_move = move_speed * delta
	progress += distance_to_move / curve_length
	
	if progress <= 1.0:
		# 获取路径上的位置
		var path_position = curve.sample_baked(progress * curve_length)
		
		# 转换为全局坐标
		var global_pos = spawn_path.to_global(path_position)
		
		# 只更新卡牌位置，不更新旋转
		card.global_position = global_pos
		
		# 更新进度
		card_path_progress[card] = progress
	else:
		# 路径移动完成，切换到直线移动
		card_path_progress.erase(card)
		print("卡牌完成路径移动，切换到直线移动")


# 自动排列卡牌，避免重叠
func _auto_arrange_cards() -> void:
	var cards = all_cards.duplicate()
	
	# 过滤掉正在拖拽的卡牌
	var non_dragged_cards = []
	for card in cards:
		if card != dragged_card:
			non_dragged_cards.append(card)
	
	# 按轨道分组
	var lane1_cards = []
	var lane2_cards = []
	
	for card in non_dragged_cards:
		var lane = card.get_meta("lane")
		if lane == 1:
			lane1_cards.append(card)
		else:
			lane2_cards.append(card)
	
	# 分别对每条轨道的卡牌进行排序和排列
	_arrange_cards_on_lane(lane1_cards)
	_arrange_cards_on_lane(lane2_cards)

# 在单条轨道上排列卡牌
func _arrange_cards_on_lane(cards: Array) -> void:
	# 按X坐标排序
	cards.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	
	# 确保卡牌之间有足够间距
	for i in range(cards.size() - 1):
		var current_card = cards[i]
		var next_card = cards[i + 1]
		
		var desired_gap = card_width * 0.9  # 稍微小于卡牌宽度的间距
		var current_gap = next_card.global_position.x - current_card.global_position.x
		
		if current_gap < desired_gap:
			# 轻微调整位置，避免重叠
			var adjustment = (desired_gap - current_gap) * 0.1  # 使用较小的调整系数
			next_card.global_position.x += adjustment

func _despawn_outside() -> void:
	var cards_to_remove = []
	for card in all_cards:
		# 对于使用路径的卡牌，根据进度判断是否要移除
		if card_path_progress.has(card):
			if card_path_progress[card] > 1.0:
				cards_to_remove.append(card)
		else:
			# 对于直线移动的卡牌，使用原来的判断逻辑
			if card.global_position.x < left_despawn_x:
				cards_to_remove.append(card)
	
	for card in cards_to_remove:
		all_cards.erase(card)
		if card_path_progress.has(card):
			card_path_progress.erase(card)
		card.queue_free()
# 轨道1的光标区域信号处理
func _on_area_entered_cursor1(area: Area2D) -> void:
	_handle_cursor_area_entered(area, cursor_area1)

# 轨道2的光标区域信号处理
func _on_area_entered_cursor2(area: Area2D) -> void:
	_handle_cursor_area_entered(area, cursor_area2)

# 统一处理光标区域进入
func _handle_cursor_area_entered(area: Area2D, cursor_area: Area2D) -> void:
	if game_completed:
		return
		
	print("检测到卡牌进入光标区域!")
	
	# 检查是否是卡牌的Area2D
	if area.name != "CardArea":
		print("不是卡牌区域:", area.name)
		return
	
	var card := area.get_parent()
	if not (card is Node2D) or not card.has_meta("card_type"):
		print("无效的卡牌节点")
		return
		
	var ctype := int(card.get_meta("card_type", 0))
	if ctype == 0:
		print("卡牌类型无效")
		return
	
	# 判断是哪个光标区域
	var is_cursor1 = (cursor_area == cursor_area1)
	var is_cursor2 = (cursor_area == cursor_area2)
	
	if is_cursor1:
		# 轨道1的检测逻辑：按顺序点击
		print("轨道1卡牌类型: ", _get_card_type_name(ctype), " 期望类型: ", _get_card_type_name(expected_next))
		
		if ctype != expected_next:
			print("游戏失败：顺序错误")
			emit_signal("_game_failed")
			return
			
		# 更新期望的下一个类型
		expected_next = _next_expected(expected_next)
		
		print("命中正确：", _get_card_type_name(ctype), " 下一个期望: ", _get_card_type_name(expected_next))
		
	elif is_cursor2:
		# 轨道2的检测逻辑：任何卡牌进入即失败
		print("轨道2卡牌进入，游戏失败：", _get_card_type_name(ctype))
		emit_signal("_game_failed")


# 游戏胜利
func game_success() -> void:
	if game_completed:
		return
		
	game_completed = true
	emit_signal("_game_success")

func _next_expected(now: int) -> int:
	match now:
		CARD_TYPE.DAY:
			return CARD_TYPE.MEAL
		CARD_TYPE.MEAL:
			return CARD_TYPE.NIGHT
		_:
			return CARD_TYPE.DAY

func _get_card_type_name(ctype: int) -> String:
	match ctype:
		CARD_TYPE.DAY:
			return "白天"
		CARD_TYPE.MEAL:
			return "吃饭"
		CARD_TYPE.NIGHT:
			return "晚上"
		_:
			return "未知"
