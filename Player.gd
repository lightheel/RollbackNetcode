extends Node2D

var server_frame = 0
var local_frame = 0
var local_target = 0

var local_input_buffer = []
var server_input_buffer = []

func _ready():
	if !Args.server:
		rpc_id(1, "server_init")
	pass

func _input(event):
	if !Args.server:
		if event.is_action_pressed("ui_up"):
			#print("up received")
			local_input_buffer.append({"frame": (local_frame + local_target), "input": "up"})
			var client_input_info = {"frame": (local_frame + local_target), "input": "up"}
			rpc_id(1, "add_input", client_input_info)
		elif event.is_action_pressed("ui_left"):
			#print("left received")
			local_input_buffer.append({"frame": (local_frame + local_target), "input": "left"})
			var client_input_info = {"frame": (local_frame + local_target), "input": "left"}
			rpc_id(1, "add_input", client_input_info)
		elif event.is_action_pressed("ui_right"):
			#print("right received")
			local_input_buffer.append({"frame": (local_frame + local_target), "input": "right"})
			var client_input_info = {"frame": (local_frame + local_target), "input": "right"}
			rpc_id(1, "add_input", client_input_info)
		elif event.is_action_pressed("ui_down"):
			#print("down received")
			local_input_buffer.append({"frame": (local_frame + local_target), "input": "down"})
			var client_input_info = {"frame": (local_frame + local_target), "input": "down"}
			rpc_id(1, "add_input", client_input_info)
		elif event.is_action_pressed("ui_select"):
			var last_buffer_entry = local_input_buffer.size()
			print(local_input_buffer[last_buffer_entry - 1])
		elif event.is_action_pressed("ui_accept"):
			print("local frame:", local_frame)
			print("local target:", local_target)

func _process(delta):
	if Args.server:
		server_frame = server_frame + 1
		for i in server_input_buffer.size():
			if server_input_buffer[i].frame == server_frame:
				if server_input_buffer[i].input == "up":
					position = position - Vector2(0, 10)
				elif server_input_buffer[i].input == "down":
					position = position + Vector2(0, 10)
				elif server_input_buffer[i].input == "left":
					position = position - Vector2(10, 0)
				elif server_input_buffer[i].input == "right":
					position = position + Vector2(10, 0)
				i+=1
	elif !Args.server:
		if local_frame != 0:
			local_frame = local_frame + 1
		for i in local_input_buffer.size():
			if local_input_buffer[i].frame == local_frame:
				if local_input_buffer[i].input == "up":
					position = position - Vector2(0, 10)
				elif local_input_buffer[i].input == "down":
					position = position + Vector2(0, 10)
				elif local_input_buffer[i].input == "left":
					position = position - Vector2(10, 0)
				elif local_input_buffer[i].input == "right":
					position = position + Vector2(10, 0)
				i+=1

# ************************************************************************ Sets up frame timing on local/server - sets RTT delay for inputs

remote func server_init():
	var id = get_tree().get_rpc_sender_id()
	send_init_reply(id)

func send_init_reply(id):
	rpc_id(id, "receive_server_reply", server_frame)

remote func receive_server_reply(rtt_server_frame):
	var local_frame_cache = rtt_server_frame
	client_rtt_reply(local_frame_cache)

func client_rtt_reply(local_frame_cache):
	rpc_id(1, "server_rtt_reply", local_frame_cache)

remote func server_rtt_reply(local_frame_cache):
	var id = get_tree().get_rpc_sender_id()
	var rtt_frame = server_frame - local_frame_cache
	var target_frame = rtt_frame + server_frame + 5
	var rtt_info = {"rtt": rtt_frame, "frame": target_frame}
	rpc_id(id, "set_client_timing", rtt_info)

remote func set_client_timing(rtt_info):
	local_frame = rtt_info.frame
	local_target = rtt_info.rtt
	print("local frame:", local_frame)
	print("local target:", local_target)

	# ************************************************************************ Server Input Functions

remote func add_input(input_info):
	server_input_buffer.append({"frame": input_info.frame, "input": input_info.input})
	print("server input added")
