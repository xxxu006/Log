extends Node2D

signal minigame_B_success
signal minigame_B_failure

var game_completed:bool
var minigame_id: String = "B"  # 根据实际小游戏设置

#game
var countdown_time: int = 30   # 倒计时总时间（秒）
var current_time: int = 30     # 当前剩余时间

@onready var countdown_label: Label = $CanvasLayer/Control/Label
@onready var countdown_timer: Timer = $CanvasLayer/Control/Timer
var audio_ = load("res://asset/音效/剪辑音.mp3")

func _ready():
	# 信号连接
	$spawn12._game_success.connect(_success)
	$spawn12._game_failed.connect(_fail)
	$spawn2._game_success.connect(_success)
	$spawn2._game_failed.connect(_fail)
	$spawn22._game_success.connect(_success)
	$spawn22._game_failed.connect(_fail)
	
	if countdown_timer:
		if not countdown_timer.timeout.is_connected(_on_countdown_timer_timeout):
			countdown_timer.timeout.connect(_on_countdown_timer_timeout)
	## 初始化倒计时
	_init_countdown()

func _init_countdown():
	current_time = countdown_time  # 在这里初始化当前时间
	_update_countdown_display()
	countdown_timer.start()

func _update_countdown_display():
	# 更新倒计时显示
	countdown_label.text = "手术倒计时：%ds" % current_time
	# 根据剩余时间改变颜色
	if current_time <= 10:
		# 少于10秒时显示为红色
		countdown_label.add_theme_color_override("font_color", Color(0.405, 0.566, 0.525, 1.0)) #
	elif current_time <= 20:
		# 少于20秒时显示为橙色
		countdown_label.add_theme_color_override("font_color", Color(0.402, 0.46, 0.492, 1.0)) #
	else:
		# 正常时间显示为白色或您喜欢的颜色
		countdown_label.add_theme_color_override("font_color", Color(0.302, 0.322, 0.371, 1.0)) #

func _on_countdown_timer_timeout():
	current_time -= 1
	_update_countdown_display()
	
	if current_time <= 0:
		countdown_timer.stop()
		# 使用 call_deferred 确保在下一帧执行
		call_deferred("_success")

func _success():
	if game_completed:  # 防止重复执行
		return
		
	game_completed = true
	countdown_timer.stop()
	Loadmanager.play_sfx(audio_)
	print("小游戏 %s 成功完成" % minigame_id)
	# 发射信号
	minigame_B_success.emit()
	# 通过 Jsonload 发送完成信号
	Jsonload.minigame_completed.emit("minigame_B" , true)
	
	# 使用 call_deferred 而不是直接暂停
	call_deferred("_delayed_scene_change")

func _delayed_scene_change():
	get_tree().paused = true
	# 更短的延迟
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	Loadmanager.load_scene("res://level/scenes/exploration_hub.tscn")

func _fail():
	if game_completed:  # 防止重复执行
		return
		
	game_completed = true
	Loadmanager.play_sfx(audio_)
	countdown_timer.stop()
	
	print("小游戏 %s 失败" % minigame_id)
	# 发射信号
	minigame_B_failure.emit()
	# 通过 Jsonload 发送完成信号
	Jsonload.minigame_completed.emit("minigame_B" , false)
	
	call_deferred("_delayed_fail_scene_change")

func _delayed_fail_scene_change():
	get_tree().paused = true
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	Loadmanager.load_scene("res://level/scenes/exploration_hub.tscn")
