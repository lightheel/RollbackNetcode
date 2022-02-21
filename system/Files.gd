tool
extends Node

# ******************************************************************************

func get_files(path, ext=''):
	var files = []
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			if ext:
				if file.ends_with(ext):
					files.append(file)
			else:
				files.append(file)

	dir.list_dir_end()

	return files

# ------------------------------------------------------------------------------

var file_prefix

func _ready():
	if OS.has_feature("standalone"):
		file_prefix = 'user://'
	else:
		file_prefix = 'res://data/'

func save_json(file_name: String, data):
	var f = File.new()
	f.open(file_prefix + file_name, File.WRITE)
	f.store_string(JSON.print(data, "\t"))
	f.close()

func load_json(file_name: String):
	var result = null
	var f = File.new()
	if f.file_exists(file_prefix + file_name):
		f.open(file_prefix + file_name, File.READ)
		var text = f.get_as_text()
		f.close()
		result = JSON.parse(text).result
	return result