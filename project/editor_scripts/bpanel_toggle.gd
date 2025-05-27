@tool
extends EditorScript

const Bpanel = preload('res://bpanel/bpanel.gd')

func _run() -> void:
	Bpanel.bpanel_toggle()
