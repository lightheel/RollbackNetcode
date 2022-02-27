extends KinematicBody2D
class_name WorldAvatar

# ******************************************************************************

onready var nameplate = $Nameplate
onready var body = $Body
onready var danceBody = $DanceBody
# onready var cosmetics = $Cosmetics
onready var movement = $Movement
onready var interactors = $Interactors

var player_info = null

var walkDirections = {
	0: "UpLeft",
	1: "Up",
	2: "UpRight",
	3: "Right",
	4: "DownRight",
	5: "Down",
	6: "DownLeft",
	7: "Left",
}

var danceDirections = {
	0: "DanceJump", # UpLeft
	1: "DanceBlursed", # Up
	2: "", # UpRight
	3: "Dance", # Right
	4: "Yeahbaby", # DownRight
	5: "DanceLow", # Down
	6: "Heyayaya", # DownLeft
	7: "DanceTaunt", # Left
}

var emoteDirections = {
	0: "", # UpLeft
	1: "", # Up
	2: "", # UpRight
	3: "", # Right
	4: "", # DownRight
	5: "Dab", # Down
	6: "", # DownLeft
	7: "", # Left
}

# ******************************************************************************

var slope = null
var cell = null

func _ready():
	if player_info:
		nameplate.text = player_info.name
#		if "core_data_lori" in player_info.key_items:
#			cosmetics.toggle_wings(true)
	$TileDetector.connect('body_entered', self, '_on_body_entered')
	$TileDetector.connect('body_exited', self, '_on_body_exited')

# ******************************************************************************

func find_region_handler(tilemap):
	if tilemap.has_method('enter_region'):
		return tilemap
	else:
		if tilemap.get_parent():
			return find_region_handler(tilemap.get_parent())
	return null

func _on_body_entered(tilemap):
	if tilemap.name == 'Slopes':
		# print('entering slope')
		slope = tilemap
		
	if player_info and player_info.net_id == Network.net_id:
		var handler = find_region_handler(tilemap)
		if handler:
			handler.enter_region(tilemap.name)

func _on_body_exited(tilemap):
	if tilemap.name == 'Slopes':
		# print('leaving slope')
		slope = null
		cell = null

	if player_info and player_info.net_id == Network.net_id:
		var handler = find_region_handler(tilemap)
		if handler:
			handler.leave_region(tilemap.name)

# ******************************************************************************

func enter_world(world: Node):
	if !world.has_node('Spawns/Default'):
		return
	world.add_child(self)

	var spawn_name = 'Default'
	var spawns = world.get_node('Spawns')

	if Game.continuing:
		position = Utils.dict_to_vec(Game.data.position)
		Game.continuing = false
	else:
		if Game.direct_launch:
			if spawns.has_node('Dev'):
				spawn_name = 'Dev'
		if Game.requested_spawn:
			if spawns.has_node(Game.requested_spawn):
				spawn_name = Game.requested_spawn
				

		position = spawns.get_node(spawn_name).position
	
	interactors.current_interactable = null
	visible = true

func activate():
	visible = true
	clear_input()

func deactivate():
	visible = false
	clear_input()

# ******************************************************************************

var input_state = {
	'run': false,
	'move_up': false,
	'move_down': false,
	'move_left': false,
	'move_right': false,
	'dance': false,
	'emote': false,
	'activate': false,
}

func clear_input():
	for input in input_state:
		input_state[input] = false

func handle_input(event):
	if event.action in input_state:
		input_state[event.action] = event.pressed

func _input(event):
	if player_info and player_info.net_id != Network.net_id:
		return

	if event is InputEventKey:
		if event.pressed:
			if event.as_text() == 'F3':
				movement_enabled = !movement_enabled
			# if event.as_text() == 'F1':
			# 	if "core_data_lori" in Player.inventory.key_items:
			# 		cosmetics.toggle_wings()
			# if event.as_text() == 'F2':
			# 	cosmetics.toggle_shades()
			# if event.as_text() == 'F4':
			# 	if "positron_chair" in Player.inventory.key_items:
			# 		cosmetics.toggle_positron_chair()

# ------------------------------------------------------------------------------

var waypoint = null
var waypoint_path := []

func add_waypoint(pos: Vector2, force=false):
	if force:
		clear_waypoint()
	var nav = get_parent().find_node("Navigation", true)
	if nav:
		var path = Array(nav.get_simple_path(global_position, pos, true))

		if !waypoint:
			waypoint = path[0]
		waypoint_path += path
	else:
		if !waypoint:
			waypoint = pos
		else:
			waypoint_path.append(pos)

func clear_waypoint():
	waypoint = null
	waypoint_path.clear()

func update_waypoint():
	if waypoint and global_position.distance_to(waypoint) < 1:
		waypoint = null

	if !waypoint and waypoint_path:
		waypoint = waypoint_path.pop_front()

# ------------------------------------------------------------------------------

