@tool
extends Control

const HISTORY_PATH := "res://bench/results/history.tres"
const BENCH_SCENE := "res://bench/BenchScene.tscn"
const TARGET_ORDER:PackedStringArray = ["editor", "template_debug", "template_release"]

const _COLOR_EDITOR := Color(0.35, 0.65, 0.95)
const _COLOR_DEBUG := Color(0.95, 0.72, 0.28)
const _COLOR_RELEASE := Color(0.38, 0.82, 0.48)
const _COLOR_AXIS := Color(0.78, 0.78, 0.82)
const _COLOR_GRID := Color(1, 1, 1, 0.08)
const _COLOR_PANEL := Color(0.11, 0.11, 0.13)
const _COLOR_TEXT := Color(0.9, 0.9, 0.93)

@onready var _metric:OptionButton = $Margin/VBox/Toolbar/Metric
@onready var _status:Label = $Margin/VBox/Toolbar/Status
@onready var _tree:Tree = $Margin/VBox/Split/Benchmarks
@onready var _chart:Control = $Margin/VBox/Split/Right/Chart
@onready var _readout:Label = $Margin/VBox/Split/Right/Readout

var _rows:Array[BenchResult] = []
var _hit:Array[BarHit] = []
var _hover := -1


class BarHit:
	var rect:Rect2
	var row:BenchResult


class RunGroup:
	var unix_s:int
	var stamp:String
	var rows:Array[BenchResult] = []


class TargetRuns:
	var runs:Array[RunGroup] = []


func _ready() -> void:
	if _metric == null or _tree == null or _chart == null:
		return
	_metric.clear()
	_metric.add_item("Time")
	_metric.set_item_metadata(0, "time_ns")
	_metric.add_item("Throughput")
	_metric.set_item_metadata(1, "bytes_per_s")
	_metric.add_item("Size")
	_metric.set_item_metadata(2, "bytes")

	if not _metric.item_selected.is_connected(_on_metric_selected):
		if _metric.item_selected.connect(_on_metric_selected) != OK:
			push_error("metric signal failed")
	if not _tree.item_selected.is_connected(_on_benchmark_selected):
		if _tree.item_selected.connect(_on_benchmark_selected) != OK:
			push_error("tree signal failed")
	if not _chart.draw.is_connected(_draw_chart):
		if _chart.draw.connect(_draw_chart) != OK:
			push_error("chart draw failed")
	if not _chart.gui_input.is_connected(_on_chart_input):
		if _chart.gui_input.connect(_on_chart_input) != OK:
			push_error("chart input failed")
	if not _chart.resized.is_connected(_chart.queue_redraw):
		if _chart.resized.connect(_chart.queue_redraw) != OK:
			push_error("chart resize failed")

	var back := $Margin/VBox/Toolbar/Back as Button
	var reload := $Margin/VBox/Toolbar/Reload as Button
	if back != null and not back.pressed.is_connected(_on_back):
		if back.pressed.connect(_on_back) != OK:
			push_error("back signal failed")
	if reload != null and not reload.pressed.is_connected(_reload_history):
		if reload.pressed.connect(_reload_history) != OK:
			push_error("reload signal failed")

	_reload_history()


func _on_back() -> void:
	if Engine.is_editor_hint():
		return
	if get_tree().change_scene_to_file(BENCH_SCENE) != OK:
		push_error("failed to open %s" % BENCH_SCENE)


func _on_metric_selected(_index:int) -> void:
	_rebuild_tree()


func _on_benchmark_selected() -> void:
	_hover = -1
	_update_readout()
	if _chart != null:
		_chart.queue_redraw()


func _reload_history() -> void:
	_load_rows()
	_rebuild_tree()
	var runs := {}
	for row in _rows:
		runs[row.unix_s] = true
	if _rows.is_empty():
		_status.text = "No rows in %s" % HISTORY_PATH
	else:
		_status.text = "%d rows, %d runs" % [_rows.size(), runs.size()]


