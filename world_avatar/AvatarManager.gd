extends Node

# ******************************************************************************

var world_avatar = null
var avatars := {}

var frame := 0
var local_target := 0
#var input_buffer := []

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
	if Network.isServer:
		return

	var client_input_info := {}

	if Network.net_id in avatars:
		avatars[Network.net_id].handle_input(event)

		if event.action in input_map:
			client_input_info = {
				'id': Network.net_id, 
				'frame': (frame + local_target), 
				'event': event.action
			}
		
		if client_input_info:
			#input_buffer.append(client_input_info)
			send_input(Network.net_id, client_input_info)

# ------------------------------------------------------------------------------

func send_input(id, client_input_info):
	if Network.connected:
		rpc_id(1, 'broadcast_input', client_input_info.id, client_input_info)

# happens on the server
remote func broadcast_input(id, client_input_info):
	recieve_input(id, client_input_info)
	rpc('recieve_input', id, client_input_info)

# happens back on each client
remote func recieve_input(id, client_input_info):
	if id == Network.net_id:
		return
	var event = client_input_info.event
	if client_input_info.frame == frame:
		if id in avatars:
			avatars[id].handle_input(event)

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
	frame = Engine.get_physics_frames()

	if !Network.connected:
		return

	if Network.isServer:
		if server_rate.check_time(delta):
			rpc('receive_sync_packet', states)

	if Network.isClient:
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
	var target_frame = rtt_frame + frame + 5
	var rtt_info = {'rtt': rtt_frame, 'frame': target_frame}
	rpc_id(id, 'set_client_timing', rtt_info)

remote func set_client_timing(rtt_info):
	frame = rtt_info.frame
	local_target = rtt_info.rtt
	Console.write_line('local frame:' + str(frame))
	Console.write_line('local target:' + str(local_target))
