extends Control

const RegisterLib = preload("uid://ehhn1k7v0g6w")
const BenchmarkFamilies = RegisterLib.BenchmarkFamilies
const ConsoleReporter = preload("uid://cp6jwltd8s2ur")

const RunnerSuite = preload("runner_suite.gd")
const RunnerPrealloc = preload("uid://6s5qd6by3jri")
const RunnerArraySize = preload("uid://c7t7mscufip1r")
const RunnerScenario = preload("runner_scenario.gd")
const RunnerReuse = preload("runner_reuse.gd")
const Run = preload("run.gd")
const COMPARE_SCENE := "res://bench/BenchCompare.tscn"
const SLIDES_SCENE := "res://bench/BenchSlides.tscn"

const _OPS:PackedStringArray = [
	"Store", "Load", "LoadReuse", "Spawn", "SpawnReuse", "Update", "UpdateReuse", "Peek",
	"Encode", "Decode", "ReadAll", "RoundTrip", "MetadataOnly", "RandomElement",
]

@onready var _suite:OptionButton = $Margin/VBox/Toolbar/Suite
@onready var _status:Label = $Margin/VBox/Toolbar/Status
@onready var _tree:Tree = $Margin/VBox/Benchmarks

var _bmf:BenchmarkFamilies
var _reporter:ConsoleReporter
var _runner:Object


class NameGroup:
	var title:String
	var rank:int
	var bench_names:Array[String] = []


class ParsedName:
	var title:String
	var rank:int
	var row:String


func _ready() -> void:
	# Template binaries drop --script. The token after -- selects a suite and
	# the process exits when that suite finishes. No token keeps this list.
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		get_tree().quit(Run.run_from_args(args))
		return
	if _tree == null or _suite == null:
		return

	_bmf = BenchmarkFamilies.GetInstance()
	_reporter = ConsoleReporter.new()
	_suite.clear()
	_suite.add_item("Scenarios")
	_suite.add_item("Suite")
	_suite.add_item("Pre-alloc")
	_suite.add_item("Array size")
	_suite.add_item("Reuse")
	_suite.select(0)

	_connect_toolbar()
	_use_suite("scenario")


func _connect_toolbar() -> void:
	var quit := $Margin/VBox/Toolbar/Quit as Button
	var compare := $Margin/VBox/Toolbar/Compare as Button
	var slides := $Margin/VBox/Toolbar/Slides as Button
	var run := $Margin/VBox/Toolbar/Run as Button
	var run_all := $Margin/VBox/Toolbar/RunAll as Button
	if quit != null and not quit.pressed.is_connected(_on_quit):
		if quit.pressed.connect(_on_quit) != OK:
			push_error("quit signal failed")
	if compare != null and not compare.pressed.is_connected(_on_compare):
		if compare.pressed.connect(_on_compare) != OK:
			push_error("compare signal failed")
	if slides != null and not slides.pressed.is_connected(_on_slides):
		if slides.pressed.connect(_on_slides) != OK:
			push_error("slides signal failed")
	if run != null and not run.pressed.is_connected(_on_run):
		if run.pressed.connect(_on_run) != OK:
			push_error("run signal failed")
	if run_all != null and not run_all.pressed.is_connected(_on_run_all):
		if run_all.pressed.connect(_on_run_all) != OK:
			push_error("run all signal failed")
	if not _suite.item_selected.is_connected(_on_suite_selected):
		if _suite.item_selected.connect(_on_suite_selected) != OK:
			push_error("suite signal failed")
	if not _tree.item_activated.is_connected(_on_run):
		if _tree.item_activated.connect(_on_run) != OK:
			push_error("tree signal failed")


func _on_quit() -> void:
	get_tree().quit()


func _on_compare() -> void:
	if get_tree().change_scene_to_file(COMPARE_SCENE) != OK:
		_status.text = "Could not open results"


func _on_slides() -> void:
	if get_tree().change_scene_to_file(SLIDES_SCENE) != OK:
		_status.text = "Could not open slides"


func _on_suite_selected(index:int) -> void:
	match index:
		1:
			_use_suite("suite")
		2:
			_use_suite("prealloc")
		3:
			_use_suite("array-size")
		4:
			_use_suite("reuse")
		_:
			_use_suite("scenario")


func _on_run() -> void:
	var spec := _selected_spec()
	if spec.is_empty():
		_status.text = "Select a benchmark"
		return
	await _run_spec(spec)


func _on_run_all() -> void:
	await _run_spec(".")


func _use_suite(which:String) -> void:
	match which:
		"prealloc":
			_runner = RunnerPrealloc.new()
		"array-size":
			_runner = RunnerArraySize.new()
		"suite":
			_runner = RunnerSuite.new()
		"reuse":
			_runner = RunnerReuse.new()
		_:
			_runner = RunnerScenario.new()
	_fill_tree()


