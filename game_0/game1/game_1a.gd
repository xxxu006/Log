# game_1a.gd
extends Node2D

# =========================
# 1. 新增：状态机和教程相关
# =========================
enum GameState {
	TUTORIAL,
	PLAYING
}

# 在编辑器中，将你的教程场景文件(.tscn)拖拽到这个属性上
@export var tutorial_scene: PackedScene

var current_state: GameState = GameState.TUTORIAL # 默认从教程开始
var game_completed: bool = false
var minigame_id: String = "A"
signal minigame_A_success
signal minigame_A_failure
var countdown_time: int = 30
var current_time: int = 30

@onready var countdown_label: Label = $CanvasLayer/Control/Label
@onready var countdown_timer: Timer = $CanvasLayer/Control/Timer
var audio_ = load("res://asset/音效/剪辑音.mp3")

# =========================
# 2. 修改：主入口函数
# =========================
func _ready():
	# 游戏启动时，决定是否显示教程
	# 这里我们总是显示教程，你可以将其替换为检查存档的逻辑
	# 例如: if SaveSystem.is_first_time_play("minigame_A"):
	_start_tutorial()

func _start_tutorial():
	current_state = GameState.TUTORIAL
	print("进入教程模式")
	
	# 暂停游戏逻辑节点
	$spawn1.process_mode = Node.PROCESS_MODE_DISABLED
	$spawn2.process_mode = Node.PROCESS_MODE_DISABLED
	countdown_label.hide() # 隐藏倒计时UI
	
	# 实例化并添加教程场景
	if tutorial_scene:
		var tutorial_instance = tutorial_scene.instantiate()
		# 关键：连接教程的完成信号
		tutorial_instance.tutorial_finished.connect(_on_tutorial_finished)
		# 将教程UI添加到CanvasLayer下，确保它在最上层
		$CanvasLayer.add_child(tutorial_instance)
	else:
		push_error("错误：没有为游戏场景分配教程场景！")
		# 如果没有教程，直接开始游戏
		start_game()

# 当教程完成时，这个函数会被调用
func _on_tutorial_finished():
	print("教程完成，准备开始游戏")
	# 移除教程实例（它自己会调用 queue_free）
	# 现在开始正式游戏
	start_game()

# =========================
# 3. 游戏启动函数
# =========================
func start_game():
	current_state = GameState.PLAYING
	print("游戏正式开始")
	
	# 显示倒计时UI
	countdown_label.show()
	
	# 恢复游戏逻辑节点
	$spawn1.process_mode = Node.PROCESS_MODE_INHERIT
	$spawn2.process_mode = Node.PROCESS_MODE_INHERIT
	
	# 执行原来的初始化逻辑
	_connect_game_signals()
	_init_countdown()

func _connect_game_signals():
	$spawn1.game_success.connect(_success)
	$spawn1.game_failed.connect(_fail)
	$spawn2._game_success.connect(_success)
	$spawn2._game_failed.connect(_fail)
	if countdown_timer:
		if not countdown_timer.timeout.is_connected(_on_countdown_timer_timeout):
			countdown_timer.timeout.connect(_on_countdown_timer_timeout)

# =========================
# 4. 原有的游戏逻辑函数（保持不变）
# =========================
func _init_countdown():
	current_time = countdown_time
	_update_countdown_display()
	countdown_timer.start()

func _update_countdown_display():
	if not countdown_label:
		push_error("错误：找不到倒计时Label节点！")
		return
	countdown_label.text = "手术倒计时：%ds" % current_time
	if current_time <= 10:
		countdown_label.add_theme_color_override("font_color", Color.RED)
	elif current_time <= 20:
		countdown_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		countdown_label.add_theme_color_override("font_color", Color.WHITE)

func _on_countdown_timer_timeout():
	current_time -= 1
	_update_countdown_display()
	if current_time <= 0:
		countdown_timer.stop()
		_fail()

func _success():
	if game_completed: return
	game_completed = true
	countdown_timer.stop()
	Loadmanager.play_sfx(audio_)
	print("小游戏 %s 成功完成" % minigame_id)
	minigame_A_success.emit()
	Jsonload.minigame_completed.emit("minigame_A", true)
	call_deferred("_delayed_scene_change")

func _fail():
	if game_completed: return
	game_completed = true
	Loadmanager.play_sfx(audio_)
	countdown_timer.stop()
	print("小游戏 %s 失败" % minigame_id)
	minigame_A_failure.emit()
	Jsonload.minigame_completed.emit("minigame_A", false)
	call_deferred("_delayed_fail_scene_change")

func _delayed_scene_change():
	get_tree().paused = true
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	Loadmanager.load_scene("res://level/scenes/exploration_hub.tscn")

func _delayed_fail_scene_change():
	get_tree().paused = true
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	Loadmanager.load_scene("res://level/scenes/exploration_hub.tscn")
