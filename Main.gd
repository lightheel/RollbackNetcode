extends Node

func _ready():
	if Game.direct_launch:
		return

	if Args.server or OS.has_feature('server'): # set up server stuff
		Network.create_server()
		OS.set_window_title('Rollback Prototype - Server')
		return
	elif Args.connect: # automatically connect to server
		Network.join_server()
		OS.set_window_title('Rollback Prototype - Client')
		return

	# start game normally
	OS.set_window_title('Rollback Prototype')

	var scene = 'res://Lobby.tscn'
	if Args.scene:
		scene = Args.scene
	Game.load_scene(scene)
