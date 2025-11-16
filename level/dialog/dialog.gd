# dialog.gd (修正版，主要是确保其与修复后的DialogueBubble.gd兼容，并增加触摸拖动和滚动条样式)

extends Control

const DialogueBubble = preload("res://level/dialog/DialogueBubble.tscn")

const INTERFERENCE_KEYWORDS = ["流逝", "外卖", "毕业","血糖","咖啡"]  # 定义干扰项列表
# 设置打字音效文件路径

# --- 新增：将样式配置移到这里，方便管理 ---
const STYLES = {
	"Player": {
		"bg_color": Color("cadaf0ff"),           # 浅蓝色背景
		"text_color": Color("363c42ff"),         # 深蓝色文字
		"font_size": 30
	},
	"Patient": {
		"bg_color": Color("ffffffff"),           # 灰色背景
		"text_color": Color("333838ff"),         # 黑色文字
		"font_size": 30
	},
	"default": {
		"bg_color": Color("#fff3e000"),           # 浅橙色背景
		"text_color": Color("000000cd"),         # 深橙色文字
		"font_size": 26
	}
}

# 节点引用
@export var dialogue_container: VBoxContainer
@export var options_container: VBoxContainer
@export var check_btn: Button 
@export var dialogue_scroll_container: ScrollContainer
var is_typing: bool = false
var waiting_for_click: bool = false
var current_typing_bubble: Node = null
var auto_advancing: bool = false
var was_typing_before_pause: bool = false

# 外部可调的自动播放开关
var auto_play_enabled := true      # true = 自动播放下一句，false = 永久等待玩家点击
func _ready():
	_setup_scrollbar()

	Loadmanager.set_typing_sfx("res://asset/音效/打字音.mp3")
	# --- 修改：删除了临时主题设置，因为现在每个气泡自己管理样式 ---
	# 订阅NarrativeManager的所有信号
	NarrativeManager.show_dialogue.connect(_on_NarrativeManager_show_dialogue)
	NarrativeManager.clear_dialogue.connect(clear_existing_dialogue)
	
	set_process_input(true)
	await get_tree().process_frame
	if check_btn:
		check_btn.auto_play_toggled.connect(set_auto_play)
	else:
		push_error("没找到 CheckAutoPlay 按钮！")

func set_auto_play(enable: bool) -> void:
	auto_play_enabled = enable
	print("dialog.gd: 自动播放已", "开启" if enable else "关闭")


func _input(event):
	if get_tree().paused:
		return
	
	# 处理跳过打字 - 优先级最高
	if is_typing and is_instance_valid(current_typing_bubble):
		# 空格/回车跳过打字
		if event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			current_typing_bubble.skip_typing()
			get_viewport().set_input_as_handled()
			return
		
		# 鼠标点击跳过打字（不检查位置，任何点击都可以跳过打字）
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 检查是否点击了UI按钮，如果是则不跳过打字
			if not _is_clicking_ui_button(event):
				current_typing_bubble.skip_typing()
				get_viewport().set_input_as_handled()
				return
	
	# 处理推进对话 - 只在等待点击且不在打字时
	if waiting_for_click and not is_typing:
		# 空格/回车推进对话
		if event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			# 如果进入了自由探索，回车键不应触发下一步
			if NarrativeManager.is_in_free_explore:
				print("dialog.gd: 在自由探索模式，回车键和空格键被禁用。")
				get_viewport().set_input_as_handled()
				return
			
			waiting_for_click = false
			print("dialog.gd: 玩家按回车/空格，请求 NarrativeManager 处理下一步。")
			NarrativeManager.process_current_step()
			get_viewport().set_input_as_handled()
			return
		
		# 鼠标点击推进对话 
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 如果进入了自由探索，鼠标点击也不应触发下一步
			if NarrativeManager.is_in_free_explore:
				print("dialog.gd: 在自由探索模式，点击被禁用。")
				get_viewport().set_input_as_handled()
				return

			waiting_for_click = false
			NarrativeManager.process_current_step()
			get_viewport().set_input_as_handled()
			return
