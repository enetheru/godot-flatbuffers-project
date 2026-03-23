@tool
extends EditorScript
const Runner = preload("runner_suite.gd")
const BenchGenerated = preload("uid://ddiycsgeokhmv")

func _run() -> void:
	var _bmf := BenchLib.GetInstance()
	var runner := Runner.new()
	runner._run()
