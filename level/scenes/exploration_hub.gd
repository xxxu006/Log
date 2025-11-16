# 加载角色，启动叙事，执行导演的动作指令，报告玩家交互。
extends Node2D

@onready var pause_menu = $CanvasLayer3/CanvasLayer2/PauseMenu
@onready var in_game_ui = $CanvasLayer3/InGameUI
@onready var character_anchor = $CharacterAnchor
@onready var dialogue_system_ui =$CanvasLayer3/CanvasLayer/DialogueSystemUI
@onready var pause_menu_ui =$CanvasLayer3/CanvasLayer2/pasemenuui
@onready var game_ui =$CanvasLayer3/CanvasLayer2/gameui
@onready var setting_menu =$setting/setting
@onready var points_label = $CanvasLayer3/InGameUI/PointsLabel
@onready var collected_keywords_label =$CanvasLayer3/CanvasLayer2/PauseMenu/Panel/HBoxContainer/VBoxContainer2/VBoxContainer/CollectedKeywordsLabel
@onready var choices_container =$CanvasLayer3/CanvasLayer2/gameui/ChoicesContainer
@onready var magnifier_button = $CanvasLayer3/InGameUI/MagnifierButton
@onready var magnifier_node = $CanvasLayer3/InGameUI/magnifier
@onready var anim_player = $AnimationPlayer

# @onready var magnifier_node = $Magnifier # 放大镜视觉
signal quit_requested
var character_instance: Node2D 
# 存储当前激活的BUG区域及其对应的 Area2D 节点
var active_bugs: Dictionary = {}
var current_bug_next_event: String = "" # 存储找到BUG后要去哪
var bug_is_active_visual: bool = false # 跟踪是否有BUG可见
var effect_nodes = {} # 用于存储效果节点
var current_available_minigame: String = ""  # 当前可用的小游戏场景路径
var is_minigame_available: bool = false      # 小游戏是否可用
var current_minigame_id: String = ""
var current_minigame_scene: String = ""


func _ready():
	get_tree().paused = false
	call_deferred("initialize_dialogue_system")
	_reset_visual_effects()
	load_character_and_setup_bugs()
	if character_instance:
		setup_bug_areas()
	else:
		print("错误：角色实例未设置")
	
	call_deferred("deferred_setup")
	call_deferred("start_narrative")
	NarrativeManager.execute_action.connect(_on_execute_action)
	
	if game_ui and game_ui is Button:
		game_ui.disabled = true
		
	# 统一在这里检查并播放待播放事件
	call_deferred("check_and_play_pending_events")
	
	

# 新增统一的事件检查函数
func check_and_play_pending_events():
	# 优先检查结局事件
	if Global.pending_ending_event != "":
		print("探索中心: 检测到待播放的结局事件: %s" % Global.pending_ending_event)
		
		# 等待一帧确保所有节点都就绪
		await get_tree().process_frame
		
		# 通过叙事管理器播放结局
		if NarrativeManager:
			NarrativeManager.start_event(Global.pending_ending_event)
		
		# 清除待播放事件
		Global.pending_ending_event = ""
	# 然后检查普通事件
	elif Global.pending_event_after_scene_change != "":
		print("探索中心: 检测到待播放事件: ", Global.pending_event_after_scene_change)
		
		# 等待一帧确保所有节点就绪
		await get_tree().process_frame
		
		# 再等待一帧确保叙事管理器就绪
		await get_tree().process_frame
		
		print("探索中心: 开始播放事件: ", Global.pending_event_after_scene_change)
		
		# 播放事件
		if NarrativeManager:
			NarrativeManager.start_event(Global.pending_event_after_scene_change)
		else:
			print("错误：叙事管理器未就绪")
		
		# 清除待播放事件
		Global.pending_event_after_scene_change = ""
	else:
		print("探索中心: 没有待播放事件")
		
func start_narrative():
	print("Hub: 启动叙事系统...")
	NarrativeManager.start_event("start_game")
