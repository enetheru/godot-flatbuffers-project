@tool
extends EditorScript
const Runner = preload("runner_suite.gd")

func _run() -> void:
	var runner := Runner.new()
	runner._run()
