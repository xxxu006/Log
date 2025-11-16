# 作为全局脚本，读取JSON，管理状态机，发出指令。
extends Node

signal show_dialogue(speaker, text)         # 指令：显示一行对话
# signal show_choices(choices_array)          # 指令：显示选项按钮
signal clear_dialogue()                     # 指令：清空对话区域
signal execute_action(action_id, params)    # 指令：让 exploration_hub 执行特定动作
signal sequence_completed                   # 状态：当前对话序列（直到下一个选择/动作）已完成
signal request_scene_reload(scene_path: String) # 信号：请求场景重载
signal show_ui_choices(choices_array)
signal clear_ui_choices() # 清除按钮

var narrative_data: Dictionary              # 存储整个 JSON 剧本
var current_event_key: String = ""          # 当前正在处理的事件名称
var current_event: Array = []               # 当前事件的步骤数组
var current_step: int = 0                   # 当前在事件中的步骤索引

# 小游戏状态变量
var pending_minigame_success_event: String = ""
var pending_minigame_failure_event: String = ""

# 自由探索状态变量
var is_in_free_explore: bool = false
var current_keyword_map: Dictionary = {}    # 存储 { "关键词": "目标事件" }
var current_event_key_for_resume: String = "" # 保存当前事件的键
var is_auto_advancing_dialogue: bool = false # 如果为 true，表示正在播放干扰对话，dialog.gd 播放完自动请求下一步

# 初始化
func _ready():
	var file = FileAccess.open("res://data/narrative.json", FileAccess.READ)
	if not is_instance_valid(file):
		return
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_error("解析 narrative.json 文件失败！错误代码: %d" % error)
		return
	narrative_data = json.get_data()
	file.close()
	# 连接全局失败信号
	Jsonload.global_failure_triggered.connect(_on_global_failure)
	
	# 确保连接小游戏完成信号
	if Jsonload and not Jsonload.minigame_completed.is_connected(_on_minigame_completed):
		Jsonload.minigame_completed.connect(_on_minigame_completed)
	
	print("NarrativeManager: 剧本加载成功。")
	if Jsonload:
		Jsonload.ending_reached.connect(_on_ending_reached)
# 处理小游戏完成信号
func _on_minigame_completed(minigame_name: String, success: bool):
	print("NarrativeManager: 收到小游戏完成信号 - 游戏: %s, 成功: %s" % [minigame_name, success])
	handle_minigame_result(success, minigame_name)  # 传递两个参数

# NarrativeManager.gd

func handle_minigame_result(success: bool, minigame_name: String):
	print("NarrativeManager: 处理小游戏结果 - 成功: %s, 游戏: %s" % [success, minigame_name])
	
	# 从 minigame_A 中提取 A
	var minigame_id = minigame_name.replace("minigame_", "")
	var target_event = ""
	
	# 根据小游戏ID和结果映射到正确的事件
	match minigame_id:
		"A":
			if success:
				target_event = "ending_A"  # 小游戏A成功 -> 结局A
			else:
				target_event = "loop_2"  # 小游戏A失败 -> 失败结局
		"B":
			if success:
				target_event = "ending_B"  # 小游戏B成功 -> 结局B  
			else:
				target_event = "loop_3"  # 小游戏B失败 -> 失败结局
		_:
			# 默认处理
			target_event = minigame_id + "_success" if success else minigame_id + "_failure"
	
	print("NarrativeManager: 目标事件: %s" % target_event)
	if target_event.begins_with("ending_"):
		var ending_id = target_event.replace("ending_", "")
		execute_action.emit("show_ending_image", {"ending_id": ending_id})
	
	# 修改这里：使用统一的结局事件处理方式
	Global.pending_ending_event = target_event
	print("NarrativeManager: 设置待播放结局事件: %s" % target_event)
	
	# 跳转回hub场景
	print("NarrativeManager: 跳转回探索中心")
	Loadmanager.load_scene("res://level/scenes/exploration_hub.tscn")
func switch_to_hub_and_play_ending(event_id: String):
	print("NarrativeManager: 切换到探索中心并播放结局")
	
	# 保存要播放的事件ID
	Global.pending_ending_event = event_id
	
	# 切换场景到探索中心
	get_tree().change_scene_to_file("res://level/scenes/exploration_hub.tscn")
