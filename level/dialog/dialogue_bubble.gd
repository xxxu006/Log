# DialogueBubble.gd (修正版)

extends PanelContainer

# 信号：当这个气泡的文字全部显示完毕时发出
signal typing_finished

@onready var dialogue_text_label = $MarginContainer/DialogueText

var full_text_bbcode: String # 存储处理过的BBCode文本
var current_char_index: int = 0
var type_timer: Timer

# --- 新增：气泡样式配置 ---
# 定义一个最大宽度，超过这个宽度文本会自动换行
const MAX_BUBBLE_WIDTH = 370 
# 定义一个最小宽度，确保短文本气泡不会太小
const MIN_BUBBLE_WIDTH = 100

func _ready():
	# 为每个气泡实例创建一个独立的计时器
	type_timer = Timer.new()
	type_timer.wait_time = 0.04 # 打字速度
	type_timer.one_shot = true
	add_child(type_timer)
	type_timer.timeout.connect(_on_type_timeout)

# --- 新增：设置气泡样式和布局的核心函数 ---
# speaker: 发言者 ("Player", "Patient", "default")
# style_config: 从dialog.gd传入的样式字典
func setup_bubble(speaker: String, text: String, style_config: Dictionary):
	# 1. 根据发言者设置对齐方式
	match speaker:
		"Player":
			# 玩家气泡靠左对齐
			self.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		"Patient":
			# 病人气泡靠右对齐
			self.size_flags_horizontal = Control.SIZE_SHRINK_END
		"default":
			# 默认/系统气泡居中，并填充最大宽度
			self.size_flags_horizontal = Control.SIZE_FILL
	
	# 2. 应用颜色和字体样式
	var style = style_config.get(speaker, style_config.get("default", {}))
	_apply_style(style)

	# 3. 计算并设置气泡宽度
	_calculate_and_set_width(text)
	
	# 4. 开始打字
	start_typing(text)

# --- 新增：应用颜色和字体样式 ---
func _apply_style(style: Dictionary):
	# 设置背景样式
	var new_stylebox = StyleBoxFlat.new()
	new_stylebox.bg_color = style.get("bg_color", Color.WHITE)
	new_stylebox.corner_radius_top_left = 10
	new_stylebox.corner_radius_top_right = 10
	new_stylebox.corner_radius_bottom_left = 10
	new_stylebox.corner_radius_bottom_right = 10
	# 添加一些内边距让文字不贴边
	new_stylebox.content_margin_left = 10
	new_stylebox.content_margin_right = 10
	new_stylebox.content_margin_top =8
	new_stylebox.content_margin_bottom = 8
	
	# --- 修正：使用 add_theme_stylebox_override ---
	# 这是覆盖现有主题样式的推荐方法
	self.add_theme_stylebox_override("panel", new_stylebox)
	
	# 设置文字颜色和大小
	dialogue_text_label.add_theme_color_override("default_color", style.get("text_color", Color.BLACK))
	dialogue_text_label.add_theme_font_size_override("normal_font_size", style.get("font_size", 24))

# --- 新增：计算并设置气泡宽度 ---
func _calculate_and_set_width(bbcode_text: String):
	# 为了计算宽度，我们需要去除BBCode标签
	var regex = RegEx.new()
	regex.compile("\\[.*?\\]") # 匹配所有 [ ... ] 标签
	var plain_text = regex.sub(bbcode_text, "", true)
	
	# 获取字体对象
	var font = dialogue_text_label.get_theme_font("normal_font")
	if font == null:
		font = ThemeDB.fallback_font # 如果没有设置字体，使用默认字体

	# 计算文本的像素宽度
	var text_width = font.get_string_size(plain_text, dialogue_text_label.horizontal_alignment, -1, dialogue_text_label.get_theme_font_size("normal_font_size")).x
	
	# 加上内边距 (从StyleBox获取)
	var stylebox = get_theme_stylebox("panel")
	var padding = stylebox.content_margin_left + stylebox.content_margin_right
	
	# 计算最终宽度，并限制在最大和最小宽度之间
	var final_width = clamp(text_width + padding, MIN_BUBBLE_WIDTH, MAX_BUBBLE_WIDTH)
	
	# 设置气泡和内部RichTextLabel的自定义最小宽度
	# 这会强制气泡至少有这么宽，并且会根据这个宽度换行
	self.custom_minimum_size.x = final_width
	dialogue_text_label.custom_minimum_size.x = final_width - padding # RichTextLabel的宽度是减去padding的
	
	# 确保RichTextLabel会自动换行
	dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text_label.fit_content = true # 允许RichTextLabel在垂直方向上适应内容

# --- 修改：开始逐字打印 ---
func start_typing(processed_bbcode_text: String):
	full_text_bbcode = processed_bbcode_text
	current_char_index = 0
	dialogue_text_label.text = "" # 清空文本
	
	# 设置 RichTextLabel 的可见字符数为0，然后通过计时器逐个增加
	dialogue_text_label.text = full_text_bbcode
	dialogue_text_label.visible_characters = 0
	
	type_timer.start()

# 计时器回调，逐个显示字符
func _on_type_timeout():
	if dialogue_text_label.visible_characters < dialogue_text_label.get_total_character_count():
		dialogue_text_label.visible_characters += 1
		type_timer.start()
	else:
		# 打字完成
		await get_tree().process_frame
		typing_finished.emit()

func _exit_tree():
	if is_instance_valid(type_timer):
		type_timer.stop()
		
# 允许玩家点击跳过打字
func skip_typing():
	# 检查计时器是否仍在运行
	if is_instance_valid(type_timer) and not type_timer.is_stopped():
		type_timer.stop()
		dialogue_text_label.visible_characters = -1 # 表示显示全部
		# 延迟一帧确保更新完成再发信号
		await get_tree().process_frame
		typing_finished.emit()

# --- 修改：连接关键词点击信号 ---
# 这个函数现在由外部调用，而不是自己连接
func connect_meta_clicked(callable: Callable):
	dialogue_text_label.meta_clicked.connect(callable)
