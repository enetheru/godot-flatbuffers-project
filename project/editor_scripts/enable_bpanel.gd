@tool
extends EditorScript

func _run() -> void:
	FlatBuffersPlugin._prime.disable_bottom_panel()
	FlatBuffersPlugin._prime.enable_bottom_panel()
