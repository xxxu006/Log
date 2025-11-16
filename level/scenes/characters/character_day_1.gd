extends Node2D

# Bug 视觉节点引用
@onready var bug_anim_3_1: AnimatedSprite2D = $BugVisual3_1 if has_node("BugVisual3_1") else null
@onready var bug_anim_3_2: AnimatedSprite2D = $BugVisual3_2 if has_node("BugVisual3_2") else null
@onready var bug_anim_3_3: AnimatedSprite2D = $BugVisual3_3 if has_node("BugVisual3_3") else null
@onready var animation_player = $AnimationPlayer
@onready var ending_sprite: Sprite2D = $EndingSprite if has_node("EndingSprite") else null

var has_played_enter_scene: bool = false

func _ready():
	# 初始停止并隐藏动画精灵
	if is_instance_valid(bug_anim_3_1):
		bug_anim_3_1.stop()
		bug_anim_3_1.hide()
	if is_instance_valid(bug_anim_3_2):
		bug_anim_3_2.stop()
		bug_anim_3_2.hide()
	if is_instance_valid(bug_anim_3_3):  # 修复：这里应该是 bug_anim_3_3
		bug_anim_3_3.stop()
		bug_anim_3_3.hide()
	
	if is_instance_valid(ending_sprite):
		ending_sprite.hide()
	
	# 连接动画完成信号
	if is_instance_valid(animation_player):
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
	
	if is_in_exploration_hub():
		# 播放进场动画（只播放一次）
		play_enter_scene_animation()
	else:
		print("当前不在探索中心场景，不播放进场动画")

func play_enter_scene_animation():
	if has_played_enter_scene:
		print("已经播放过进场动画，直接播放idle动画")
		play_idle_animation()
		return
		
	if animation_player and animation_player.has_animation("enter_scene"):
		print("播放进场动画")
		animation_player.play("enter_scene")
		has_played_enter_scene = true
	else:
		print("警告：找不到enter_scene动画或AnimationPlayer，直接播放idle动画")
		play_idle_animation()

func play_idle_animation():
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")
		print("播放idle动画")
	else:
		print("警告：找不到idle动画或AnimationPlayer")

# 显示或隐藏特定的BUG视觉效果
func show_bug_visual(bug_id: String, is_visible: bool): 
	print("角色: 显示 BUG '%s'" % [bug_id])
	var target_anim_sprite: AnimatedSprite2D = null
	match bug_id:
		"bug_3_1": target_anim_sprite = bug_anim_3_1
		"bug_3_2": target_anim_sprite = bug_anim_3_2
		"bug_3_3": target_anim_sprite = bug_anim_3_3
		_:
			print("角色：警告！未知的 bug_id: '%s'" % bug_id)
			return

	if not is_instance_valid(target_anim_sprite):
		print("角色：警告！找不到对应的 AnimatedSprite2D 节点 for '%s'" % bug_id)
		return

	if is_visible:
		# 显示 BUG
		print("角色：显示 BUG '%s' (Animated)" % bug_id)
		target_anim_sprite.show()
		# 播放默认动画
		target_anim_sprite.play()
	else:
		# 隐藏 BUG
		print("角色：隐藏 BUG '%s' (Animated)" % bug_id)
		target_anim_sprite.stop() # 停止播放动画
		target_anim_sprite.hide() # 隐藏节点

func _on_animation_finished(anim_name: String):
	print("角色动画完成: ", anim_name)
	
	# 如果进场动画播放完毕，自动切换到idle动画
	if anim_name == "enter_scene":
		print("进场动画完成，切换到idle动画")
		play_idle_animation()

# 检查当前是否在探索中心场景
func is_in_exploration_hub() -> bool:
	# 方法1：检查场景树中是否有探索中心的节点
	if get_tree().get_root().has_node("ExplorationHub") or get_tree().get_root().has_node("ExplorationCenter"):
		return true
	
	# 方法2：检查当前场景名称包含关键词
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_name = current_scene.name.to_lower()
		if "hub" in scene_name or "exploration" in scene_name or "center" in scene_name:
			return true
	
	# 方法3：打印调试信息
	print("当前场景: ", current_scene.name if current_scene else "null")
	print("场景文件路径: ", current_scene.scene_file_path if current_scene and current_scene.scene_file_path else "null")
	
	return false
## 隐藏结局图片
#func hide_ending_image():
	#if is_instance_valid(ending_sprite):
		#ending_sprite.hide()
		#print("角色: 隐藏结局图片")

#func show_ending_image(ending_id: String):
	#print("角色: 显示结局图片 - ", ending_id)
	#
	#if not is_instance_valid(ending_sprite):
		#print("错误：结局图片节点不存在")
		#return
	#
	## 根据结局ID加载对应的图片
	#var image_path = ""
	#match ending_id:
		#"ending_A", "A", "ending_a", "a":
			#image_path = "res://asset/人物/bug/ending1.png"
		#"ending_B", "B", "ending_b", "b":
			#image_path = "res://asset/人物/bug/ending2.png"
		#"ending_C", "C", "ending_c", "c":
			#image_path = "res://asset/人物/bug/ending3.png"  # 如果有第三个结局
		#_:
			#print("错误：未知的结局ID: ", ending_id)
			#return
	#
	#print("角色: 尝试加载图片路径: ", image_path)
	#var texture = load(image_path)
	#if texture:
		#print("角色: 图片加载成功")
		#ending_sprite.texture = texture
		#ending_sprite.show()
		#print("角色: 结局图片显示成功 - ", ending_id)
		#
		## 添加淡入效果
		#ending_sprite.modulate = Color(1, 1, 1, 0)
		#var tween = create_tween()
		#tween.tween_property(ending_sprite, "modulate", Color(1, 1, 1, 1), 1.0)
		#tween.tween_callback(_on_ending_image_shown.bind(ending_id))
	#else:
		#print("错误：无法加载结局图片: ", image_path)
		## 打印更多调试信息
		#print("文件是否存在: ", FileAccess.file_exists(image_path))
#
#func _on_ending_image_shown(ending_id: String):
	#print("角色: 结局图片显示完成 - ", ending_id)

# 启用或禁用特定 BugArea 的点击 
func set_bug_area_interaction_node(area_node: Area2D, enabled: bool):
	if is_instance_valid(area_node):
		area_node.monitoring = enabled
		area_node.monitorable = enabled
		# area_node.visible = enabled # 调试时显示区域
		print("角色：设置 BUG 区域 '%s' 交互为 %s" % [area_node.name, enabled])
	else:
		print("角色：错误！传入的 BugArea 节点无效！")
