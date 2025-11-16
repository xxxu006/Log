# game_manager.gd
extends Node
# 定义存档文件的路径,存档系统还没做
const SAVE_FILE_PATH = "user://savegame.json"
var bg_="res://asset/音乐/待机_1.mp3"
# 当 GameManager 节点进入场景树时调用

func _ready():
	#可以自己处理退出逻辑，比如显示确认对话框
	get_tree().set_auto_accept_quit(false)
	Loadmanager.play_music(bg_)


# 这是处理所有系统通知的核心函数
func _notification(what: int) -> void:
	# 检查通知类型是否为“窗口关闭请求”
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("检测到窗口关闭请求！")
		# 调用我们的退出处理函数
		_handle_quit_request()

func load_game():
	# 1. 检查存档文件是否存在
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("警告：未找到存档文件，将开始新游戏。")
		return null # 返回 null 表示没有存档

	# 2. 打开文件进行读取
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		print("错误：无法打开存档文件进行读取！")
		return null

	# 3. 读取文件内容为 JSON 字符串
	var json_string = file.get_as_text()
	file.close()

	# 4. 解析 JSON 字符串
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	# 5. 检查解析是否成功
	if parse_result != OK:
		print("错误：JSON 解析失败！")
		return null
	
	# 6. 返回解析后的数据（它应该是一个 Dictionary）
	var data = json.data
	print("游戏已加载！")
	return data

# 处理退出请求的函数
func _handle_quit_request():
	# 这里你可以选择直接退出，或者像之前一样显示确认对话框
	# 为了演示，我们直接执行清理和退出
	
	# 在实际游戏中，你可能想在这里弹出一个确认对话框
	# var dialog = ConfirmationDialog.new()
	# dialog.dialog_text = "确定要退出游戏吗？未保存的进度将会丢失。"
	# dialog.confirmed.connect(_on_quit_confirmed)
	# dialog.canceled.connect(_on_quit_canceled)
	# get_tree().get_root().add_child(dialog)
	# dialog.popup_centered()
	
	# 为了简单起见，我们直接执行退出
	_perform_cleanup_and_quit()


# 确认退出后执行的函数
func _on_quit_confirmed():
	_perform_cleanup_and_quit()

# 取消退出后执行的函数
func _on_quit_canceled():
	print("用户取消了退出操作。")


# 执行真正的清理和退出操作
func _perform_cleanup_and_quit():
	print("正在执行清理操作...")
	
	# 1. 保存游戏数据
	save_data(Jsonload.current_data)
	# 3. 所有操作完成后，真正退出游戏
	print("清理完成，游戏退出。")
	get_tree().quit()


# --- 你的游戏逻辑函数 ---

func save_data(data_to_save: Dictionary):
	# 打开文件
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		print("错误：无法打开文件进行保存！")
		return

	# 转换并写入
	var json_string = JSON.stringify(data_to_save)
	file.store_string(json_string)
	file.close()
	
	print("游戏已保存到: ", SAVE_FILE_PATH)


# 这个函数可以被你的退出按钮调用
func quit_game():
	_handle_quit_request()
