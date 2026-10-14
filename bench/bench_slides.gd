extends Control

## One scenario operation per page, with the timer boundary and the latest saved rows.

const ConsoleReporter = preload("uid://cp6jwltd8s2ur")
const RunnerScenario = preload("runner_scenario.gd")
const HistoryReporter = preload("history_reporter.gd")

const HISTORY_PATH := "res://bench/results/history.tres"
const BENCH_SCENE := "res://bench/BenchScene.tscn"
const _CODECS:PackedStringArray = ["Flatbuffers", "BuiltIn", "GDict"]
const _TARGETS:PackedStringArray = ["editor", "template_debug", "template_release"]
const _COLOR_FLAT := Color(0.45, 0.78, 0.95)
const _COLOR_GODOT := Color(0.95, 0.55, 0.32)
const _COLOR_DICT := Color(0.72, 0.55, 0.9)
const _COLOR_AXIS := Color(0.78, 0.78, 0.82)
const _COLOR_GRID := Color(1, 1, 1, 0.08)
const _COLOR_PANEL := Color(0.11, 0.11, 0.13)
const _COLOR_TEXT := Color(0.9, 0.9, 0.93)
const _COLOR_MARK := Color(1, 1, 1, 0.05)

@onready var _back:Button = $Margin/VBox/Toolbar/Back
@onready var _prev:Button = $Margin/VBox/Toolbar/Prev
@onready var _next:Button = $Margin/VBox/Toolbar/Next
@onready var _index_label:Label = $Margin/VBox/Toolbar/Index
@onready var _target:OptionButton = $Margin/VBox/Toolbar/Target
@onready var _rerun:Button = $Margin/VBox/Toolbar/Rerun
@onready var _lamp:ColorRect = $Margin/VBox/Toolbar/Lamp
@onready var _busy_text:Label = $Margin/VBox/Toolbar/Busy
@onready var _busy_bar:ProgressBar = $Margin/VBox/BusyBar
@onready var _title:Label = $Margin/VBox/Scroll/Body/Title
@onready var _times:Label = $Margin/VBox/Scroll/Body/Times
@onready var _shows:Label = $Margin/VBox/Scroll/Body/Shows
@onready var _runs_chart:Control = $Margin/VBox/Scroll/Body/RunsChart
@onready var _targets_chart:Control = $Margin/VBox/Scroll/Body/TargetsChart
@onready var _source:Label = $Margin/VBox/Scroll/Body/Source

class Slide:
	var op:String
	var times:String
	var shows:String


class BarGroup:
	var unix_s:int
	var stamp:String
	var rows:Array[BenchResult] = []


class BarHit:
	var rect:Rect2
	var row:BenchResult


var _rows:Array[BenchResult] = []
var _slides:Array[Slide] = []
var _index := 0
var _busy := false
var _runner:Object
var _runs_hits:Array[BarHit] = []
var _targets_hits:Array[BarHit] = []
var _runs_hover := -1
var _targets_hover := -1


func _ready() -> void:
	if _title == null or _target == null or _rerun == null:
		return
	_slides = _make_slides()
	_target.clear()
	for target_name:String in _TARGETS:
		_target.add_item(target_name)
	_target.select(_TARGETS.size() - 1)
	_busy_bar.min_value = 0
	_busy_bar.max_value = float(_CODECS.size())
	_busy_bar.value = 0
	_connect_toolbar()
	_connect_charts()
	_set_running(false, "")
	_load_rows()
	_show_slide()


func _unhandled_input(event:InputEvent) -> void:
	if _busy:
		return
	if event.is_action_pressed("ui_left"):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_step(1)
		get_viewport().set_input_as_handled()


func _connect_toolbar() -> void:
	if not _back.pressed.is_connected(_on_back):
		if _back.pressed.connect(_on_back) != OK:
			push_error("back signal failed")
	if not _prev.pressed.is_connected(_on_prev):
		if _prev.pressed.connect(_on_prev) != OK:
			push_error("prev signal failed")
	if not _next.pressed.is_connected(_on_next):
		if _next.pressed.connect(_on_next) != OK:
			push_error("next signal failed")
	if not _rerun.pressed.is_connected(_on_rerun):
		if _rerun.pressed.connect(_on_rerun) != OK:
			push_error("rerun signal failed")
	if not _target.item_selected.is_connected(_on_target_selected):
		if _target.item_selected.connect(_on_target_selected) != OK:
			push_error("target signal failed")