func _collect_names() -> Array[String]:
	var found:Array[BenchmarkInstance] = []
	var bench_names:Array[String] = []
	if _bmf == null or not _bmf.FindBenchmarks(".", found):
		_status.text = "Could not list benchmarks"
		return bench_names
	for instance:BenchmarkInstance in found:
		bench_names.append(str(instance.name))
	return bench_names


func _fill_tree() -> void:
	var bench_names := _collect_names()
	_tree.clear()
	_tree.columns = 1
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "Benchmark")
	_tree.set_column_expand(0, true)
	var root := _tree.create_item()
	var select_item:TreeItem = null
	for group:NameGroup in _bucket(bench_names):
		var parent := _tree.create_item(root)
		parent.set_text(0, group.title)
		parent.set_metadata(0, "")
		for bench_name:String in group.bench_names:
			var item := _tree.create_item(parent)
			item.set_text(0, _row_label(bench_name))
			item.set_metadata(0, bench_name)
			item.set_tooltip_text(0, bench_name)
			if select_item == null:
				select_item = item
	if select_item != null:
		select_item.select(0)
	_status.text = "%d benchmarks" % bench_names.size()


func _bucket(bench_names:Array[String]) -> Array[NameGroup]:
	var groups:Array[NameGroup] = []
	for bench_name:String in bench_names:
		var parsed := _parse(bench_name)
		var group := _group_for(groups, parsed.title, parsed.rank)
		group.bench_names.append(bench_name)
	return groups


func _group_for(groups:Array[NameGroup], title:String, rank:int) -> NameGroup:
	for group:NameGroup in groups:
		if group.title == title:
			return group
	var created := NameGroup.new()
	created.title = title
	created.rank = rank
	var at := groups.size()
	for i in groups.size():
		if groups[i].rank > rank:
			at = i
			break
	if groups.insert(at, created) != OK:
		push_error("could not order benchmark group")
	return created


func _parse(bench_name:String) -> ParsedName:
	var parsed := ParsedName.new()
	var codec := "Benchmark"
	var rest := bench_name
	const flat := "BM_Flatbuffers_"
	const built_in := "BM_BuiltIn_"
	const dict_from_obj := "BM_DictFromObj_"
	const gdict := "BM_GDict_"
	if bench_name.begins_with(flat):
		codec = "FlatBuffers"
		rest = bench_name.substr(flat.length())
	elif bench_name.begins_with(built_in):
		codec = "Objects"
		rest = bench_name.substr(built_in.length())
	elif bench_name.begins_with(dict_from_obj):
		codec = "Dict from objects"
		rest = bench_name.substr(dict_from_obj.length())
	elif bench_name.begins_with(gdict):
		codec = "Dictionary"
		rest = bench_name.substr(gdict.length())

	var tail := ""
	var slash := rest.find("/")
	if slash >= 0:
		tail = " " + rest.substr(slash)
		rest = rest.substr(0, slash)

	var variant := ""
	var variant_rank := 0
	if rest.ends_with("PASR"):
		variant = "pre-allocate, static reader"
		variant_rank = 3
		rest = rest.substr(0, rest.length() - 4)
	elif rest.ends_with("PA"):
		variant = "pre-allocate"
		variant_rank = 1
		rest = rest.substr(0, rest.length() - 2)
	elif rest.ends_with("SR"):
		variant = "static reader"
		variant_rank = 2
		rest = rest.substr(0, rest.length() - 2)

	var op_rank := _OPS.size()
	for i in _OPS.size():
		if rest == _OPS[i]:
			op_rank = i
			break
	parsed.title = rest
	if not variant.is_empty():
		parsed.title = "%s  %s" % [rest, variant]
	parsed.rank = op_rank * 10 + variant_rank
	parsed.row = codec + tail
	return parsed


func _row_label(bench_name:String) -> String:
	return _parse(bench_name).row


func _selected_spec() -> String:
	if _tree == null:
		return ""
	var item := _tree.get_selected()
	if item == null:
		return ""
	var meta := _meta_text(item)
	if not meta.is_empty():
		return "^%s$" % _quote_re(meta)
	var parts:Array[String] = []
	for i in item.get_child_count():
		var child := item.get_child(i)
		var child_meta := _meta_text(child)
		if not child_meta.is_empty():
			parts.append(_quote_re(child_meta))
	if parts.is_empty():
		return ""
	return "^(%s)$" % "|".join(PackedStringArray(parts))


func _meta_text(item:TreeItem) -> String:
	var meta:Variant = item.get_metadata(0)
	if meta is String:
		return meta
	return ""


func _quote_re(text:String) -> String:
	var quoted := ""
	const special := ".^$|()[]{}*+?\\"
	for i in text.length():
		var ch := text[i]
		if special.contains(ch):
			quoted += "\\"
		quoted += ch
	return quoted


func _run_spec(spec:String) -> void:
	_status.text = "Running"
	await get_tree().process_frame
	var count := BenchLib.RunSpecifiedBenchmarks(_reporter, null, spec)
	if count == 0:
		_status.text = "No benchmarks matched"
	else:
		_status.text = "Finished %d" % count