var target = null

func follow(node):
	if is_instance_valid(node) and node.is_inside_tree():
		target = node

func clear_target():
	target = null

# ------------------------------------------------------------------------------

var direction := 0
var velocity := Vector2()
var speed := 0.0
var movement_enabled = true
var dead := false

func _physics_process(delta):
	if dead:
		return

	speed = movement.calculate_speed()
	body.speed_scale = speed
	danceBody.speed_scale = speed

	if input_state['dance']:
		dance()
		return
	if input_state['emote']:
		emote()
		return

	danceBody.visible = false
	body.visible = true
	
	if player_info and player_info.net_id == Network.net_id:
		if input_state['activate']:
			input_state['activate'] = false
			interactors.attempt_interaction()

	var isometric_velocity
	velocity = movement.calculate_velocity()
	if velocity:
		# direct control
		clear_waypoint()
		clear_target()
		isometric_velocity = movement.calculate_isometric_velocity(velocity)
		if movement_enabled:
			move_and_collide(isometric_velocity * speed)
	else:
		# auto movement
		if target and is_instance_valid(target):
			# target following
			velocity = global_position.direction_to(target.global_position)

			var distance = global_position.distance_to(target.global_position)
			if distance < 1:
				speed *= distance
		else:
			# waypoint movement
			update_waypoint()
			if waypoint:
				velocity = global_position.direction_to(waypoint)
		
		# apply auto movement
		if slope:
			velocity = movement.calculate_slope(movement.calculate_isometric_velocity(velocity))
		if movement_enabled and is_inside_tree():
			move_and_collide(velocity * speed)

	# make animations match movement
	if velocity:
		direction = movement.calculate_direction(velocity)

		var floating = false
		# if cosmetics.positron_chair.visible:
		# 	floating = true
		# if cosmetics.wings.visible and input_state['run']:
		# 	floating = true
			
		if floating:
			glide()
		else:
			walk()
		play_footstep_sound()
	else:
		idle()

	# if player_info and player_info.net_id == Network.net_id:
	# 	Game.data.position = Utils.vec_to_dict(Vector2(position))
	# 	Game.save_requested = true

	# cosmetics.update()
	if isometric_velocity:
		interactors.rotate_interactors(isometric_velocity)
		interactors.check_tooltip()

# ******************************************************************************

var walking = false

func walk():
	body.direction = direction
	body.walking = true
	walking = true
	# $PositronChairSounds.playing = false

func glide():
	body.direction = direction
	body.gliding = false
	walking = false
	# $PositronChairSounds.playing = true
	# $PositronChairSounds.pitch_scale = 1.2

func idle():
	body.walking = false
	# body.frame = direction
	# $PositronChairSounds.playing = false

# ------------------------------------------------------------------------------

var footstep_sounds = [
	preload('res://assets/sound/environment/footstep_factory_over_1.wav'),
	preload('res://assets/sound/environment/footstep_factory_over_2.wav'),
	preload('res://assets/sound/environment/footstep_factory_over_3.wav'),
	preload('res://assets/sound/environment/footstep_factory_over_4.wav'),
]

onready var footstep_player = {
	true: $FootstepSound1,
	false: $FootstepSound2,
}

var last_frame = 0
var last_anim = ''
var frame_count = 0
var audio_player = false

func play_footstep_sound():
	pass
	# if !visible or (body.frame == last_frame and body.animation == last_anim):
	# 	return
	# if !walking:
	# 	return
	# last_frame = body.frame
	# last_anim = body.animation
	# if frame_count >= 3:
	# 	frame_count = 0
	# 	footstep_player[audio_player].pitch_scale = rand_range(.9, 1.1)
	# 	footstep_player[audio_player].stream = footstep_sounds[randi() % footstep_sounds.size()]
	# 	footstep_player[audio_player].play()
	# 	audio_player = !audio_player
	# frame_count += 1

# ******************************************************************************

func dance():
	var danceName = danceDirections[direction]
	if danceName:
		# cosmetics.shades.visible = false
		# if !(direction in [4, 5, 6]):
		# 	cosmetics.wings.hide()
		body.visible = false
		danceBody.visible = true
		danceBody.play(danceName)

func emote():
	var emoteName = emoteDirections[direction]
	if emoteName:
		# cosmetics.shades.visible = false
		body.visible = false
		danceBody.visible = true
		danceBody.play(emoteName)

func die():
	dead = true
#	body.play('Fall')

# ******************************************************************************

func get_item():
	direction = 5
	# cosmetics.update()
#	body.play('GetItem')

# ******************************************************************************

func get_state():
	return {
		pos = global_position,
		input = input_state,
		vis = visible,
		# cos = cosmetics.get_state(),
	}

func set_state(dict):
	global_position = dict['pos']
	input_state = dict['input']
	visible = dict['vis']
	# cosmetics.set_state(dict['cos'])
