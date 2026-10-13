@tool
extends BenchmarkReporter

const HistoryScript = preload("bench_history.gd")
const ResultScript = preload("bench_result.gd")

var open_error := ""

var _history:BenchHistory
var _path:String
var _target:String
var _suite:String
var _timestamp:String
var _unix_s:int


func _init(path:String, target_name:String, suite_name:String) -> void:
	super()
	_target = target_name
	_suite = suite_name
	_timestamp = Time.get_datetime_string_from_system(true)
	_unix_s = int(Time.get_unix_time_from_system())
	_path = path.replace("\\", "/")

	var dir := _path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		var err := DirAccess.make_dir_recursive_absolute(dir)
		if err != OK and not DirAccess.dir_exists_absolute(dir):
			open_error = "history dir failed (%s): %s" % [error_string(err), dir]
			return

	if FileAccess.file_exists(_path):
		var loaded:Resource = ResourceLoader.load(
				_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if loaded == null or loaded.get_script() != HistoryScript:
			open_error = "history load failed: %s" % _path
			return
		_history = loaded as BenchHistory
		if _history == null:
			open_error = "history script mismatch: %s" % _path
			return
	else:
		_history = HistoryScript.new()


func ReportContext(_context:Context) -> bool:
	return true


func ReportRuns(reports:Array[Run]) -> void:
	if _history == null:
		return

	for run in reports:
		if run.report_big_o or run.report_rms:
			continue
		if run.run_type == Run.RunType.RT_Aggregate and run.aggregate_unit != StatisticUnit.kTime:
			continue
		_history.rows.append(_row(run))

	_save()


func close() -> void:
	_save()


func _row(run:Run) -> BenchResult:
	var row:BenchResult = ResultScript.new()
	row.timestamp_utc = _timestamp
	row.unix_s = _unix_s
	row.target = _target
	row.suite = _suite
	row.benchmark = run.benchmark_name()
	if run.skipped != Skipped.NotSkipped:
		row.error = run.skip_message
		return row

	var mult := GetTimeUnitMultiplier(run.time_unit)
	row.time_ns = run.GetAdjustedRealTime() * (1e9 / mult)
	row.iterations = run.iterations
	row.bytes = _measurement(run, "bytes_size", true)
	row.bytes_per_s = _measurement(run, "bytes/s", false)
	return row


func _measurement(run:Run, key:String, per_iter:bool) -> float:
	if not run.counters.has(key):
		return NAN
	var cnt:Counter = run.counters[key]
	var value := cnt.value
	if per_iter and (cnt.flags & Counter.Flags.kIsIterationInvariant) != 0 and run.iterations != 0:
		value /= float(run.iterations)
	return value


func _save() -> void:
	if _history == null or _path.is_empty():
		return
	var err := ResourceSaver.save(_history, _path)
	if err != OK:
		open_error = "history save failed (%s): %s" % [error_string(err), _path]
		printerr(open_error)
