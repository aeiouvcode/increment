extends "res://main.gd"
var header_calls: = 0
func _header() -> void:
	header_calls += 1
	super._header()