# 辅助函数：检查是否点击了UI按钮
func _is_clicking_ui_button(event: InputEventMouseButton) -> bool:
	# 获取鼠标位置
	var mouse_pos = event.position
	
	# 检查是否点击了选项按钮
	for child in options_container.get_children():
		if child is Button:
			var button_rect = child.get_global_rect()
			if button_rect.has_point(mouse_pos):
				return true
# 获取所有在 "interactive_ui" 组中的节点
	var interactive_nodes = get_tree().get_nodes_in_group("interactive_ui")
	for node in interactive_nodes:
		if node is Button:
			var button_rect = node.get_global_rect()
			if button_rect.has_point(mouse_pos):
				return true
	return false

# 显示台词
func _on_NarrativeManager_show_dialogue(speaker: String, text: String):
	is_typing = true           # 标记开始打字
	# 开始播放打字音效
	Loadmanager.start_typing_sfx()
	waiting_for_click = false  # 打字时不能点击前进
	var bubble = add_dialogue_bubble(speaker, text)
	current_typing_bubble = bubble # 保存引用

	# 连接到新的完成处理函数
	bubble.typing_finished.connect(_on_bubble_typing_finished, CONNECT_ONE_SHOT)


func _setup_scrollbar():
	var v_scroll_bar = dialogue_scroll_container.get_v_scroll_bar()
	if not v_scroll_bar:
		print("错误：未找到垂直滚动条！")
		return
		
	print("找到滚动条，开始设置样式")
	
	# 设置滚动条的最小尺寸（宽度）
	v_scroll_bar.custom_minimum_size.x = 10 # 可以调细一点，比如8或10
	
	# --- 创建轨道（背景）样式 ---
	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color("#f0f0f0") # 非常浅的灰色背景
	track_style.corner_radius_top_left = 5
	track_style.corner_radius_top_right = 5
	track_style.corner_radius_bottom_left = 5
	track_style.corner_radius_bottom_right = 5
	# 可以给轨道加个淡淡的边框
	track_style.border_width_left = 1
	track_style.border_width_right = 1
	track_style.border_color = Color("#e0e0e0")
	
	# --- 创建滑块（可拖动部分）样式 ---
	var grabber_style = StyleBoxFlat.new()
	# 使用与您对话框风格匹配的颜色，比如一个柔和的蓝色
	grabber_style.bg_color = Color("cadaf0ff") # 和Player气泡颜色一致
	grabber_style.corner_radius_top_left = 5
	grabber_style.corner_radius_top_right = 5
	grabber_style.corner_radius_bottom_left = 5
	grabber_style.corner_radius_bottom_right = 5
	
	# 应用样式
	v_scroll_bar.add_theme_stylebox_override("scroll", track_style)
	v_scroll_bar.add_theme_stylebox_override("grabber", grabber_style)
	v_scroll_bar.add_theme_stylebox_override("grabber_highlight", grabber_style) # 鼠标悬停时
	v_scroll_bar.add_theme_stylebox_override("grabber_pressed", grabber_style)   # 鼠标按下时
	
	print("滚动条样式设置完成")

# --- 修改：添加对话气泡 ---
func add_dialogue_bubble(speaker: String, text: String) -> Node:
	var new_bubble = DialogueBubble.instantiate()
	var processed_text = process_keywords(text)
	
	dialogue_container.add_child(new_bubble)

	# --- 关键改动：调用新的setup_bubble方法，并传入样式配置 ---
	new_bubble.setup_bubble(speaker, processed_text, STYLES)
	
	# --- 关键改动：在这里连接meta_clicked信号 ---
	new_bubble.connect_meta_clicked(_on_meta_clicked)
	
	call_deferred("scroll_to_bottom")
	return new_bubble # 返回气泡实例

