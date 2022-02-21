extends Node

# ******************************************************************************

func _ready():
	Console.exec_locals = {
		'Game': Game
	}

	Console.add_command('load_scene', self, 'load_scene')\
		.add_argument('scene', TYPE_STRING)\
		.set_description('Change the currently loaded scene.')\
		.register()

	Console.add_command('color_test', self, 'color_test')\
		.set_description('Prints the colors supported by the console')\
		.register()

# ******************************************************************************

var colors = [
	'aqua',
	'black',
	'blue',
	'fuchsia',
	'gray',
	'green',
	'lime',
	'maroon',
	'navy',
	'purple',
	'red',
	'silver',
	'teal',
	'white',
	'yellow',
]

func color_test():
	Console.write_line('Printing test colors')
	for color in colors:
		Console.write_line('[color=%s][%s][/color]' % [color, color])

# ------------------------------------------------------------------------------

func load_scene(scene):
	Game.load_scene(scene)
	Console.toggle_console()