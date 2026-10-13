@tool
extends EditorScript

const Run = preload("run.gd")


func _run() -> void:
	if Run.run_from_args(PackedStringArray()) != 0:
		printerr("benchmark run failed")