func deferred_setup():
	connect_all_signals()
	_on_points_changed(Jsonload.interaction_points)
	_on_keyword_collected("", Jsonload.collected_keywords.size(), Jsonload.ALL_POSSIBLE_KEYWORDS.size())
	# 初始化放大镜按钮状态
	if is_instance_valid(magnifier_button):
		magnifier_button.disabled = false  # 确保按钮可用

	# 延迟播放角色动画，确保角色完全加载
	call_deferred("play_character_idle")
	
	# 初始禁用小游戏按钮
	if is_instance_valid(game_ui):
		game_ui.disabled = true

# 处理ESC键
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			pause_menu.hide_menu()
		else:
			pause_menu.show_menu()

# 统一管理所有信号连接
func connect_all_signals():
	# 只在未连接时连接
	if not pause_menu.resume_requested.is_connected(_on_resume_requested):
		pause_menu.resume_requested.connect(_on_resume_requested)
	if not pause_menu.settings_requested.is_connected(_on_settings_requested):
		pause_menu.settings_requested.connect(_on_settings_requested)
	if not pause_menu.main_requested.is_connected(_on_main_requested):
		pause_menu.main_requested.connect(_on_main_requested)
	if not quit_requested.is_connected(_on_quit_requested):
		quit_requested.connect(_on_quit_requested)
	if not pause_menu_ui.pressed.is_connected(_on_pause_menu_ui_pressed):
		pause_menu_ui.pressed.connect(_on_pause_menu_ui_pressed)
	if not game_ui.pressed.is_connected(_on_game_ui_pressed):
		game_ui.pressed.connect(_on_game_ui_pressed)
	print("检查 NarrativeManager 信号连接:")
	print("show_ui_choices 连接:", NarrativeManager.show_ui_choices.is_connected(_on_show_ui_choices))
	print("clear_ui_choices 连接:", NarrativeManager.clear_ui_choices.is_connected(_clear_ui_choices))
	
	if not NarrativeManager.show_ui_choices.is_connected(_on_show_ui_choices):
		print("重新连接 show_ui_choices 信号")
		NarrativeManager.show_ui_choices.connect(_on_show_ui_choices)
	
	if not NarrativeManager.clear_ui_choices.is_connected(_clear_ui_choices):
		print("重新连接 clear_ui_choices 信号")  
		NarrativeManager.clear_ui_choices.connect(_clear_ui_choices)
	if not NarrativeManager.sequence_completed.is_connected(_on_sequence_completed):
		NarrativeManager.sequence_completed.connect(_on_sequence_completed)

	if not NarrativeManager.execute_action.is_connected(_on_NarrativeManager_execute_action):
		NarrativeManager.execute_action.connect(_on_NarrativeManager_execute_action)
	if not NarrativeManager.show_ui_choices.is_connected(_on_show_ui_choices):
		NarrativeManager.show_ui_choices.connect(_on_show_ui_choices)
	if not NarrativeManager.clear_ui_choices.is_connected(_clear_ui_choices):
		NarrativeManager.clear_ui_choices.connect(_clear_ui_choices)
	if not magnifier_node.following_cancelled.is_connected(_on_magnifier_following_cancelled):
		magnifier_node.following_cancelled.connect(_on_magnifier_following_cancelled)
	
	# 检查并连接 non_bug_clicked 信号
	if not magnifier_node.non_bug_clicked.is_connected(_on_magnifier_non_bug_clicked):
		magnifier_node.non_bug_clicked.connect(_on_magnifier_non_bug_clicked)
	
	# 检查并连接 area_clicked 信号
	if not magnifier_node.area_clicked.is_connected(_on_magnifier_area_clicked):
		magnifier_node.area_clicked.connect(_on_magnifier_area_clicked)

	if not Jsonload.interaction_points_changed.is_connected(_on_points_changed):
		Jsonload.interaction_points_changed.connect(_on_points_changed)
	if not Jsonload.keyword_collected.is_connected(_on_keyword_collected):
		Jsonload.keyword_collected.connect(_on_keyword_collected)
	if is_instance_valid(magnifier_button) and not magnifier_button.pressed.is_connected(_on_magnifier_button_pressed):
		magnifier_button.pressed.connect(_on_magnifier_button_pressed)
	if is_instance_valid(magnifier_node) and not magnifier_node.area_clicked.is_connected(_on_magnifier_area_clicked):
		magnifier_node.area_clicked.connect(_on_magnifier_area_clicked)
	if not magnifier_button.pressed.is_connected(_on_magnifier_button_pressed):
		magnifier_button.pressed.connect(_on_magnifier_button_pressed)
	if not magnifier_node.area_clicked.is_connected(_on_magnifier_area_clicked):
		magnifier_node.area_clicked.connect(_on_magnifier_area_clicked)
