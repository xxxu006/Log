extends TextureButton

@export var dfault:Texture
@export var open: Texture
@export var btn: TextureButton
@export var panel2:Panel
@onready var panel1:Panel= $"../../Panel"

func _ready():
	pressed.connect(open_panel)
	
func open_panel():
	panel1.visible=true
	panel2.visible=false
	btn.texture_normal = dfault
	texture_normal =open