func _connect_charts() -> void:
	if _runs_chart == null or _targets_chart == null:
		return
	if not _runs_chart.draw.is_connected(_draw_runs_chart):
		if _runs_chart.draw.connect(_draw_runs_chart) != OK:
			push_error("runs chart draw failed")
	if not _runs_chart.gui_input.is_connected(_on_runs_input):
		if _runs_chart.gui_input.connect(_on_runs_input) != OK:
			push_error("runs chart input failed")
	if not _runs_chart.mouse_exited.is_connected(_on_runs_exit):
		if _runs_chart.mouse_exited.connect(_on_runs_exit) != OK:
			push_error("runs chart exit failed")
	if not _runs_chart.resized.is_connected(_runs_chart.queue_redraw):
		if _runs_chart.resized.connect(_runs_chart.queue_redraw) != OK:
			push_error("runs chart resize failed")
	if not _targets_chart.draw.is_connected(_draw_targets_chart):
		if _targets_chart.draw.connect(_draw_targets_chart) != OK:
			push_error("targets chart draw failed")
	if not _targets_chart.gui_input.is_connected(_on_targets_input):
		if _targets_chart.gui_input.connect(_on_targets_input) != OK:
			push_error("targets chart input failed")
	if not _targets_chart.mouse_exited.is_connected(_on_targets_exit):
		if _targets_chart.mouse_exited.connect(_on_targets_exit) != OK:
			push_error("targets chart exit failed")
	if not _targets_chart.resized.is_connected(_targets_chart.queue_redraw):
		if _targets_chart.resized.connect(_targets_chart.queue_redraw) != OK:
			push_error("targets chart resize failed")


func _on_back() -> void:
	if _busy:
		return
	if get_tree().change_scene_to_file(BENCH_SCENE) != OK:
		_busy_text.text = "Could not open the bench list"


func _on_prev() -> void:
	_step(-1)


func _on_next() -> void:
	_step(1)


func _on_target_selected(_which:int) -> void:
	if _busy:
		return
	_show_slide()


func _step(delta:int) -> void:
	if _busy or _slides.is_empty():
		return
	var nxt := _index + delta
	if nxt < 0 or nxt >= _slides.size():
		return
	_index = nxt
	_show_slide()


func _on_rerun() -> void:
	if _busy or _slides.is_empty():
		return
	var slide := _slides[_index]
	var target_name := _process_target()
	var history := HistoryReporter.new(ProjectSettings.globalize_path(HISTORY_PATH), target_name, "scenario")
	if not history.open_error.is_empty():
		_source.text = history.open_error
		return

	var console := ConsoleReporter.new()
	var missed := ""
	_set_running(true, "Checking the payload")
	await RenderingServer.frame_post_draw
	if _runner == null:
		_runner = RunnerScenario.new()

	for i in _CODECS.size():
		var codec := _CODECS[i]
		_busy_bar.value = float(i)
		_busy_text.text = "Working    %s    %s    %d / %d" % [
			slide.op, _codec_label(codec), i + 1, _CODECS.size(),
		]
		await RenderingServer.frame_post_draw
		var spec := "^BM_%s_%s$" % [codec, slide.op]
		var count := BenchLib.RunSpecifiedBenchmarks(console, history, spec)
		if count == 0:
			missed = "No benchmark matched %s" % spec
			break
		_busy_bar.value = float(i + 1)
		await RenderingServer.frame_post_draw

	history.close()
	if missed.is_empty():
		_set_running(false, "Idle")
	else:
		_set_running(false, missed)
	if not history.open_error.is_empty():
		_source.text = history.open_error
		return
	_select_target(target_name)
	_load_rows()
	_show_slide()


