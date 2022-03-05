extends Node
class_name FakeEvent

# ******************************************************************************

# this is a dummy class that lets us pretend to send actions across the network

var action = ''
var pressed = false
var frame = 0

func _init(name='', value=false):
	action = name
	pressed = value

func is_action_pressed(name):
	if action == name:
		return pressed
		
func is_action_released(name):
	if action == name:
		return !pressed

func to_dict():
	return {
		'action': action,
		'pressed': pressed,
		'frame': frame,
	}

func from_dict(dict):
	action = dict.action
	pressed = dict.pressed
	return self

func _to_string():
	return '[FakeEvent:RID] <%s, %s>' % [action, pressed]
