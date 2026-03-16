extends Node

const BenchmarkFamilies = BenchLib.BenchmarkFamilies
const BenchmarkInstance = BenchLib.BenchmarkInstance
const ConsoleReporter = preload("uid://cp6jwltd8s2ur")


const Runner = preload("runner_suite.gd")


@onready var rich_text_label: RichTextLabel = $RichTextLabel

var bmf:BenchmarkFamilies
var reporter:ConsoleReporter = ConsoleReporter.new()


func _on_meta_clicked( meta:String ) -> void:
	if meta == "quit":
		get_tree().quit()
		return

	var spec:String
	if meta == "all": spec = "."
	else: spec = "^%s$" % meta

	var bmis:Array[BenchmarkInstance]
	if not bmf.FindBenchmarks(spec, bmis):
		printerr("FindBenchmarks encountered an error")
		get_tree().quit()
		return

	if bmis.is_empty():print("FindBenchmarks found no Benchmarks")
	var _num_completed:int = BenchLib.RunSpecifiedBenchmarks(
			reporter, null, spec)


func _init() -> void:
	bmf = BenchLib.BenchmarkFamilies.GetInstance()
	var _runner := Runner.new()


func _ready() -> void:
	rich_text_label.text = "[url=quit]quit[/url]\n\n"
	rich_text_label.append_text("[url=all]all[/url]\n\n")
	if rich_text_label.meta_clicked.connect(_on_meta_clicked) != OK:
		printerr("Failed to connect rtl.meta_clicked signal")
		get_tree().quit()
		return


	var bmis:Array[BenchmarkInstance]
	if not bmf.FindBenchmarks(".", bmis):
		printerr("FindBenchmarks encountered an error")
		get_tree().quit()
		return


	for instance:BenchmarkInstance in bmis:
		rich_text_label.append_text("[url=%s]%s[/url]\n" % [
			instance.name, instance.name ])
