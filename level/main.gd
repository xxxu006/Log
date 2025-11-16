extends Node

@onready var scene_container = $SceneContainer
@onready var setting_panel = $UILayer/setting 

func _ready():
	# 订阅 Loadmanager 的新信号

	Loadmanager.scene_ready_to_instantiate.connect(switch_scene)
	# ❗ 新增：连接 NarrativeManager 的重载请求信号到 go_to_scene 函数
	NarrativeManager.request_scene_reload.connect(go_to_scene)
	go_to_scene("res://level/mainUI/main_menu.tscn") # 启动主菜单

# 接收信号并执行场景切换
func switch_scene(packed_scene: PackedScene):
	if scene_container.get_child_count() > 0:
		scene_container.get_child(0).queue_free()
	var instance = packed_scene.instantiate()
	scene_container.add_child(instance)

# 供其他场景调用的统一接口
func go_to_scene(scene_path: String, use_loading_screen: bool =false):
	Loadmanager.load_scene(scene_path, use_loading_screen)

func show_settings():
	setting_panel.show_setting()
