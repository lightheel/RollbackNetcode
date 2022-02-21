extends Node

# ******************************************************************************

var _playback_cache := {}

func _pause_node(node: Node, value: bool):
	if node is AnimationPlayer:
		if value:
			_playback_cache[node.get_path()] = node.playback_active
			node.playback_active = false
		else:
			if node.get_path() in _playback_cache:
				node.playback_active = _playback_cache[node.get_path()]

	if node is AudioStreamPlayer or node is AnimatedSprite:
		if value:
			_playback_cache[node.get_path()] = node.playing
			node.playing = false
		else:
			if node.get_path() in _playback_cache:
				node.playing = _playback_cache[node.get_path()]

	node.set_process(!value)
	node.set_physics_process(!value)

func set_paused(node: Node, value: bool):
	for child in node.get_children():
		if child.get_child_count():
			set_paused(child, value)
		_pause_node(child, value)

func pause(node: Node):
	set_paused(node, true)

func resume(node: Node):
	set_paused(node, false)

# ******************************************************************************

var collision_cache := {}

func _set_collision_enabled(node: Node, value: bool):
	if !node.get('collision_layer'):
		return
	var path = node.get_path()

	prints(path, node.collision_layer, value)

	if !value:
		collision_cache[path] = { 
			layer = node.collision_layer,
			mask = node.collision_mask,
		}
		
		node.collision_layer = 0
		node.collision_mask = 0
	else:
		if path in collision_cache:
			node.collision_layer = collision_cache[path].layer
			node.collision_mask = collision_cache[path].mask

func set_collision_enabled(node: Node, value: bool):
	for child in node.get_children():
		if child.get_child_count():
			set_collision_enabled(child, value)
		_set_collision_enabled(child, value)

func enable_collision(node: Node):
	pass

func disable_collision(node: Node):
	pass

# ******************************************************************************

func attach_input_probe(node:Node):
	for child in node.get_children():
		if child.get_child_count():
			attach_input_probe(child)
		if node is Control:
			node.connect('gui_input', self, 'input_probe', [node.get_path()])

func input_probe(event, node):
	print(node, ' ', event)

# ******************************************************************************

func vec_to_dict(vec):
	var dict := {}

	dict['x'] = vec.x
	dict['y'] = vec.y
	if vec is Vector3:
		dict['z'] = vec.z

	return dict

func dict_to_vec(dict):
	if 'z' in dict:
		return Vector3(dict.x, dict.y, dict.z)
	return Vector2(dict.x, dict.y)
