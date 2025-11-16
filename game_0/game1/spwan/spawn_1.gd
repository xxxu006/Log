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
@export var lane_y: float = 0.0
@export var card_width: float = 300.0
@export var card_height: float = 225.0
@export var move_speed: float = 180.0
@export var spawn_interval_range := Vector2(0.35, 0.90)
@export var spawn_chance: float = 0.85
@export var max_cards_on_lane: int = 12
@export var right_margin: float = 200.0
@export var left_despawn_x: float = -600.0

# 顺序校验：1->2->3 循环
var expected_next: int = CARD_TYPE.DAY

# 信号
signal game_failed
signal game_success

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
@onready var spawn_path: Path2D = $SpawnArea1
@onready var cursor_area: Area2D = $Cursor

# 存储所有卡牌的数组
var all_cards: Array = []

# 在_ready函数中添加光标区域检查
func _ready() -> void:
	rng.randomize()
	_generate_new_deck()
	_schedule_next_spawn()

	# 确保光标区域有碰撞形状
	if is_instance_valid(cursor_area):
		# 检查是否有碰撞形状，如果没有则添加一个
		if cursor_area.get_child_count() == 0 or not (cursor_area.get_child(0) is CollisionShape2D):
			var collision_shape = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = Vector2(50, 50)  # 适当的大小
			collision_shape.shape = shape
			cursor_area.add_child(collision_shape)
			print("为光标区域添加碰撞形状")
		drag_scale_tween = create_tween()
		drag_scale_tween.kill() # 先停止，等需要时再使用
		cursor_area.collision_layer = 4
		cursor_area.collision_mask = 2
		
		cursor_area.body_entered.connect(_on_body_entered_cursor)
		cursor_area.area_entered.connect(_on_area_entered_cursor)
	
	print("游戏初始化完成，期望的第一个类型: ", _get_card_type_name(expected_next))
	print("胜利条件：坚持30秒")

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
			_game_success()
	
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

	# 从当前牌组获取卡牌类型
	var ctype: int = _get_card_from_deck()
	
	# 创建卡牌节点
	var card := _create_card_node(ctype)
	
	# 设置初始位置
	var lane = _get_path_lane_info()
	var start_x = _calculate_spawn_position(lane)
	var y_on_lane = lane.y
	
	card.global_position = Vector2(start_x, y_on_lane)
	
	# 添加到场景和管理数组
	add_child(card)
	all_cards.append(card)


# 优化生成位置计算，避免初始重叠
func _calculate_spawn_position(_lane: Dictionary) -> float:
	if all_cards.is_empty():
		# 没有卡牌时，从右侧边界开始
		return get_viewport_rect().size.x + card_width * 0.5
	else:
		# 找到最右侧的卡牌
		var rightmost_x = -INF
		for card in all_cards:
			if card != dragged_card:  # 排除拖拽中的卡牌
				rightmost_x = max(rightmost_x, card.global_position.x)
		
		# 如果没找到有效卡牌，使用默认位置
		if rightmost_x == -INF:
			rightmost_x = get_viewport_rect().size.x
		
		# 在最右侧卡牌的右边生成，确保有足够间距
		var new_x = rightmost_x + card_width * 1.2
		
		return new_x
func _create_card_node(ctype: int) -> Node2D:
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
	
	# 保存类型信息
	holder.set_meta("card_type", ctype)
	
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
		if now - press_time >= 200 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
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
	
	print("开始拖拽: ", _get_card_type_name(card.get_meta("card_type")))

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
		area_node.collision_layer = 2  # 恢复碰撞层
	
	# 确保卡牌回到轨道上
	var lane = _get_path_lane_info()
	dragged_card.global_position.y = lane.y
	
	# 检查是否与其他卡牌重叠，如果有则轻微调整位置
	_resolve_final_overlap(dragged_card)
	
	print("结束拖拽: ", _get_card_type_name(dragged_card.get_meta("card_type")))
	
	# 重要：清除拖拽状态
	is_dragging = false
	dragged_card = null