# 新增：初始化对话系统
func initialize_dialogue_system():
	print("初始化对话系统...")
	# 确保对话系统节点已准备好
	if is_instance_valid(dialogue_system_ui):
		dialogue_system_ui.visible = true
		print("对话系统已初始化")
# 新增：延迟播放角色动画的方法

	
# 处理事件序列完成的信号
func _on_sequence_completed():
	print("探索中心：收到 sequence_completed 信号，进入自由探索状态")
	
	# 详细检查每个BUG的状态
	var active_count = 0
	for bug_id in active_bugs:
		var bug_data = active_bugs[bug_id]
		print("BUG %s 状态: is_active=%s, next_event=%s" % [bug_id, bug_data["is_active"], bug_data["next_event"]])
		if bug_data["is_active"]:
			active_count += 1
	
	bug_is_active_visual = (active_count > 0)
	
	print("探索中心：激活的BUG数量: %d, bug_is_active_visual: %s" % [active_count, bug_is_active_visual])
	
	# 根据是否有激活的BUG来设置放大镜按钮状态
	if is_instance_valid(magnifier_button):
		magnifier_button.disabled = !bug_is_active_visual
		print("放大镜按钮状态: disabled=%s" % (!bug_is_active_visual))
	
	# 检查并更新小游戏按钮状态
	if is_instance_valid(game_ui):
		# 如果小游戏可用，确保按钮启用；否则禁用
		game_ui.disabled = !is_minigame_available
		print("小游戏按钮状态: disabled=%s, is_minigame_available=%s" % [!is_minigame_available, is_minigame_available])
	
	# 只有在没有激活BUG时才完全重置放大镜状态
	if not bug_is_active_visual:
		_reset_magnifier_state()
func load_character_and_setup_bugs():
	var current_day = Jsonload.current_cycle
	var character_path = "res://level/scenes/characters/character_day_1.tscn" 

	if not ResourceLoader.exists(character_path):
		print("错误：找不到第 %s 天的角色场景！路径: %s" % [current_day, character_path])
		return
	var character_scene = load(character_path)
	if character_scene:
		character_instance = character_scene.instantiate()
		character_anchor.add_child(character_instance)
		
		 # 确保角色动画播放
		if character_instance.has_method("force_play_enter_animation"):
			character_instance.force_play_enter_animation()
		else:
			print("角色没有 force_play_enter_animation 方法，使用默认动画播放")
			character_instance.play_enter_scene_animation()
		
		setup_bug_areas()
	else:
		print("错误：无法加载角色场景: ", character_path)
		

func setup_bug_areas():
	active_bugs.clear()
	if not is_instance_valid(character_instance):
		print("错误：角色实例无效，无法设置BUG区域")
		return
		
	for child in character_instance.get_children():
		if child.name.begins_with("BugArea") and child is Area2D:
			var bug_id = "bug_" + child.name.replace("BugArea", "").to_lower()
			
			# 初始禁用交互
			if character_instance.has_method("set_bug_area_interaction_node"):
				character_instance.set_bug_area_interaction_node(child, false)

			active_bugs[bug_id] = {
				"area_node": child, 
				"is_active": false, 
				"next_event": ""
			} 
			print("Hub: 找到并初始化 BUG 区域: %s (is_active: false)" % bug_id)