func _load_rows() -> void:
	_rows.clear()
	if not ResourceLoader.exists(HISTORY_PATH):
		return
	var loaded:Resource = ResourceLoader.load(
			HISTORY_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not loaded is BenchHistory:
		return
	var history := loaded as BenchHistory
	for row in history.rows:
		if row is BenchResult:
			_rows.append(row)


func _metric_id() -> String:
	if _metric == null:
		return "time_ns"
	var id:Variant = _metric.get_selected_metadata()
	if id is String:
		return id
	return "time_ns"


func _value_of(row:BenchResult) -> float:
	match _metric_id():
		"bytes_per_s":
			return row.bytes_per_s
		"bytes":
			return row.bytes
		_:
			return row.time_ns


func _format_value(value:float) -> String:
	if is_nan(value):
		return "-"
	match _metric_id():
		"bytes_per_s":
			return "%.2f MiB/s" % (value / (1024.0 * 1024.0))
		"bytes":
			return "%.0f B" % value
		_:
			if value >= 1.0e6:
				return "%.2f ms" % (value / 1.0e6)
			if value >= 1.0e3:
				return "%.1f us" % (value / 1.0e3)
			return "%.0f ns" % value


func _known_targets() -> Array[String]:
	var present:Dictionary[String, bool] = {}
	for row in _rows:
		present[row.target] = true
	var ordered:Array[String] = []
	for target in TARGET_ORDER:
		if present.erase(target):
			ordered.append(target)
	for target:String in present.keys():
		ordered.append(target)
	return ordered


func _benchmark_names() -> Array[String]:
	var seen:Dictionary[String, bool] = {}
	var names:Array[String] = []
	for row in _rows:
		if seen.has(row.benchmark):
			continue
		seen[row.benchmark] = true
		names.append(row.benchmark)
	return names


func _selected_benchmark() -> String:
	if _tree == null:
		return ""
	var item := _tree.get_selected()
	if item == null:
		return ""
	var meta:Variant = item.get_metadata(0)
	if meta is String:
		return meta
	return item.get_text(0)


func _latest(benchmark:String, target:String) -> BenchResult:
	var found:BenchResult = null
	for row in _rows:
		if row.benchmark != benchmark or row.target != target:
			continue
		if not row.error.is_empty() or is_nan(_value_of(row)):
			continue
		found = row
	return found


func _samples(benchmark:String) -> Array[BenchResult]:
	var found:Array[BenchResult] = []
	for row in _rows:
		if row.benchmark != benchmark or not row.error.is_empty():
			continue
		if is_nan(_value_of(row)):
			continue
		found.append(row)
	return found


func _rebuild_tree() -> void:
	if _tree == null:
		return
	var selected := _selected_benchmark()
	_tree.clear()
	var targets := _known_targets()
	_tree.columns = 1 + targets.size()
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "Benchmark")
	_tree.set_column_expand(0, true)
	_tree.set_column_clip_content(0, true)
	for i in targets.size():
		_tree.set_column_title(i + 1, targets[i])
		_tree.set_column_expand(i + 1, false)
		_tree.set_column_custom_minimum_width(i + 1, 120)

	var root := _tree.create_item()
	var select_item:TreeItem = null
	for benchmark in _benchmark_names():
		var item := _tree.create_item(root)
		item.set_text(0, benchmark)
		item.set_metadata(0, benchmark)
		for i in targets.size():
			var sample := _latest(benchmark, targets[i])
			var text := "-"
			if sample != null:
				text = _format_value(_value_of(sample))
			item.set_text(i + 1, text)
		if select_item == null or benchmark == selected:
			select_item = item
	if select_item != null:
		select_item.select(0)
	_hover = -1
	_update_readout()
	if _chart != null:
		_chart.queue_redraw()


func _update_readout() -> void:
	if _readout == null:
		return
	if _hover >= 0 and _hover < _hit.size():
		var row := _hit[_hover].row
		_readout.text = "%s\n%s    %s    %s    %d iters" % [
			row.benchmark,
			row.target,
			_format_value(_value_of(row)),
			row.timestamp_utc,
			row.iterations,
		]
		return

	var benchmark := _selected_benchmark()
	if benchmark.is_empty():
		_readout.text = ""
		return
	var lines:Array[String] = [benchmark]
	for target in _known_targets():
		var sample := _latest(benchmark, target)
		if sample == null:
			lines.append("%s    -" % target)
			continue
		lines.append("%s    %s    %s    %d iters" % [
			target,
			_format_value(_value_of(sample)),
			sample.timestamp_utc,
			sample.iterations,
		])
	_readout.text = "\n".join(PackedStringArray(lines))


func _color_for(target:String) -> Color:
	match target:
		"editor":
			return _COLOR_EDITOR
		"template_debug":
			return _COLOR_DEBUG
		"template_release":
			return _COLOR_RELEASE
		_:
			return Color(0.7, 0.7, 0.75)


func _on_chart_input(event:InputEvent) -> void:
	if not event is InputEventMouseMotion or _chart == null:
		return
	var point := _chart.get_local_mouse_position()
	var found := -1
	for i in _hit.size():
		if _hit[i].rect.has_point(point):
			found = i
			break
	if found == _hover:
		return
	_hover = found
	_update_readout()
	_chart.queue_redraw()


