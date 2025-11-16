extends CanvasLayer


signal loading_screen_has_full_coverage

@onready var animationplayer:AnimationPlayer=$AnimationPlayer
@onready var progressBar:ProgressBar=$Panel/ProgressBar
func _update_progress_bar(new_value:float)->void:
	if progressBar:
		progressBar.value = new_value * 100
	else:
		print("ProgressBar is not ready yet.")
	
func _start_outro_animation()->void:
	await Signal(animationplayer,'animation_finished')
	emit_signal("loading_screen_has_full_coverage")
	await Signal(animationplayer,'animation_finished')
	queue_free()