# 处理关键词收集信号
func _on_keyword_collected(keyword_name, collected_count, total_count):
	# 更新关键词列表 Label
	if is_instance_valid(collected_keywords_label):
		# 从 Jsonload 获取最新的列表
		var keywords_list = Jsonload.collected_keywords
		# 将数组转换为逗号分隔的字符串
		var keywords_text = ", ".join(keywords_list)
		# 更新 Label 文本
		collected_keywords_label.text = "%s" % keywords_text
	else:
		print("警告：CollectedKeywordsLabel 节点无效！")

# 处理点数变化的UI更新
func _on_points_changed(new_count: int):
	if is_instance_valid(points_label):
		points_label.text = "行动次数: %d" % new_count
	else:
		print("警告：PointsLabel 节点无效！")

# 处理放大镜按钮点击
# 添加新的处理函数
func _on_magnifier_following_cancelled():
	print("探索中心：收到放大镜取消跟随信号，重新启用放大镜按钮")
	# 如果还有激活的BUG，则重新启用放大镜按钮
	if bug_is_active_visual and is_instance_valid(magnifier_button):
		magnifier_button.disabled = false
# 处理放大镜按钮点击
func _on_magnifier_button_pressed():
	magnifier_node.start_following()
	# 只有在自由探索时才能点击
	print("Hub: 放大镜按钮被点击")
	if not NarrativeManager.is_in_free_explore:
		return

	if bug_is_active_visual:
		# 有BUG激活
		print("Hub: 激活放大镜模式。")
		magnifier_node.start_following()
		magnifier_button.disabled = true
	else:
		# 无BUG播放干扰项对话
		print("Hub: 点击放大镜（无BUG），播放干扰项。")
		
		var target = NarrativeManager.get_target_for_keyword("magnifier_click_fail")
		
		if not target.is_empty():
			NarrativeManager.play_distractor_without_cost(target)
		else:
			print("警告：JSON 中没有为 'global_distractor_magnifier_fail' 定义事件。")

# 处理放大镜的点击事件
func _on_magnifier_area_clicked(area_name: String):
	# 注意：这里不调用 _reset_magnifier_state()，只停止跟随
	if is_instance_valid(magnifier_node):
		magnifier_node.stop_following()
	
	# 重新启用放大镜按钮，让玩家可以再次点击
	if is_instance_valid(magnifier_button) and bug_is_active_visual:
		magnifier_button.disabled = false
	
	var bug_id = "bug_" + area_name.replace("BugArea", "").to_lower()
	
	if active_bugs.has(bug_id) and active_bugs[bug_id]["is_active"]:
		print("探索中心：检测到放大镜点击 BUG: ", bug_id)
		var next_event = active_bugs[bug_id].get("next_event", "")
		NarrativeManager.bug_found(bug_id, next_event)
	else:
		_on_magnifier_non_bug_clicked()

func _on_magnifier_non_bug_clicked():
	print("探索中心：放大镜点击非BUG区域，播放干扰项并消耗点数")
	# 播放干扰项并消耗点数
	var target = NarrativeManager.get_target_for_keyword("magnifier_click_fail")
	
	if not target.is_empty():
		# 使用会消耗点数的干扰项播放方法
		NarrativeManager.make_distractor_choice(target)
	else:
		print("警告：JSON 中没有为 'magnifier_click_fail' 定义事件。")
# 重置放大镜状态
func _reset_magnifier_state():
	print("Hub: 重置放大镜状态。")
	if is_instance_valid(magnifier_node):
		magnifier_node.stop_following()
	
	if is_instance_valid(magnifier_button):
		magnifier_button.disabled = false
	