# 核心入口
func start_event(event_name: String, clear_ui: bool = true):
	if not narrative_data.has(event_name):
		print("错误：NarrativeManager 找不到事件: ", event_name)
		return

	print("NarrativeManager: === 开始事件: ", event_name, " (Clear UI: %s) ===" % clear_ui)
	
	
	if event_name == "ending_A":
		print("NarrativeManager: 检测到进入结局A，请求重置行动次数。")
		Jsonload.reset_interaction_points()
	
	if clear_ui:
		current_event_key_for_resume = event_name
		# current_keyword_map.clear()
	elif event_name.ends_with("_resume"):
		# 干扰项就会返回到resume事件
		current_event_key_for_resume = event_name
		
	current_event_key = event_name
	current_event = narrative_data[event_name]
	current_step = 0
	
	is_in_free_explore = false # 启动任何事件时都退出探索
	
	is_auto_advancing_dialogue = not clear_ui
	
	if clear_ui:
		clear_dialogue.emit()
		clear_ui_choices.emit()
	
	process_current_step()

# 用于正确关键词，清空对话
func make_mapped_choice(target_event: String):
	print("NarrativeManager: 玩家选择 [Mapped] -> ", target_event)
	
	if not is_in_free_explore: return # 增加保护
	
	if Jsonload.consume_point_and_check_failure():
		print("NarrativeManager: 点数耗尽，中止启动新事件。等待重置...")
		return
			
	is_in_free_explore = false
	start_event(target_event, true) # true: 清空UI

# 用于干扰关键词/角色点击
func make_distractor_choice(target_event: String):
	print("NarrativeManager: 玩家选择 [Distractor] -> ", target_event)

	if not is_in_free_explore: return
	
	if Jsonload.consume_point_and_check_failure():
		print("NarrativeManager: 点数耗尽，中止启动新事件。等待重置...")
		return
			
	is_in_free_explore = false # 暂时退出探索，播放干扰对话
	# false: 不清空UI，追加对话
	start_event(target_event, false)
# 播放干扰对话但不消耗点数
func play_distractor_without_cost(target_event: String):
	print("NarrativeManager: 播放干扰对话 [不消耗次数] -> ", target_event)
	
	if not is_in_free_explore: return
			
	# 保存当前状态
	var was_in_free_explore = is_in_free_explore
	is_in_free_explore = false
	start_event(target_event, false)  # 只播放对话，不消耗点数
# 由 exploration_hub 调用
func bug_found(bug_id: String, next_event: String):
	# 检查是否在自由探索模式
	if not is_in_free_explore:
		print("NarrativeManager: BUG '%s' 被点击, 但不在自由探索模式。忽略。" % bug_id)
		return # 不做任何事

	print("NarrativeManager: BUG '%s' 找到, 消耗点数..." % bug_id)
	
	# 消耗点数并检查失败
	if Jsonload.consume_point_and_check_failure():
		print("NarrativeManager: 点数耗尽，中止启动新事件。等待重置...")
		return # 停止执行，Jsonload将触发重置流程
	
	# 退出探索状态并开始新事件,BUG点击清空UI
	is_in_free_explore = false

	if next_event:
		print("NarrativeManager: BUG '%s' 找到, 前往 -> %s" % [bug_id, next_event])
		start_event(next_event, true) # BUG 总是清空UI
	else:
		print("NarrativeManager: BUG '%s' 找到, 但没有指定 next_event!" % bug_id)
		
# 获取关键词对应的目标事件
func get_target_for_keyword(keyword: String) -> String:
	# 优先在当前对话的 map 中查找
	if current_keyword_map.has(keyword):
		return current_keyword_map.get(keyword)
	
	# 如果在 map 中找不到，检查是否为全局干扰项
	
	# 查是否为放大镜干扰项
	if keyword == "magnifier_click_fail":
		# 如果 JSON 中有 "global_distractor_magnifier_fail"，则使用它
		if narrative_data.has("global_distractor_magnifier_fail"):
			return "global_distractor_magnifier_fail"
	# 检查是否为特定词语干扰项
	if keyword == "global_distractor_specific":
		if narrative_data.has("global_distractor_specific"):
			return "global_distractor_specific"

	# 如果都不是，返回空
	return ""