func _show_slide() -> void:
	if _slides.is_empty() or _title == null:
		return
	var slide := _slides[_index]
	_index_label.text = "%d / %d" % [_index + 1, _slides.size()]
	_title.text = slide.op
	_times.text = slide.times
	_shows.text = slide.shows
	_prev.disabled = _busy or _index <= 0
	_next.disabled = _busy or _index >= _slides.size() - 1

	var target_name := _selected_target()
	var flat := _latest(_paired_name("Flatbuffers", slide.op), target_name)
	var objects := _latest(_paired_name("BuiltIn", slide.op), target_name)
	var dictionary := _latest(_paired_name("GDict", slide.op), target_name)
	var base := NAN
	if flat != null and flat.error.is_empty():
		base = flat.time_ns
	_fill_result("FlatBuffers", flat, base)
	_fill_result("Objects", objects, base)
	_fill_result("Dictionary", dictionary, base)
	_source.text = _source_line(target_name, _newest(flat, objects, dictionary))
	_runs_hover = -1
	_targets_hover = -1
	if _runs_chart != null:
		_runs_chart.queue_redraw()
	if _targets_chart != null:
		_targets_chart.queue_redraw()


func _draw_runs_chart() -> void:
	if _runs_chart == null or _slides.is_empty():
		return
	var op := _slides[_index].op
	var target_name := _selected_target()
	_draw_bars(
			_runs_chart,
			"%s    %s" % [op, target_name],
			_history_groups(op, target_name),
			true,
			_runs_hits,
			_runs_hover)


func _draw_targets_chart() -> void:
	if _targets_chart == null or _slides.is_empty():
		return
	var op := _slides[_index].op
	_draw_bars(
			_targets_chart,
			op,
			_target_groups(op),
			false,
			_targets_hits,
			_targets_hover)


func _draw_bars(
		chart:Control,
		title:String,
		groups:Array[BarGroup],
		clock_only:bool,
		hits:Array[BarHit],
		hover:int) -> void:
	hits.clear()
	chart.draw_rect(Rect2(Vector2.ZERO, chart.size), _COLOR_PANEL)
	if chart.size.x < 80.0 or chart.size.y < 80.0:
		return

	var font := ThemeDB.fallback_font
	var title_size := 16
	var axis_size := 12
	var pad_left := 78.0
	var pad_right := 16.0
	var pad_top := 46.0
	var pad_bottom := 32.0
	var plot := Rect2(
			pad_left,
			pad_top,
			maxf(1.0, chart.size.x - pad_left - pad_right),
			maxf(1.0, chart.size.y - pad_top - pad_bottom))
	chart.draw_string(
			font, Vector2(plot.position.x, 20), title,
			HORIZONTAL_ALIGNMENT_LEFT, plot.size.x * 0.55, title_size, _COLOR_TEXT)
	_draw_legend(chart, font, axis_size, plot)

	if groups.is_empty():
		chart.draw_string(
				font, plot.position + Vector2(8, 24), "No samples",
				HORIZONTAL_ALIGNMENT_LEFT, plot.size.x, title_size, _COLOR_AXIS)
		return

	var top := 0.0
	for cluster in groups:
		for sample in cluster.rows:
			top = maxf(top, sample.time_ns)
	if top <= 0.0:
		top = 1.0
	top *= 1.12

	for tick in 4:
		var frac := float(tick) / 3.0
		var y := plot.position.y + plot.size.y * (1.0 - frac)
		chart.draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), _COLOR_GRID)
		chart.draw_string(
				font, Vector2(0, y + 4), _format_time(top * frac),
				HORIZONTAL_ALIGNMENT_RIGHT, pad_left - 8, axis_size, _COLOR_AXIS)

	var mark := -1
	if clock_only:
		mark = groups.size() - 1
	else:
		var selected := _selected_target()
		for g in groups.size():
			if groups[g].stamp == selected:
				mark = g
	var group_w := plot.size.x / float(groups.size())
	for g in groups.size():
		var group := groups[g]
		if g == mark:
			chart.draw_rect(
					Rect2(plot.position.x + group_w * float(g), plot.position.y, group_w, plot.size.y),
					_COLOR_MARK)
		var slot := group_w * 0.82
		var bar_w := maxf(2.0, slot / float(maxi(group.rows.size(), 1)) - 3.0)
		var origin_x := plot.position.x + group_w * float(g) + (group_w - slot) * 0.5
		for b in group.rows.size():
			var row := group.rows[b]
			var height := plot.size.y * (row.time_ns / top)
			var rect := Rect2(
					origin_x + float(b) * (bar_w + 3.0),
					plot.end.y - height,
					bar_w,
					height)
			var fill := _bar_color(row.benchmark)
			var hovered := hits.size() == hover
			if hovered:
				fill = fill.lightened(0.3)
			chart.draw_rect(rect, fill)
			var hit := BarHit.new()
			hit.rect = rect
			hit.row = row
			hits.append(hit)
			if hovered:
				var label := "%s  %s" % [_codec_of(row.benchmark), _format_time(row.time_ns)]
				var label_y := maxf(plot.position.y + 14.0, rect.position.y - 2.0)
				chart.draw_string(
						font, Vector2(rect.position.x, label_y), label,
						HORIZONTAL_ALIGNMENT_LEFT, 160.0, axis_size, _COLOR_TEXT)

		chart.draw_string(
				font,
				Vector2(origin_x, plot.end.y + 18),
				_axis_label(group.stamp, clock_only),
				HORIZONTAL_ALIGNMENT_LEFT,
				maxf(8.0, group_w - 4.0),
				axis_size,
				_COLOR_AXIS)