# 处理NarrativeManager的动作指令
func _on_NarrativeManager_execute_action(action_id: String, params):
	print("舞台监督收到动作指令: ", action_id, " Params: ", params)
	if not is_instance_valid(character_instance):
		print("警告：尝试执行动作 %s 时角色实例无效！" % action_id)
		return

	match action_id:
		"show_bug_visual":
			if params and params.has("bug_id"):
				var bug_id = params.bug_id
				print("Hub: 准备显示 BUG '%s'" % bug_id)
		
				# 检查角色实例和方法
				if not is_instance_valid(character_instance):
					print("错误：角色实例无效！")
					return
		
		# 实际调用角色的显示BUG方法
				if character_instance.has_method("show_bug_visual"):
					print("Hub: 调用角色 show_bug_visual 方法")
					character_instance.show_bug_visual(bug_id, true)
				else:
					print("错误：角色没有 show_bug_visual 方法！")
		
		# 更新 active_bugs 状态
				if active_bugs.has(bug_id):
					active_bugs[bug_id]["is_active"] = true 
					bug_is_active_visual = true
					print("Hub: BUG '%s' 状态更新为激活" % bug_id)
				else:
					print("错误：BUG '%s' 不在 active_bugs 中" % bug_id)

		"enable_bug_click": # 处理新动作
			if params and params.has("bug_id") and active_bugs.has(params.bug_id):
				var bug_id = params.bug_id
				var area_node = active_bugs[bug_id].area_node
				active_bugs[bug_id]["next_event"] = params.get("next_event", "") 
				
				if is_instance_valid(area_node) and character_instance.has_method("set_bug_area_interaction_node"):
					print("动作：激活 BUG '%s' 点击区域。" % bug_id)
					character_instance.set_bug_area_interaction_node(area_node, true)
				else:
					print("错误：无法激活 BUG '%s' 区域！" % bug_id)
			else:
				print("错误：enable_bug_click 动作缺少 bug_id 或 bug_id 无效！")
		
		"disable_bug_click": # 处理新动作
			if params and params.has("bug_id") and active_bugs.has(params.bug_id):
				var bug_id = params.bug_id
				var area_node = active_bugs[bug_id].area_node
				if is_instance_valid(area_node) and character_instance.has_method("set_bug_area_interaction_node"):
					print("动作：禁用 BUG '%s' 点击区域。" % bug_id)
					character_instance.set_bug_area_interaction_node(area_node, false)
				
				active_bugs[bug_id]["is_active"] = false
				active_bugs[bug_id]["next_event"] = ""
				
				# 检查是否有其他BUG处于激活状态
				bug_is_active_visual = active_bugs.values().any(func(b): return b.is_active)
				
				# 如果这是最后一个BUG，重置放大镜
				if not bug_is_active_visual:
					_reset_magnifier_state()
			else:
				print("错误：disable_bug_click 动作缺少 bug_id 或 bug_id 无效！")
		
		# 处理隐藏 BUG 视觉
		"hide_bug_visual":
			if params and params.has("bug_id"):
				var bug_id = params.bug_id
				if character_instance.has_method("show_bug_visual"):
					print("动作：隐藏 BUG 视觉 '%s'" % bug_id)
					character_instance.show_bug_visual(bug_id, false)
			else:
				print("错误：hide_bug_visual 缺少 bug_id 参数！")

		# 处理显示效果，effect_id：effect_bug31_enlarged，effect_bug33_distort
		"show_effect":
			if params and params.has("effect_id"):
				var effect_id = params.effect_id
				print("动作：显示效果 '%s'" % effect_id)
				_play_visual_effect(effect_id)
			else:
				print("错误：show_effect 缺少 effect_id 参数！")

		"enable_minigame_interaction":
			current_minigame_id = params.get("minigame_id", "")
			current_minigame_scene = params.get("scene_path", "")
			is_minigame_available = true
			enable_medical_machine_click()
			print("ExplorationHub: 小游戏交互已启用 - ID: %s, 场景: %s" % [current_minigame_id, current_minigame_scene])
		#"play_failure_animation":
			#print("动作：播放失败动画！") #可选
				#
		_: 
			print("警告：exploration_hub 收到未知动作指令: ", action_id)