func should_auto_advance_after_current_step() -> bool:
	if current_step >= current_event.size():
		return false # 事件结束，等待自由探索
	var next_step_data = current_event[current_step]
	# 如果下一步不是对话，则应该自动推进
	if next_step_data.type == "dialogue":
		return false # 下一句还是对话，等待回车
		
	if next_step_data.type == "action" and next_step_data.get("do") == "show_bug_visual":
		return false # 下一步是显示BUG，等待回车
		
	return true
#
func _on_global_failure():
	#print("NarrativeManager: 收到全局失败信号！启动失败结局。")
	# 确保不在自由探索中
	is_in_free_explore = false
	## 强制停止放大镜
	#execute_action.emit("force_stop_magnifier", null)
	# 启动失败结局事件
	start_event("failure_ending", true) # 失败结局总是清空UI

# 状态机核心
func process_current_step():
	# 检查事件是否结束
	if current_step >= current_event.size():
		print("NarrativeManager: --- 事件结束: ", current_event_key, " ---")
		is_in_free_explore = true
		is_auto_advancing_dialogue = false # 清除标志
		print("NarrativeManager: 进入自由探索状态。")
		sequence_completed.emit()
		return

	var step_data = current_event[current_step]
	current_step += 1 # 预读下一步

	print("NarrativeManager: 处理步骤 %d (%s), 类型: %s" % [current_step, current_event_key, step_data.type])

	match step_data.type:
		"dialogue":
			# 默认情况等待玩家
			var should_auto_advance_this_step = is_auto_advancing_dialogue
			
			if current_step < current_event.size():
				# 如果对话后面有自动的步骤
				var next_step_data = current_event[current_step]
				if next_step_data.type in ["action", "goto", "map_keywords", "condition"]:
					# 自动推进
					should_auto_advance_this_step = true
			
			# 更新 dialog.gd 将要读取的全局标志
			is_auto_advancing_dialogue = should_auto_advance_this_step
			
			# 正常发出信号
			show_dialogue.emit(step_data.speaker, step_data.text)
			
			# 序列的最后一步重置标志
			if not should_auto_advance_this_step:
				is_auto_advancing_dialogue = false

			pass
		
		# 处理关键词映射
		"map_keywords":
			current_keyword_map = step_data.get("map", {}).duplicate()
			print("NarrativeManager: 关键词映射已加载: ", current_keyword_map)
			# 检查并发出 Choices 信号
			if current_keyword_map.has("_choices"):
				var choices_data = current_keyword_map["_choices"]
				print("NarrativeManager: 发送 UI Choices: ", choices_data)
				show_ui_choices.emit(choices_data)
				# 从 map 中移除
				current_keyword_map.erase("_choices")
			else:
				print("NarrativeManager: 没有找到 _choices 数据")
			process_current_step.call_deferred() # 自动处理下一步

		"action":
			var action_id = step_data.do
			var params = step_data.get("params", {})

			# 处理内部动作
			if action_id == "set_cycle":
				if params and params.has("cycle"):
					Jsonload.current_cycle = params.cycle
					Jsonload.save_game_state()
					print("NarrativeManager: 内部动作 - 设置循环为 ", params.cycle)
					process_current_step.call_deferred()
				else:
					print("错误：set_cycle 动作缺少 cycle 参数！")
					process_current_step.call_deferred()

			elif action_id == "reload_exploration_hub":
				print("NarrativeManager: Emitting request_scene_reload signal.")
				Global.pending_event_after_scene_change = "start_game"
				Loadmanager.load_scene("res://level/scenes/exploration_hub.tscn")
				return

			elif action_id == "reset_points":
				print("NarrativeManager: JSON请求重置行动次数。")
				Jsonload.reset_interaction_points()
				process_current_step.call_deferred()

	# 处理小游戏跳转
			elif action_id == "goto_minigame":
				var scene_path = params.get("scene", "")
				var minigame_id = params.get("minigame_id", "")
		
				if minigame_id:
			# 设置小游戏成功和失败的事件
					pending_minigame_success_event = "minigame_%s_success" % minigame_id
					pending_minigame_failure_event = "minigame_%s_failure" % minigame_id
			
					print("NarrativeManager: 设置小游戏事件 - 成功: %s, 失败: %s" % [
						pending_minigame_success_event, pending_minigame_failure_event
			])
			
			# 不立即启动小游戏，而是发送信号让 UI 解锁
					print("NarrativeManager: 请求解锁小游戏交互 - 游戏ID: %s" % minigame_id)
					execute_action.emit("enable_minigame_interaction", {
				"minigame_id": minigame_id,
				"scene_path": scene_path
			})
			
			# 进入自由探索模式，等待玩家点击
					is_in_free_explore = true
					sequence_completed.emit()
				else:
					print("错误：goto_minigame 动作缺少 minigame_id 参数！")
					process_current_step.call_deferred()

	# 处理结局记录动作
			elif action_id == "record_ending":
				var ending_id = params.get("ending_id", "")
				if ending_id:
					Jsonload.record_ending(ending_id)
					print("NarrativeManager: 记录结局: ", ending_id)
				else:
					print("错误：record_ending 动作缺少 ending_id 参数！")
				process_current_step.call_deferred()

	# 处理直接场景切换
			elif action_id == "change_scene":
				var scene_path = params.get("scene", "")
				if scene_path:
					print("NarrativeManager: 切换场景到: ", scene_path)
					get_tree().change_scene_to_file(scene_path)
				else:
					print("错误：change_scene 动作缺少 scene 参数！")
		# 场景切换后不需要继续处理步骤

	# 处理其他发送给 exploration_hub 的动作
			else:
				var known_hub_actions = [
			"show_bug_visual", "enable_bug_click", "disable_bug_click",
			"flash_screen", "play_failure_animation",
			"hide_bug_visual", "show_effect"
		]
				if action_id in known_hub_actions:
					execute_action.emit(action_id, params)
			
			# 对于大多数动作，我们可以立即继续处理下一步
			# 除了那些需要等待的动作
					var wait_actions = ["goto_minigame", "reload_exploration_hub"]
					if action_id not in wait_actions:
						process_current_step.call_deferred()
				else:
					print("警告：NarrativeManager 收到未明确处理的 action: ", action_id)
					process_current_step.call_deferred()

		"goto":
			is_in_free_explore = false # 确保 GOTO 时退出探索
			start_event(step_data.event, not is_auto_advancing_dialogue) # 跳转会重置 current_step


		"condition":
			var target_event = ""
			match step_data.check:
				"cycle":
					if Jsonload.current_cycle == step_data.value:
						target_event = step_data.target
				"keywords_collected_count":
					var required_count = step_data.get("value", 8)
					if Jsonload.collected_keywords.size() >= required_count:
						target_event = step_data.success_target
					else:
						target_event = step_data.failure_target
				"resume_last_event":
					if not current_event_key_for_resume.is_empty():
						target_event = current_event_key_for_resume
					else:
						target_event = "start_game"
			if target_event:
				start_event(target_event, not is_auto_advancing_dialogue)
			else:
				process_current_step.call_deferred()

		_:
			print("警告：NarrativeManager 遇到未知步骤类型: ", step_data.type)
			process_current_step()
					
# NarrativeManager.gd

func process_step(step: Dictionary, step_index: int):
	var step_type = step.get("type", "")
	
	match step_type:
		"action":
			var action = step.get("action", "")
			var args = step.get("args", [])
			process_action(action, args)
		"dialogue":
			# 原有对话处理...
			pass
		"goto":
			# 原有跳转处理...
			pass
		"change_scene":
			var scene_path = step.get("scene", "")
			if scene_path != "":
				Loadmanager.load_scene(scene_path)

func process_action(action: String, args: Array):
	match action:
		"reset_action_count":
			# 原有重置行动次数代码...
			pass
		"change_scene_to_hub":
			# 切换到探索中心
			Loadmanager.load_scene("res://level/scenes/exploration_hub.tscn")
		# 其他动作...
func _on_ending_reached(ending_id: String):
	pass
	#显示endingpopup，解锁endpanel（mainmanu里面的panel图鉴）
