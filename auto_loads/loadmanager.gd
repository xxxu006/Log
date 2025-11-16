extends Node
#过场管理，音效管理

signal scene_ready_to_instantiate(packed_scene: PackedScene)
signal progress_changed(progress)
signal load_done
const VOLUME_SETTING_KEY = "audio/music_volume"
var music_volume: float = 0.5  # 在这里声明 music_volume 变量
var sfx_volume: float = 0.5

var _load_screen_path:String='res://auto_loads/loading_screen.tscn'#过场动画
var _load_screen=load(_load_screen_path)
var _loaded_resource:PackedScene
var _scene_path:String
var _progress:Array=[]
var _current_loading_screen: Node = null  # 跟踪当前加载屏幕
var use_sub_threads:bool=true
#多线程加载开关


func _ready():
	init_music_audio_manager()
	init_sfx_audio_manager()


# 新增：处理加载屏幕出场动画完成
func _on_loading_screen_outro_finished() -> void:
	print("Loadmanager: 加载屏幕出场动画完成，准备销毁")
	if is_instance_valid(_current_loading_screen):
		_current_loading_screen.queue_free()
		_current_loading_screen = null
		print("Loadmanager: 加载屏幕已销毁")
# @use_loading_screen: 是否显示加载遮罩动画，默认为 true
func load_scene(scene_path: String, use_loading_screen: bool = true) -> void:
	print("Loadmanager: 开始加载场景 ", scene_path)
	_scene_path = scene_path
	
	if use_loading_screen:
		# 实例化加载屏幕节点
		_current_loading_screen = _load_screen.instantiate()
		
		# 使用 call_deferred 确保安全添加
		get_tree().get_root().add_child.call_deferred(_current_loading_screen)
		
		# 等待一帧，确保节点已添加到场景树
		await get_tree().process_frame
		
		# 检查节点是否有效
		if is_instance_valid(_current_loading_screen):
			# 在加载屏幕实例化后的连接信号部分添加：
# 新增：连接加载屏幕的动画完成信号
			if _current_loading_screen.has_signal("outro_animation_finished"):
				if _current_loading_screen.outro_animation_finished.is_connected(_on_loading_screen_outro_finished):
					_current_loading_screen.outro_animation_finished.disconnect(_on_loading_screen_outro_finished)
				_current_loading_screen.outro_animation_finished.connect(_on_loading_screen_outro_finished)
			# 连接信号
			if self.progress_changed.is_connected(_current_loading_screen._update_progress_bar):
				self.progress_changed.disconnect(_current_loading_screen._update_progress_bar)
			self.progress_changed.connect(_current_loading_screen._update_progress_bar)
			
			if self.load_done.is_connected(_current_loading_screen._start_outro_animation):
				self.load_done.disconnect(_current_loading_screen._start_outro_animation)
			self.load_done.connect(_current_loading_screen._start_outro_animation)
			
			# 等待加载屏幕准备就绪
			if _current_loading_screen.has_signal("loading_screen_has_full_coverage"):
				await _current_loading_screen.loading_screen_has_full_coverage
				print("Loadmanager: 加载屏幕已就绪")
		else:
			push_error("加载屏幕实例无效！")
		# 等待加载屏幕准备就绪
	start_load()

func start_load()->void:
	var state=ResourceLoader.load_threaded_request(_scene_path,'',use_sub_threads)
	if state==OK:
		set_process(true)
		print("Loadmanager: 开始资源加载")
	else:
		print("Loadmanager: 资源加载请求失败，错误码: ", state)

func _process(_delta):
	var load_status=ResourceLoader.load_threaded_get_status(_scene_path,_progress)
	match load_status:
		0: # 无效
			print("Loadmanager: 资源状态无效")
			set_process(false)
			return
		2: # 失败
			print("Loadmanager: 资源加载失败")
			set_process(false)
			return
		1: # 加载中
			emit_signal("progress_changed",_progress[0])
		3: # 加载完毕
			_loaded_resource=ResourceLoader.load_threaded_get(_scene_path)
			if _loaded_resource:
				print("Loadmanager: 资源加载完成，准备实例化")
				emit_signal("progress_changed",1.0)
				emit_signal("load_done")
				get_tree().change_scene_to_packed(_loaded_resource)
				print("Loadmanager: 场景已切换")
				emit_signal("scene_ready_to_instantiate", _loaded_resource)
			else:
				print("Loadmanager: 错误：加载的资源为空")
			set_process(false)



#音频
enum Bus {
	MASTER,
	MUSIC,
	SFX,
}

const MUSIC_BUS = "Music"
const SFX_BUS = "SFX"

## 音乐播放器配置
## 音乐播放器的个数
var music_audio_player_count: int = 2
## 当前播放音乐的播放器的序号，默认是0
var current_music_player_index: int = 0
## 音乐播放器存放的数组，方便调用
var music_players: Array[AudioStreamPlayer]
## 音乐渐变时长
var music_fade_duration:float = 1.0

## 音效播放器的个数
var sfx_audio_player_count: int = 6
## 音效播放器存放的数组，方便调用
var sfx_players: Array[AudioStreamPlayer]

# --- 打字音效相关变量 ---
var typing_sfx_stream: AudioStream
var current_typing_sfx_player: AudioStreamPlayer = null  # 当前用于打字音效的播放器
var is_typing_sfx_playing: bool = false
	
## 初始化音乐播放器
func init_music_audio_manager() -> void:
	for i in music_audio_player_count:
		var audio_player := AudioStreamPlayer.new()
		audio_player.process_mode = Node.PROCESS_MODE_ALWAYS#暂停也能播放
		audio_player.bus = MUSIC_BUS
		add_child(audio_player)
		music_players.append(audio_player)