func _draw_chart() -> void:
	var chart := _chart
	_hit.clear()
	if chart == null:
		return
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
	var benchmark := _selected_benchmark()
	chart.draw_string(
			font, Vector2(plot.position.x, 20), benchmark,
			HORIZONTAL_ALIGNMENT_LEFT, plot.size.x * 0.55, title_size, _COLOR_TEXT)
	_draw_legend(chart, font, axis_size, plot)

	var samples := _samples(benchmark)
	if samples.is_empty():
		chart.draw_string(
				font, plot.position + Vector2(8, 24), "No samples",
				HORIZONTAL_ALIGNMENT_LEFT, plot.size.x, title_size, _COLOR_AXIS)
		return

	var order := _passes(samples)
	var top := 0.0
	for group in order:
		for row in group.rows:
			top = maxf(top, _value_of(row))
	if top <= 0.0:
		top = 1.0
	top *= 1.12

	for tick in 4:
		var frac := float(tick) / 3.0
		var y := plot.position.y + plot.size.y * (1.0 - frac)
		chart.draw_line(
				Vector2(plot.position.x, y), Vector2(plot.end.x, y), _COLOR_GRID)
		chart.draw_string(
				font, Vector2(0, y + 4), _format_value(top * frac),
				HORIZONTAL_ALIGNMENT_RIGHT, pad_left - 8, axis_size, _COLOR_AXIS)

	var group_w := plot.size.x / float(order.size())
	for g in order.size():
		var group := order[g]
		var slot := group_w * 0.82
		var bar_w := maxf(2.0, slot / float(group.rows.size()) - 3.0)
		var origin_x := plot.position.x + group_w * float(g) + (group_w - slot) * 0.5
		for b in group.rows.size():
			var row := group.rows[b]
			var value := _value_of(row)
			var height := plot.size.y * (value / top)
			var rect := Rect2(
					origin_x + float(b) * (bar_w + 3.0),
					plot.end.y - height,
					bar_w,
					height)
			var fill := _color_for(row.target)
			if _hit.size() == _hover:
				fill = fill.lightened(0.3)
			chart.draw_rect(rect, fill)
			var hit := BarHit.new()
			hit.rect = rect
			hit.row = row
			_hit.append(hit)

		var clock := group.stamp
		if clock.contains("T"):
			clock = clock.split("T", true, 1)[1]
		var label_w := minf(group_w - 4.0, 72.0)
		chart.draw_string(
				font,
				Vector2(origin_x, plot.end.y + 18),
				clock,
				HORIZONTAL_ALIGNMENT_LEFT,
				label_w,
				axis_size,
				_COLOR_AXIS)


func _runs_for(samples:Array[BenchResult], target:String) -> Array[RunGroup]:
	var order:Array[RunGroup] = []
	for row in samples:
		if row.target != target:
			continue
		var group := _group_for(order, row.unix_s)
		if group.stamp.is_empty():
			group.stamp = row.timestamp_utc
		group.rows.append(row)
	return order


## One cluster is the nth sample of each target. run.ps1 stamps each target
## separately, so a shared unix_s would put them in different groups.
func _passes(samples:Array[BenchResult]) -> Array[RunGroup]:
	var columns:Array[TargetRuns] = []
	var count := 0
	for target in _known_targets():
		var column := TargetRuns.new()
		column.runs = _runs_for(samples, target)
		count = maxi(count, column.runs.size())
		columns.append(column)

	var passes:Array[RunGroup] = []
	for i in count:
		var cluster := RunGroup.new()
		for column in columns:
			if i >= column.runs.size():
				continue
			var run := column.runs[i]
			if cluster.stamp.is_empty() or run.stamp < cluster.stamp:
				cluster.stamp = run.stamp
				cluster.unix_s = run.unix_s
			for row in run.rows:
				cluster.rows.append(row)
		passes.append(cluster)
	return passes


func _group_for(order:Array[RunGroup], unix_s:int) -> RunGroup:
	for group in order:
		if group.unix_s == unix_s:
			return group
	var created := RunGroup.new()
	created.unix_s = unix_s
	order.append(created)
	return created


func _draw_legend(chart:Control, font:Font, font_size:int, plot:Rect2) -> void:
	var targets := _known_targets()
	var x := plot.end.x
	for i in range(targets.size() - 1, -1, -1):
		var target := targets[i]
		var text_w := font.get_string_size(target, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		x -= text_w + 22.0
		chart.draw_rect(Rect2(x, 8, 12, 12), _color_for(target))
		chart.draw_string(
				font, Vector2(x + 16, 18), target,
				HORIZONTAL_ALIGNMENT_LEFT, text_w + 4.0, font_size, _COLOR_TEXT)
