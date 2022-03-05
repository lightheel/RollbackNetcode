extends Node

# ******************************************************************************

var world_avatar = null
var avatars := {}

var frame := 0
var local_target := 0
var input_buffer := []
var server_buffer := []

func _ready():
	Game.connect('scene_changed', self, 'scene_changed')
	Network.connect('peer_connected', self, 'create_peer')
	Network.connect('peer_disconnected', self, 'remove_peer')
	Network.connect('disconnected_from_server', self, 'remove_all_peers')

# ******************************************************************************

func scene_changed():
	for avatar in avatars.values():
		if is_instance_valid(avatar):
			avatar.queue_free()
	avatars.clear()
	if !Game.world.has_node('Spawns'):
		return
	if Network.connected:
		for id in Network.playerRegistry:
			create_peer(Network.playerRegistry[id])
		if !Network.isServer:
			rpc_id(1, "server_init")
	else:
		create_peer(Network.player_info)

func create_peer(pinfo):
	var id = pinfo.net_id
	
	if id == 1:
		return
	
	if Game.world:
		if !(id in avatars):
			create_avatar(pinfo)
		avatars[id].enter_world(Game.world)

	if pinfo.net_id == Network.net_id:
		Player.focus_avatar()

func create_avatar(pinfo):
	if !world_avatar:
		world_avatar = load('res://world_avatar/WorldAvatar.tscn')

	var avatar = world_avatar.instance()
	avatars[pinfo.net_id] = avatar
	avatar.player_info = pinfo
	return avatar

# ------------------------------------------------------------------------------

func remove_peer(pinfo):
	avatars[pinfo.net_id].queue_free()

func remove_all_peers():
	for avatar in avatars:
		avatars[avatar].queue_free()

# ******************************************************************************

func deactivate():
	send_command('deactivate')

func activate():
	send_command('activate')

func send_command(command, id=Network.net_id) -> void:
	if Network.connected:
		if Network.isServer:
			broadcast_command(command, id)
		else:
			rpc_id(1, 'broadcast_command', command, id)
	else:
		receive_command(command, id)
	
remote func broadcast_command(command, id) -> void:
	receive_command(command, id)
	rpc('receive_command', command, id)

remote func receive_command(command, id) -> void:
	if id in avatars:
		match command:
			'deactivate':
				avatars[id].deactivate()
			'activate':
				avatars[id].activate()

# ******************************************************************************

var input_map = {
	'run': false,
	'move_up': false,
	'move_down': false,
	'move_left': false,
	'move_right': false,
	'dance': false,
	'emote': false,
}

func clear_input():
	if Network.net_id in avatars:
		avatars[Network.net_id].clear_input()

# only used by local player
func handle_input(event):
	var local_event = event.to_dict()
	if Network.isServer:
		return

	if Network.net_id in avatars:

		#if local_event.pressed:
			if event.action in input_map:
				local_event.frame = frame + local_target
				input_buffer.append(local_event)

func local_input_buffer_tick():
	if !Network.connected:
		return

	cleanup_old_inputs()
	var i = 0
	while i < input_buffer.size():
		#Console.write_line('Input in buffer: ' + str(input_buffer[i]))
		if input_buffer[i].frame == frame:
			avatars[Network.net_id].handle_input(input_buffer[i])
			send_input(Network.net_id, input_buffer[i])
		i+=1
	#if input_buffer.size() == 0:
		#if Network.net_id in avatars:
			#avatars[Network.net_id].clear_input()

func cleanup_old_inputs():
	for input_ref in input_buffer:
		#print(input_ref)
		if input_ref.frame > frame:
			return
		if input_ref.frame < frame - 30:
			input_buffer.erase(input_ref)


# ------------------------------------------------------------------------------

func send_input(id, event):
	if Network.connected:
			rpc_id(1, 'broadcast_input', id, event)

# happens on the server
remote func broadcast_input(id, event):
	var server_input = {'id': id, "event": event}
	server_buffer.append(server_input)

func server_input_buffer_tick():
	#cleanup_server_inputs()
	var i = 0
	while i < server_buffer.size():
		if server_buffer[i].event.frame == frame:
			recieve_input(server_buffer[i].id, server_buffer[i].event)
			rpc('recieve_input', server_buffer[i].id, server_buffer[i].event)
			print('input matched frame on server')
			server_buffer.pop_at(i)
		i+=1
"""
func cleanup_server_inputs():
	for input_ref in server_buffer:
		#print(input_ref)
		if input_ref.event.frame > frame:
			return
		if input_ref.event.frame < frame - 60:
			server_buffer.erase(input_ref)
"""
# happens back on each client
remote func recieve_input(id, event):
	Console.write_line('Input received on frame: ' + str(frame) + ' from ID: ' + str(id))
	if id == Network.net_id:
		return

	if id in avatars:
		avatars[id].handle_input(event)
		#Console.write_line('Event: ' + str(event))
	elif !id in avatars:
		print("id not in list to move")

# ******************************************************************************

# only used by local player
func add_waypoint(pos, force):
	if Network.net_id in avatars:
		avatars[Network.net_id].add_waypoint(pos, force)

	if Network.isClient:
		rpc_id(1, 'broadcast_waypoint', Network.net_id, pos, force)

# happens on the server
remote func broadcast_waypoint(id, pos, force):
	recieve_waypoint(id, pos, force)
	rpc('recieve_waypoint', id, pos, force)

# happens back on each client
remote func recieve_waypoint(id, pos, force):
	if id == Network.net_id:
		return
	if id in avatars:
		avatars[id].add_waypoint(pos, force)

# ******************************************************************************

var client_rate = RateLimiter.new(0.5)
var server_rate = RateLimiter.new(0.5)
var states = {}

func _physics_process(delta):
	if !Network.connected:
		return

	if Network.isServer:
		frame = Engine.get_physics_frames()
		server_input_buffer_tick()
		if server_rate.check_time(delta):
			rpc('receive_sync_packet', states)

	if Network.isClient:
		local_input_buffer_tick()
		frame+=1
		if client_rate.check_time(delta):
			send_sync_packet()

func send_sync_packet():
	if Network.net_id in avatars:
		var packet = avatars[Network.net_id].get_state()
		rpc_id(1, 'server_receive_sync_packet', Network.net_id, packet)

# this happens on the server
remote func server_receive_sync_packet(id, packet):
	avatars[id].set_state(packet)
	states[id] = packet

# this happens on EVERY client
remote func receive_sync_packet(packet):
	for id in packet:
		if id == Network.net_id:
			return
		if id in avatars and is_instance_valid(avatars[id]):
			avatars[id].set_state(packet[id])

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
	var target_frame = rtt_frame + frame + 7
	var rtt_info = {'rtt': rtt_frame, 'frame': target_frame}
	rpc_id(id, 'set_client_timing', rtt_info)

remote func set_client_timing(rtt_info):
	frame = rtt_info.frame
	local_target = rtt_info.rtt
	Console.write_line('local frame:' + str(frame))
	Console.write_line('local target:' + str(local_target))
