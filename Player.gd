extends Node2D

# ******************************************************************************

var frame := 0
var local_target := 0
var input_buffer := []

# ******************************************************************************

func _ready():
	InputManager.connect('input_event', self, 'handle_input')

var input_map = {
	ui_up = 'up',
	ui_left = 'left',
	ui_right = 'right',
	ui_down = 'down',
}

func handle_input(event):
	if Network.isServer:
		return

	var client_input_info := {}

	if event.pressed and event.action in input_map:
		client_input_info = {
			'id': Network.net_id, 
			'frame': (frame + local_target), 
			'input': input_map[event.action]
		}

	if event.is_action_pressed('ui_accept'):
		Console.write_line('local frame:' + str(frame))
		Console.write_line('local target:' + str(local_target))

	if client_input_info:
		input_buffer.append(client_input_info)
		rpc_id(1, 'add_input', client_input_info)
		Console.write_line(str(client_input_info))

var input_direction = {
	'up': Vector2(0, -10),
	'down': Vector2(0, 10),
	'left': Vector2(-10, 0),
	'right': Vector2(10, 0),
}

var last_applied_frame = 0

func _physics_process(delta):
	frame = Engine.get_physics_frames()

	while input_buffer:
		var frame_info = input_buffer.pop_front()
		position += input_direction[frame_info.input]

		# if frame_info.frame > last_applied_frame:
		# 	last_applied_frame = frame_info.frame


# ************************************************************************ 
# Sets up frame timing on local/server - sets RTT delay for inputs

remote func server_init():
	var id = get_tree().get_rpc_sender_id()
	send_init_reply(id)

func send_init_reply(id):
	rpc_id(id, 'receive_server_reply', frame)

remote func receive_server_reply(rtt_server_frame):
	var local_frame_cache = rtt_server_frame
	client_rtt_reply(local_frame_cache)

func client_rtt_reply(local_frame_cache):
	rpc_id(1, 'server_rtt_reply', local_frame_cache)

remote func server_rtt_reply(local_frame_cache):
	var id = get_tree().get_rpc_sender_id()
	var rtt_frame = frame - local_frame_cache
	var target_frame = rtt_frame + frame + 5
	# var target_frame = frame + 5
	var rtt_info = {'rtt': rtt_frame, 'frame': target_frame}
	rpc_id(id, 'set_client_timing', rtt_info)

remote func set_client_timing(rtt_info):
	frame = rtt_info.frame
	local_target = rtt_info.rtt
	Console.write_line('local frame:' + str(frame))
	Console.write_line('local target:' + str(local_target))

# ************************************************************************ 
# Server Input Functions

var fake_delay = 1.0

remote func add_input(input_info):

	# yield(get_tree().create_timer(fake_delay), 'timeout')

	input_buffer.append({'frame': input_info.frame, 'input': input_info.input})
	Console.write_line('rx:' + str(input_info) + ' at: ' + str(frame))