# UI选择相关

func _on_show_ui_choices(choices_array: Array):
	_clear_ui_choices() # 清除旧的
	if not is_instance_valid(choices_container):
		print("错误：ChoicesContainer 无效！")
		return
		
	print("Hub UI: 显示选项按钮...")
	for choice_data in choices_array:
		var button = Button.new()
		button.text = choice_data.text
		# 连接按钮点击到处理函数，并传递目标事件
		button.pressed.connect(_on_ui_choice_selected.bind(choice_data.target))
		choices_container.add_child(button)
	choices_container.show()

func _clear_ui_choices():
	if not is_instance_valid(choices_container): return
	for child in choices_container.get_children():
		child.queue_free()
	choices_container.hide()

func _on_ui_choice_selected(target_event: String):
	print("Hub UI: 玩家选择了按钮 -> ", target_event)
	_clear_ui_choices() # 点击后清除按钮
	# 按钮选项总是消耗点数并开始新序列
	NarrativeManager.make_mapped_choice(target_event)
	
# 处理视觉效果的函数
# 在 _play_visual_effect 方法中添加更多调试信息
func _play_visual_effect(effect_id: String):
	print("Hub: 尝试播放视觉效果: ", effect_id)
	
	if not is_instance_valid(anim_player):
		print("错误：AnimationPlayer 节点无效！")
		return
		
	print("Hub: AnimationPlayer 有效，检查动画列表...")
	
	# 打印所有可用的动画
	var animation_list = anim_player.get_animation_list()
	print("可用的动画列表: ", animation_list)
	
	if anim_player.has_animation(effect_id):
		print("Hub: 找到动画 '%s'，开始播放" % effect_id)
		anim_player.play(effect_id)
	else:
		print("警告：AnimationPlayer 没有名为 '%s' 的动画！" % effect_id)
		print("当前注册的动画: ", animation_list)

# 播放角色idle动画
func play_character_idle():
	if is_instance_valid(character_instance):
		# 添加安全检查
		if character_instance.has_method("play_idle_animation"):
			character_instance.play_idle_animation()
		else:
			print("警告：角色实例没有 play_idle_animation 方法")
	else:
		print("警告：角色实例无效，无法播放动画")
		# 如果角色无效，尝试重新加载
		call_deferred("load_character_and_setup_bugs")
		call_deferred("play_character_idle")

# 停止角色动画（如果需要）
func stop_character_animations():
	if is_instance_valid(character_instance):
		if character_instance.has_method("stop_animations"):
			character_instance.stop_animations()
# 重置效果函数
func _reset_visual_effects():
	if is_instance_valid(anim_player):
		anim_player.stop(true) 
		print("Hub: 重置 AnimationPlayer 效果。")


# 暂停菜单逻辑
func _on_pause_menu_ui_pressed() -> void:
	quit_requested.emit()
	
# 禁用小游戏按钮
func disable_minigame_button():
	if is_instance_valid(game_ui):
		game_ui.disabled = true
		game_ui.visible = false  # 可选：隐藏按钮
		print("小游戏按钮已禁用")
	else:
		print("错误：无法禁用 game_ui，节点无效")

# 修改原来的按钮点击处理
func _on_game_ui_pressed():
	print("小游戏按钮被点击")
	print("当前小游戏ID: %s, 场景: %s" % [current_minigame_id, current_minigame_scene])
	print("小游戏是否可用: %s" % is_minigame_available)
	
	# 处理两种小游戏启动方式
	if current_minigame_id != "" and current_minigame_scene != "" and is_minigame_available:
		print("正在跳转到小游戏: %s (ID: %s)" % [current_minigame_scene, current_minigame_id])
		
		# 启动小游戏
		if Jsonload:
			Jsonload.start_minigame("minigame_%s" % current_minigame_id)
		
		# 执行场景跳转
		Loadmanager.load_scene(current_minigame_scene, true)
		
		# 跳转后重置状态
		current_minigame_id = ""
		current_minigame_scene = ""
		is_minigame_available = false
		disable_minigame_button()
	elif current_available_minigame != "" and is_minigame_available:
		print("正在跳转到小游戏: %s" % current_available_minigame)
		# 执行场景跳转
		Loadmanager.load_scene(current_available_minigame, true)
		# 跳转后重置状态
		current_available_minigame = ""
		is_minigame_available = false
		disable_minigame_button()
	else:
		print("错误：没有可用的迷你游戏或场景路径为空")
	