func init_sfx_audio_manager() -> void:
	for i in sfx_audio_player_count:
		var audio_player := AudioStreamPlayer.new()
		audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
		audio_player.bus = SFX_BUS
		audio_player.volume_db = linear_to_db(sfx_volume)  # 设置初始音量
		add_child(audio_player)
		sfx_players.append(audio_player)
# 设置音乐音量
func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	
	# 应用到所有音乐播放器
	for player in music_players:
		player.volume_db = linear_to_db(music_volume)
	# 保存设置
	save_volume_settings()

# 保存音量设置
func save_volume_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.save("user://audio_settings.cfg")
	config.set_value("audio", "sfx_volume", sfx_volume) 
	config.save("user://audio_settings.cfg")

# 加载音量设置
func load_volume_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://audio_settings.cfg")
	
	if err == OK:
		music_volume = config.get_value("audio", "music_volume", 0.5)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.5)
		# 应用加载的音量到所有播放器
		for player in music_players:
			player.volume_db = linear_to_db(music_volume)
		for player in sfx_players:  # 新增音效播放器音量设置
			player.volume_db = linear_to_db(sfx_volume)

# 获取当前音量（用于初始化滑动条）
func get_music_volume() -> float:
	return music_volume

## 播放指定音乐
func play_music(music_path: String) -> void:
	var audio_stream = load(music_path)
	
	if not audio_stream:
		push_error("无法加载音乐文件: " + music_path)
		return
	
	# 设置循环播放 - 根据音频格式设置循环
	if audio_stream is AudioStreamWAV:
		audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif audio_stream is AudioStreamMP3:
		audio_stream.loop = true
	# 可以根据需要添加其他音频格式
	
	var current_audio_player: AudioStreamPlayer = music_players[current_music_player_index]
	if current_audio_player.stream == audio_stream and current_audio_player.playing:
		return
	
	var empty_audio_index = 1 if current_music_player_index == 0 else 0
	var empty_audio_player: AudioStreamPlayer = music_players[empty_audio_index]
	
	# 渐入新音乐
	empty_audio_player.stream = audio_stream
	empty_audio_player.volume_db = -40  # 从静音开始
	play_and_fade_in(empty_audio_player)
	
	# 渐出当前音乐
	if current_audio_player.playing:
		fade_out_and_stop(current_audio_player)
	
	# 更新当前播放器索引
	current_music_player_index = empty_audio_index
# 渐入
func play_and_fade_in(audio_player: AudioStreamPlayer) -> void:
	audio_player.play()
	var tween: Tween = create_tween()
	tween.tween_property(audio_player, "volume_db", linear_to_db(music_volume), music_fade_duration)
## 渐出
func fade_out_and_stop(_audio_: AudioStreamPlayer) -> void:
	for player in music_players:
		var tween: Tween = create_tween()
		tween.tween_property(player, "volume_db", -40.0, music_fade_duration / 2.0)
		await tween.finished
		player.stop()
		player.stream = null
		

# 设置音效音量
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	# 应用到所有音效播放器
	for player in sfx_players:
		player.volume_db = linear_to_db(sfx_volume)
	
	# 保存设置
	save_volume_settings()

# 获取音效音量
func get_sfx_volume() -> float:
	return sfx_volume
## 播放指定音效
func play_sfx(_audio: AudioStream, _is_random_pitch:bool = false) -> void:
	var pitch := 1.0
	if _is_random_pitch:
		pitch = randf_range(0.9, 1.1)
	for i in sfx_audio_player_count:
		var sfx_audio_player := sfx_players[i]
		if not sfx_audio_player.playing:
			sfx_audio_player.stream = _audio
			sfx_audio_player.pitch_scale = pitch
			sfx_audio_player.play()
			break

## 设置总线的音量
func set_volume(bus_index:Bus, v:float) -> void:
	var db := linear_to_db(v)
	AudioServer.set_bus_volume_db(bus_index, db)
	
	# --- 打字音效功能（使用现有的SFX播放器）---

## 设置打字音效
func set_typing_sfx(sfx_path: String) -> void:
	var audio_stream = load(sfx_path)
	if audio_stream:
		typing_sfx_stream = audio_stream
		print("打字音效设置成功: ", sfx_path)
	else:
		push_error("无法加载打字音效: " + sfx_path)

## 开始播放打字音效（循环）
func start_typing_sfx() -> void:

	if typing_sfx_stream and not is_typing_sfx_playing:
		# 寻找一个空闲的SFX播放器
		for i in sfx_audio_player_count:
			var sfx_audio_player := sfx_players[i]
			if not sfx_audio_player.playing:
				current_typing_sfx_player = sfx_audio_player
				current_typing_sfx_player.stream = typing_sfx_stream
				current_typing_sfx_player.pitch_scale = 1.0  # 固定音高
				current_typing_sfx_player.play()
				is_typing_sfx_playing = true
				print("开始播放打字音效")
				break

## 停止播放打字音效
func stop_typing_sfx() -> void:
	if current_typing_sfx_player and is_typing_sfx_playing:
		current_typing_sfx_player.stop()
		is_typing_sfx_playing = false
		current_typing_sfx_player = null
		print("停止播放打字音效")


	
	
# 场景切换处理
func _on_scene_changed():
	# 根据场景名称自动切换BGM
	#match scene_name:
		#"MainMenu":
			#play_bgm(BGM_TRACKS.MAIN_MENU)
		#"GameLevel":
			#play_bgm(BGM_TRACKS.GAME_LEVEL)
		#"BossBattle":
			#play_bgm(BGM_TRACKS.BOSS_BATTLE)
		#"Credits":
			#play_bgm(BGM_TRACKS.CREDITS)
		#_:
			# 默认停止音乐或保持当前
	pass
