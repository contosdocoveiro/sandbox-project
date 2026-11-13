extends Node

var failures := 0
var checked := 0

func _ready() -> void:
	for scan_root in ["res://actors", "res://components", "res://services", "res://world", "res://dev", "res://tests", "res://shaders"]:
		_scan(scan_root)
	print("RESOURCE LOAD CHECK: %d resources, %d failures" % [checked, failures])
	get_tree().quit(failures)

func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_scan(full)
		elif entry.ends_with(".tscn") or entry.ends_with(".tres") or entry.ends_with(".gd"):
			checked += 1
			var res := load(full)
			if res == null:
				push_error("Failed to load %s" % full)
				failures += 1
		entry = dir.get_next()
	dir.list_dir_end()