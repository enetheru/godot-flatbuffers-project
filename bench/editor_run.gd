@tool
extends EditorScript
const Runner = preload("suite_runner.gd")

func _run() -> void:
	var runner := Runner.new()
	runner._run()