func _draw_legend(chart:Control, font:Font, font_size:int, plot:Rect2) -> void:
	var labels:PackedStringArray = ["FlatBuffers", "Objects", "Dictionary"]
	var colors:Array[Color] = [_COLOR_FLAT, _COLOR_GODOT, _COLOR_DICT]
	var x := plot.end.x
	for i in range(labels.size() - 1, -1, -1):
		var text_w := font.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		x -= text_w + 22.0
		chart.draw_rect(Rect2(x, 8, 12, 12), colors[i])
		chart.draw_string(
				font, Vector2(x + 16, 18), labels[i],
				HORIZONTAL_ALIGNMENT_LEFT, text_w + 4.0, font_size, _COLOR_TEXT)


func _on_runs_input(event:InputEvent) -> void:
	_hover(_runs_chart, event, _runs_hits, true)


func _on_targets_input(event:InputEvent) -> void:
	_hover(_targets_chart, event, _targets_hits, false)


func _on_runs_exit() -> void:
	if _runs_hover == -1:
		return
	_runs_hover = -1
	if _runs_chart != null:
		_runs_chart.queue_redraw()


func _on_targets_exit() -> void:
	if _targets_hover == -1:
		return
	_targets_hover = -1
	if _targets_chart != null:
		_targets_chart.queue_redraw()


func _hover(chart:Control, event:InputEvent, hits:Array[BarHit], runs:bool) -> void:
	if chart == null or not event is InputEventMouseMotion:
		return
	var point := chart.get_local_mouse_position()
	var found := -1
	for i in hits.size():
		if hits[i].rect.has_point(point):
			found = i
	if runs:
		if found == _runs_hover:
			return
		_runs_hover = found
	else:
		if found == _targets_hover:
			return
		_targets_hover = found
	chart.queue_redraw()


func _history_groups(op:String, target_name:String) -> Array[BarGroup]:
	var order:Array[BarGroup] = []
	for seen in _rows:
		if seen.target != target_name or not seen.error.is_empty() or is_nan(seen.time_ns):
			continue
		if not seen.benchmark.ends_with("_" + op):
			continue
		var found := _group_for(order, seen.unix_s)
		if found.stamp.is_empty():
			found.stamp = seen.timestamp_utc
	var filled:Array[BarGroup] = []
	for group in order:
		for codec:String in _CODECS:
			var bench_name := _paired_name(codec, op)
			for sample in _rows:
				if sample.unix_s != group.unix_s or sample.target != target_name or sample.benchmark != bench_name:
					continue
				if sample.error.is_empty() and not is_nan(sample.time_ns):
					group.rows.append(sample)
				break
		if not group.rows.is_empty():
			filled.append(group)
	return filled


func _target_groups(op:String) -> Array[BarGroup]:
	var order:Array[BarGroup] = []
	for target_name:String in _TARGETS:
		var group := BarGroup.new()
		group.stamp = target_name
		for codec:String in _CODECS:
			var sample := _latest(_paired_name(codec, op), target_name)
			if sample == null or not sample.error.is_empty() or is_nan(sample.time_ns):
				continue
			group.rows.append(sample)
		if not group.rows.is_empty():
			order.append(group)
	return order


func _group_for(order:Array[BarGroup], unix_s:int) -> BarGroup:
	for group in order:
		if group.unix_s == unix_s:
			return group
	var created := BarGroup.new()
	created.unix_s = unix_s
	order.append(created)
	return created