# 解决拖拽结束后的重叠问题
func _resolve_final_overlap(card: Node2D) -> void:
	var cards = all_cards.duplicate()
	cards.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	
	var card_idx := cards.find(card)
	if card_idx == -1:
		return
	
	# 检查与左侧卡牌的重叠
	if card_idx > 0:
		var left_card = cards[card_idx - 1]
		var overlap_left = (left_card.global_position.x + card_width * 0.5) - (card.global_position.x - card_width * 0.5)
		if overlap_left > 0:
			card.global_position.x += overlap_left + 5  # 轻微调整，避免刚好接触
	
	# 检查与右侧卡牌的重叠
	if card_idx < cards.size() - 1:
		var right_card = cards[card_idx + 1]
		var overlap_right = (card.global_position.x + card_width * 0.5) - (right_card.global_position.x - card_width * 0.5)
		if overlap_right > 0:
			card.global_position.x -= overlap_right + 5  # 轻微调整，避免刚好接触

# 修改 _handle_dragging 函数
func _handle_dragging() -> void:
	if not is_dragging or not dragged_card:
		return
	
	var mouse_pos = get_global_mouse_position()
	var lane = _get_path_lane_info()
	
	# 直接使用鼠标位置，让卡牌紧贴鼠标
	dragged_card.global_position = Vector2(
		clampf(mouse_pos.x, lane.min_x - 8.0, lane.max_x + 8.0),
		mouse_pos.y
	)
# =========================
# 卡牌移动和自动排列
# =========================
func get_card_nodes() -> Array:
	return all_cards.duplicate()

func get_card_count() -> int:
	return all_cards.size()

func _get_path_lane_info() -> Dictionary:
	if not is_instance_valid(spawn_path) or spawn_path.curve.get_point_count() < 2:
		var vy := global_position.y
		return { "y": vy, "min_x": -INF, "max_x": INF }
	var p0 := spawn_path.curve.get_point_position(0)
	var pn := spawn_path.curve.get_point_position(spawn_path.curve.get_point_count() - 1)
	var g0 := spawn_path.to_global(p0)
	var gn := spawn_path.to_global(pn)
	var y_lane := lane_y if lane_y != 0.0 else g0.y
	var min_x = min(g0.x, gn.x)
	var max_x = max(g0.x, gn.x)
	return { "y": y_lane, "min_x": min_x, "max_x": max_x }

func _auto_move_cards(delta: float) -> void:
	for card in all_cards:
		# 跳过正在拖拽的卡牌
		if card == dragged_card:
			continue
		card.global_position.x -= move_speed * delta
	
	# 自动排列非拖拽卡牌，避免重叠
	_auto_arrange_cards()

# 自动排列卡牌，避免重叠
func _auto_arrange_cards() -> void:
	var cards = all_cards.duplicate()
	
	# 过滤掉正在拖拽的卡牌
	var non_dragged_cards = []
	for card in cards:
		if card != dragged_card:
			non_dragged_cards.append(card)
	
	# 按X坐标排序
	non_dragged_cards.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	
	# 确保卡牌之间有足够间距
	for i in range(non_dragged_cards.size() - 1):
		var current_card = non_dragged_cards[i]
		var next_card = non_dragged_cards[i + 1]
		
		var desired_gap = card_width * 0.9  # 稍微小于卡牌宽度的间距
		var current_gap = next_card.global_position.x - current_card.global_position.x
		
		if current_gap < desired_gap:
			# 轻微调整位置，避免重叠
			var adjustment = (desired_gap - current_gap) * 0.1  # 使用较小的调整系数
			next_card.global_position.x += adjustment

func _despawn_outside() -> void:
	var cards_to_remove = []
	for card in all_cards:
		if card.global_position.x < left_despawn_x:
			cards_to_remove.append(card)
	
	for card in cards_to_remove:
		all_cards.erase(card)
		card.queue_free()

func _on_body_entered_cursor(_body: Node) -> void:
	pass

func _on_area_entered_cursor(area: Area2D) -> void:
	if game_completed:
		return
		
	print("检测到卡牌进入光标区域!")
	
	var card := area.get_parent()
	if not (card is Node2D) or not card.has_meta("card_type"):
		print("无效的卡牌节点")
		return
		
	var ctype := int(card.get_meta("card_type", 0))
	if ctype == 0:
		print("卡牌类型无效")
		return
	
	print("卡牌类型: ", _get_card_type_name(ctype), " 期望类型: ", _get_card_type_name(expected_next))
	
	if ctype != expected_next:
		print("游戏失败：顺序错误")
		emit_signal("game_failed")
		return
		
	# 更新期望的下一个类型
	expected_next = _next_expected(expected_next)
	
	print("命中正确：", _get_card_type_name(ctype), " 下一个期望: ", _get_card_type_name(expected_next))

# 游戏胜利
func _game_success() -> void:
	if game_completed:
		return
		
	emit_signal("game_success")

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
