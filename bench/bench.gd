extends Node

const Runner = preload("suite_runner.gd")

func _ready() -> void:
	var runner := Runner.new()
	runner._run()
	get_tree().quit()