func _on_quit_requested():
	pause_menu.show_menu()

	
func _on_resume_requested():
	print("接收到继续游戏信息")
	
	pause_menu.hide_menu()

func _on_settings_requested():
	print("打开设置")
	setting_menu.show_setting()

func _on_main_requested():
	pause_menu.hide_menu()
	Loadmanager.load_scene("res://level/mainUI/main_menu.tscn",false)

# 添加处理动作的函数
func _on_execute_action(action_id: String, params: Dictionary):
	print("ExplorationHub: 收到动作 - %s, 参数: %s" % [action_id, params])
	
	match action_id:
		"enable_minigame_interaction":
			current_minigame_id = params.get("minigame_id", "")
			current_minigame_scene = params.get("scene_path", "")
			print("ExplorationHub: 小游戏交互已启用 - ID: %s, 场景: %s" % [current_minigame_id, current_minigame_scene])
			
			# 在这里启用场景中的医疗机器点击区域
			enable_medical_machine_click()
			
		"show_bug_visual":
			# 处理显示BUG视觉效果
			var bug_id = params.get("bug_id", "")
			var show = params.get("show", true)
			if bug_id and character_instance:
				character_instance.show_bug_visual(bug_id, show)
				
		"enable_bug_click":
			# 处理启用BUG点击
			var bug_id = params.get("bug_id", "")
			var enabled = params.get("enabled", true)
			# 根据你的场景结构启用相应的BUG区域
			
		# 添加其他动作的处理...
		_:
			print("ExplorationHub: 未知动作类型: %s" % action_id)
# 添加医疗机器点击处理函数
func on_medical_machine_clicked():
	if current_minigame_id != "" and current_minigame_scene != "":
		print("ExplorationHub: 医疗机器被点击，启动小游戏: %s" % current_minigame_id)
		
		# 启动小游戏
		if Jsonload:
			Jsonload.start_minigame("minigame_%s" % current_minigame_id)
		
		# 切换到小游戏场景
		get_tree().change_scene_to_file(current_minigame_scene)
		
		# 重置状态
		current_minigame_id = ""
		current_minigame_scene = ""
	else:
		print("ExplorationHub: 医疗机器未激活或小游戏信息不完整")

# 小游戏完成回调
# 在 ExplorationHub.gd 中

func _on_minigame_completed(minigame_name: String, success: bool):
	print("ExplorationHub: 收到小游戏结果: ", minigame_name, " 成功: ", success)
	# 将结果传递给叙事管理器
	if NarrativeManager:
		NarrativeManager.handle_minigame_result(success, minigame_name)
func _on_scene_loaded():
	# 场景加载后重置小游戏按钮状态
	current_available_minigame = ""
	is_minigame_available = false
	disable_minigame_button()
func enable_medical_machine_click():
	if game_ui and game_ui is Button:
		# 启用按钮
		game_ui.disabled = false
		game_ui.visible = true
		is_minigame_available = true  # 确保设置这个标志
		print("医疗机器按钮已启用")
		print("医疗机器按钮已启用，小游戏可用性: %s" % is_minigame_available)
		
		# 确保按钮的点击信号已连接
		if not game_ui.pressed.is_connected(_on_game_ui_pressed):  # 注意这里应该是 _on_game_ui_pressed
			game_ui.pressed.connect(_on_game_ui_pressed)
	else:
		print("错误：game_ui不是按钮类型或不存在")


func _on_close_button_button_down() -> void:
	pause_menu.hide_menu()
