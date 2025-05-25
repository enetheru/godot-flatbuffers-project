@tool
extends EditorScript

const Test = preload('res://tests/test.gd')

func _run() -> void:
	var tester = Test.new()
	tester._run()