func _axis_label(stamp:String, clock_only:bool) -> String:
	if not clock_only or not stamp.contains("T"):
		return stamp
	var parts := stamp.split("T", true, 1)
	if parts.size() < 2:
		return stamp
	return parts[1]


func _bar_color(benchmark:String) -> Color:
	if benchmark.begins_with("BM_Flatbuffers_"):
		return _COLOR_FLAT
	if benchmark.begins_with("BM_BuiltIn_"):
		return _COLOR_GODOT
	if benchmark.begins_with("BM_GDict_"):
		return _COLOR_DICT
	return _COLOR_AXIS


func _codec_of(benchmark:String) -> String:
	if benchmark.begins_with("BM_Flatbuffers_"):
		return "FlatBuffers"
	if benchmark.begins_with("BM_BuiltIn_"):
		return "Objects"
	if benchmark.begins_with("BM_GDict_"):
		return "Dictionary"
	return benchmark


func _fill_result(codec_label:String, row:BenchResult, base:float) -> void:
	var time_label := _result_label(codec_label, "Time")
	var ratio_label := _result_label(codec_label, "Ratio")
	var detail_label := _result_label(codec_label, "Detail")
	if time_label == null or ratio_label == null or detail_label == null:
		return
	if row == null:
		time_label.text = "-"
		ratio_label.text = ""
		detail_label.text = "no saved row"
		return
	if not row.error.is_empty():
		time_label.text = "failed"
		ratio_label.text = ""
		detail_label.text = row.error
		return
	time_label.text = _format_time(row.time_ns)
	ratio_label.text = _format_ratio(row.time_ns, base)
	detail_label.text = "%s    %d iters" % [_format_bytes(row.bytes), row.iterations]


func _source_line(target_name:String, sample:BenchResult) -> String:
	var stamp := "no saved %s rows for this test" % target_name
	if sample != null and not sample.timestamp_utc.is_empty():
		stamp = "%s    %s UTC" % [target_name, sample.timestamp_utc]
	return "%s\nRe-run measures this process (%s) and appends those rows. Editor and template_debug are debug Godot binaries." % [
		stamp, _process_target(),
	]


func _result_label(codec_label:String, which:String) -> Label:
	var node := get_node_or_null("Margin/VBox/Scroll/Body/%s/%s" % [codec_label, which])
	if node is Label:
		return node
	return null


func _load_rows() -> void:
	_rows.clear()
	if not ResourceLoader.exists(HISTORY_PATH):
		return
	var loaded:Resource = ResourceLoader.load(
			HISTORY_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	var history := _as_history(loaded)
	if history == null:
		return
	for row in history.rows:
		var sample := _as_result(row)
		if sample != null and sample.suite == "scenario":
			_rows.append(sample)


func _latest(benchmark:String, target_name:String) -> BenchResult:
	var found:BenchResult = null
	for row in _rows:
		if row.benchmark == benchmark and row.target == target_name:
			found = row
	return found


func _selected_target() -> String:
	var idx := _target.selected
	if idx < 0 or idx >= _TARGETS.size():
		return _TARGETS[_TARGETS.size() - 1]
	return _TARGETS[idx]


func _select_target(target_name:String) -> void:
	for i in _TARGETS.size():
		if _TARGETS[i] == target_name:
			_target.select(i)
			return


func _set_running(running:bool, detail:String) -> void:
	_busy = running
	_back.disabled = running
	_rerun.disabled = running
	_target.disabled = running
	_prev.disabled = running or _index <= 0
	_next.disabled = running or _slides.is_empty() or _index >= _slides.size() - 1
	if running:
		Input.set_default_cursor_shape(Input.CURSOR_BUSY)
		_lamp.color = Color(0.95, 0.72, 0.2)
		_busy_text.add_theme_color_override("font_color", Color(0.98, 0.86, 0.45))
		_busy_text.text = detail
		return
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_lamp.color = Color(0.35, 0.35, 0.38)
	_busy_text.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58))
	_busy_bar.value = 0
	_busy_text.text = detail if not detail.is_empty() else "Idle"


func _process_target() -> String:
	if OS.has_feature("editor"):
		return "editor"
	if OS.is_debug_build():
		return "template_debug"
	return "template_release"


