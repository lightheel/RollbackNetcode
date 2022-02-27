extends Node2D

# ******************************************************************************

onready var camera: Node = $Camera

# ******************************************************************************

func _ready() -> void:
	InputManager.register(self)

# ------------------------------------------------------------------------------

var world_avatar setget , get_world_avatar

func get_world_avatar():
	if Network.net_id in AvatarManager.avatars:
		return AvatarManager.avatars[Network.net_id]
	return null

func focus_avatar():
	if Network.net_id in AvatarManager.avatars:
		camera.follow(get_world_avatar(), Vector2(1.5, 1.5))

# ******************************************************************************

var menu_stack = []

func push_menu(menu):
	menu_stack.push_front(menu)

func pop_menu():
	menu_stack.pop_front()

# ------------------------------------------------------------------------------

var input_proxy = null

func set_input_proxy(proxy=null) -> void:
	input_proxy = proxy
	AvatarManager.clear_input()

# ------------------------------------------------------------------------------

func handle_input(event) -> void:
	if Console.Line.has_focus():
		return

	# if menu_stack and menu_stack[0].has_method('handle_input'):
	# 	menu_stack[0].handle_input(event)
	# 	return

	if input_proxy:
		if input_proxy.has_method('handle_input'):
			input_proxy.handle_input(event)
		return

	# if current_battle:
	# 	current_battle.handle_input(event)
	# 	return
			
	AvatarManager.handle_input(event)