# scroll_to_bottom 函数没有变化
func scroll_to_bottom():
	# 等待VBoxContainer调整完毕
	await get_tree().process_frame
	if is_instance_valid(dialogue_scroll_container):
		dialogue_scroll_container.scroll_vertical = dialogue_scroll_container.get_v_scroll_bar().max_value

		
var aaa=load("res://asset/音效/按键音_3.mp3")
# _on_meta_clicked, process_keywords, update_keyword_count, clear_existing_dialogue, clear_options 函数均无变化
func _on_meta_clicked(meta):
	var clicked_keyword = str(meta)
	# 检查是否在自由探索中，并触发事件
	if NarrativeManager.is_in_free_explore:
		Loadmanager.play_sfx(aaa)
		Jsonload.collect_keyword(clicked_keyword)
		
		var target_event_name = NarrativeManager.get_target_for_keyword(clicked_keyword)
		
		if not target_event_name.is_empty():
			if target_event_name.begins_with("distractor_"):
				# (Interference Keyword - Mapped)
				# 目标以 "distractor_" 开头，调用追加对话的函数
				print("  - Action: Calling make_distractor_choice('%s')" % target_event_name)
				NarrativeManager.make_distractor_choice(target_event_name)
			else:
				# (Mapped Keyword - New Sequence)
				# 目标不是干扰项，调用清空对话的函数
				print("  - Action: Calling make_mapped_choice('%s')" % target_event_name)
				NarrativeManager.make_mapped_choice(target_event_name)
		else:
			# (Unmapped Highlighted Word - Not Interference)
			print("dialog.gd: 未映射关键词 [%s] 被点击，只收集，无对话。" % clicked_keyword)
	else:
		print("dialog.gd: 关键词 [%s] 被点击（非探索模式）。" % clicked_keyword)
		
func _on_bubble_typing_finished():
	if get_tree().paused:
		Loadmanager.stop_typing_sfx()
		is_typing = false
		current_typing_bubble = null
		return

	Loadmanager.stop_typing_sfx()
	print("dialog.gd: 气泡打字完成/跳过。")
	is_typing = false
	current_typing_bubble = null

	# 如果自动播放被关闭，就老老实实等待玩家
	if not auto_play_enabled or not NarrativeManager.should_auto_advance_after_current_step():
		print("dialog.gd: 等待玩家点击。（自动播放已关闭或当前句不允许自动推进）")
		waiting_for_click = true
		return

	# —— 自动播放分支：1.5 秒后继续 ——
	waiting_for_click = false
	var t := Timer.new()
	t.wait_time = 1.5
	t.one_shot = true
	add_child(t)
	t.timeout.connect(
		func():
			t.queue_free()
			NarrativeManager.process_current_step.call_deferred()
	)
	t.start()
	print("dialog.gd: 1.5 秒后自动推进下一句。")
	



func process_keywords(text: String) -> String:
	var result = text
	var regex = RegEx.new()
	regex.compile("【(.*?)】")
	var search_results = regex.search_all(result)
	for match in search_results:
		var full_match = match.get_string(0)
		var keyword = match.get_string(1)

			
		var replacement = "[color=red][url=" + keyword + "]" + keyword + "[/url][/color]"
		result = result.replace(full_match, replacement)
	return result

func clear_existing_dialogue():
	for child in dialogue_container.get_children():
		child.queue_free()

func clear_options():
	for child in options_container.get_children():
		child.queue_free()
# 添加 _notification 函数来处理暂停状态变化
func _notification(what):
	match what:
		NOTIFICATION_PAUSED:
			# 游戏暂停时调用
			print("对话框: 游戏暂停")
			# 保存当前打字状态
			was_typing_before_pause = is_typing
			# 停止打字音效
			if is_typing:
				Loadmanager.stop_typing_sfx()
				print("对话框: 暂停时停止打字音效")
		
		NOTIFICATION_UNPAUSED:
			# 游戏恢复时调用
			# 如果暂停前正在打字，恢复打字音效
			if was_typing_before_pause and is_typing:
				Loadmanager.start_typing_sfx()