func _paired_name(codec:String, op:String) -> String:
	return "BM_%s_%s" % [codec, op]


func _codec_label(codec:String) -> String:
	match codec:
		"Flatbuffers":
			return "FlatBuffers"
		"BuiltIn":
			return "Objects"
		"GDict":
			return "Dictionary"
		_:
			return codec


func _format_time(value:float) -> String:
	if is_nan(value):
		return "-"
	if value >= 1.0e6:
		return "%.2f ms" % (value / 1.0e6)
	if value >= 1.0e3:
		return "%.1f us" % (value / 1.0e3)
	return "%.0f ns" % value


func _format_bytes(value:float) -> String:
	if is_nan(value):
		return "- B"
	return "%.0f B" % value


func _format_ratio(value:float, base:float) -> String:
	if is_nan(value) or is_nan(base) or base == 0.0:
		return ""
	return "%.2fx" % (value / base)


func _newest(a:BenchResult, b:BenchResult, c:BenchResult) -> BenchResult:
	var found := a
	if b != null and (found == null or b.unix_s >= found.unix_s):
		found = b
	if c != null and (found == null or c.unix_s >= found.unix_s):
		found = c
	return found


func _as_history(loaded:Resource) -> BenchHistory:
	if loaded is BenchHistory:
		return loaded
	return null


func _as_result(row:Resource) -> BenchResult:
	if row is BenchResult:
		return row
	return null


func _make_slides() -> Array[Slide]:
	var slides:Array[Slide] = []
	slides.append(_slide(
			"Store",
			"FlatBuffers builds the 64-record buffer inside the timer: the field formulas, a new builder, 64 copies of the name string, and finish. Dictionary times var_to_bytes of a dictionary built before the timer. Objects times var_to_bytes_with_objects of an object graph built before the timer.",
			"Dictionary and Objects measure encoding only. FlatBuffers includes construction. A lower Dictionary time is a smaller piece of work. The byte count is one buffer. The Objects buffer is larger because var_to_bytes_with_objects also writes the script class."))
	slides.append(_slide(
			"Load",
			"The buffer is built before the timer. Inside, each codec reads every field and checks the checksum. Dictionary decodes with bytes_to_var, and Objects with bytes_to_var_with_objects, then both walk the value again. FlatBuffers produces the values in that walk. FlatBuffers also constructs a reader for the root, each list entry, and the nested sibling and parent.",
			"Fair as touch-every-field. Dictionary and Objects include one extra walk past the moment the data exists. The checksum truncates ratio with int(), so a 32-bit versus 64-bit fraction on that field does not fail the check."))
	slides.append(_slide(
			"Spawn",
			"The buffer is built before the timer. FlatBuffers copies every field into a new dictionary, and constructs a reader per record. Dictionary returns bytes_to_var. Objects returns bytes_to_var_with_objects. An empty or null result fails the run. The timer does not repeat the checksum.",
			"FlatBuffers and Dictionary both end as a dictionary. Objects ends as a FooBarContainer. Pair FlatBuffers with Dictionary. The Objects column is a different destination."))
	slides.append(_slide(
			"Update",
			"The buffer and the destination exist before the timer. FlatBuffers writes fields into that dictionary and does not allocate a second copy of the payload. Dictionary and Objects decode a temporary, then copy onto the existing value. The timer does not repeat the checksum. FlatBuffers constructs a reader per record.",
			"FlatBuffers patches a dictionary, not Foo, Bar, or FooBar instances. Pair it with Dictionary. A no-op apply is rejected once at startup, before any timer starts. A later break that still returns a value would still record a time."))
	slides.append(_slide(
			"Peek",
			"The buffer is built before the timer. The timed work reads the rating of record 32 and compares it with a value computed beforehand. FlatBuffers builds a root and reads that field. Dictionary and Objects decode the whole buffer first. Dictionary also narrows the decoded Variant before converting the rating.",
			"FlatBuffers is a one-field read. The other two times are a full decode plus that read. The Variant narrowing is small beside bytes_to_var."))
	return slides


func _slide(op:String, times:String, shows:String) -> Slide:
	var slide := Slide.new()
	slide.op = op
	slide.times = times
	slide.shows = shows
	return slide
