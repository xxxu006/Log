extends Node

signal interaction_points_changed(new_count) # 通知UI更新
# signal exploration_failed_restart          # 通知NarrativeManager重置
signal global_failure_triggered           # 通知NarrativeManager游戏失败

signal keyword_collected(keyword_name, collected_count, total_count)  # 当新关键词被收集时发出
# 添加小游戏结果信号
signal minigame_completed(minigame_id, success)
# 添加结局解锁信号
signal ending_reached(ending_id)
var all_clicked_keywords: Array = [] 
var current_cycle: int = 1
var interaction_points: int = 10 # 玩家每天的“提问次数”
var collected_keywords: Array = [] # 存储已收集的关键词
var current_minigame: String = ""  # 当前正在玩的小游戏ID
var completed_endings: Array = []  # 存储玩家经历过的结局

const ALL_POSSIBLE_KEYWORDS = ["循环", "停滞","无意义的分镜","剪掉","当下"]
const REQUIRED_KEYWORD_COUNT = 5

# current_data 记录新的变量
var current_data = {
	"current_cycle": current_cycle,
	"interaction_points": interaction_points,
	"all_clicked_keywords": all_clicked_keywords,
	"collected_keywords": collected_keywords,
	"completed_endings": completed_endings  # 保存结局记录
}

func _ready():
	load_game_state()
	# 启动时通知UI当前的收集状态
	emit_signal("keyword_collected", "", collected_keywords.size(), ALL_POSSIBLE_KEYWORDS.size())
	if not minigame_completed.is_connected(_on_minigame_completed):
		minigame_completed.connect(_on_minigame_completed)
	interaction_points = max(0, interaction_points)

# 收集关键词
func collect_keyword(keyword: String):
	# 检查这是否是一个有效的、可收集的关键词
	if not keyword in ALL_POSSIBLE_KEYWORDS:
		print("Jsonload: 尝试收集无效关键词 '%s'，忽略。" % keyword)
		return

	# 检查是否已经收集过
	if keyword in collected_keywords:
		print("Jsonload: 关键词 '%s' 已收集，忽略。" % keyword)
		return
		
	print("Jsonload: 收集到新关键词: ", keyword)
	collected_keywords.append(keyword)
	
	# 发出信号，通知UI更新
	emit_signal("keyword_collected", keyword, collected_keywords.size(), ALL_POSSIBLE_KEYWORDS.size())
	
	save_game_state()
func record_keyword_click(keyword: String):
	if keyword not in all_clicked_keywords:
		all_clicked_keywords.append(keyword)
		save_game_state()  # 保存状态
		print("Jsonload: 记录关键词点击: ", keyword)
# 消耗点数并检查是否失败
func consume_point_and_check_failure() -> bool:
	if interaction_points <= 0:
		interaction_points=0
		print("失败：全局行动次数用尽。")
		emit_signal("global_failure_triggered")
		return true # 返回 true，失败结局
	
	interaction_points -= 1
	emit_signal("interaction_points_changed", interaction_points)
	print("全局行动次数消耗！剩余: ", interaction_points)
	return false # 返回 false，表示游戏继续

## 处理探索失败，重置当前对话
#func _end_exploration_failure():
	#print("进入探索失败重置...")
	#interaction_points = 4 # 重置提问次数
	#
	## 发出信号，通知 UI 重置显示
	#emit_signal("interaction_points_changed", interaction_points)
	#
	#save_game_state() # 保存重置后的点数
	#
	## 延迟一帧后发出重置信号
	#await get_tree().process_frame
	## 通知 NarrativeManager 重启当前事件
	#emit_signal("exploration_failed_restart")

# 重置行动次数的函数
func reset_interaction_points():
	print("Jsonload: 重置全局行动次数。")
	interaction_points = 10 # 重置回初始值
	emit_signal("interaction_points_changed", interaction_points)
	save_game_state() # 保存重置后的次数
# 在 Jsonload.gd 中添加
func reset_game_state():
	print("Jsonload: 重置游戏状态")
	current_cycle = 1
	interaction_points = 10
	collected_keywords.clear()
	all_clicked_keywords.clear()
	current_minigame = ""
	
	# 发出信号更新UI
	emit_signal("interaction_points_changed", interaction_points)
	emit_signal("keyword_collected", "", collected_keywords.size(), ALL_POSSIBLE_KEYWORDS.size())
	
	# 保存重置后的状态
	save_game_state()
## 检查当天的关键词是否都已收集
#func check_day_completion() -> bool:
	#if not required_keywords_for_day.has(current_cycle):
		#return true # 如果当天没有设置必须的关键词，默认成功
	#
	#var required = required_keywords_for_day[current_cycle]
	#for keyword in required:
		#if not collected_keywords.has(keyword):
			#return false # 只要有一个没找到，就返回失败
	#
	#return true

func load_game_state():
	var loaded_data = Gamemanager.load_game()
	if loaded_data:
		print("应用加载的数据...")
		# 应用新变量
		current_cycle = loaded_data.get("current_cycle", 1)
		interaction_points = loaded_data.get("interaction_points", 11)
		completed_endings = loaded_data.get("completed_endings", [])
		all_clicked_keywords = loaded_data.get("all_clicked_keywords", [])
		collected_keywords = loaded_data.get("collected_keywords", [])
	else:
		print("没有找到存档，使用默认值开始新游戏。")
		current_cycle = 1
		interaction_points = 10
		collected_keywords.clear()
		all_clicked_keywords.clear()
	emit_signal("interaction_points_changed", interaction_points)
	emit_signal("keyword_collected", "", collected_keywords.size(), ALL_POSSIBLE_KEYWORDS.size())
	

# 启动小游戏
func start_minigame(minigame_id: String):
	current_minigame = minigame_id
	print("Jsonload: 启动小游戏: ", minigame_id)

# 小游戏完成回调
func _on_minigame_completed(minigame_id: String, success: bool):
	print("Jsonload: 小游戏 %s 结果: %s" % [minigame_id, "成功" if success else "失败"])
	
	# 记录结局经历
	if success:
		match minigame_id:
			"minigame_A":
				if not "ending_A" in completed_endings:
					completed_endings.append("ending_A")
				ending_reached.emit("ending_A")
			"minigame_B", "minigame_C":
				if not "ending_B" in completed_endings:
					completed_endings.append("ending_B")
				ending_reached.emit("ending_B")
	
	current_minigame = ""
	save_game_state()

# 检查是否经历过某个结局
func has_experienced_ending(ending_id: String) -> bool:
	return ending_id in completed_endings

# 获取所有经历过的结局
func get_experienced_endings() -> Array:
	return completed_endings.duplicate()

# 在保存游戏状态时添加结局数据
func save_game_state():
	var save_data = {
		"current_cycle": current_cycle,
		"interaction_points": interaction_points,
		"all_clicked_keywords": all_clicked_keywords,
		"collected_keywords": collected_keywords,
		"completed_endings": completed_endings  # 保存结局记录
	}
	# 在保存前，从变量更新 current_data
	current_data["current_cycle"] = current_cycle
	current_data["interaction_points"] = interaction_points
	current_data["collected_keywords"] = collected_keywords
	

	
