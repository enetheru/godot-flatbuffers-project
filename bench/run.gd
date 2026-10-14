extends SceneTree

const RunnerSuite = preload("runner_suite.gd")
const RunnerPrealloc = preload("runner_prealloc.gd")
const RunnerArraySize = preload("runner_array_size.gd")
const RunnerScenario = preload("runner_scenario.gd")
const ConsoleReporter = preload("uid://cp6jwltd8s2ur")
const HistoryReporter = preload("history_reporter.gd")


## args[0] suite (default), all, prealloc, array-size, scenario.
## args[1] target name stored on each row. args[2] absolute history.tres path.
## An empty path keeps the console table only.
static func run_from_args(args:PackedStringArray) -> int:
	var which := "suite"
	if args.size() > 0:
		which = args[0]
	var target := ""
	if args.size() > 1:
		target = args[1]
	var history_path := ""
	if args.size() > 2:
		history_path = args[2]

	# _init registers the suite. Keep the instance until the run returns.
	var _runner:Object
	match which:
		"suite", "all":
			_runner = RunnerSuite.new()
		"prealloc":
			_runner = RunnerPrealloc.new()
		"array-size":
			_runner = RunnerArraySize.new()
		"scenario":
			_runner = RunnerScenario.new()
		_:
			printerr("unknown benchmark suite '%s'" % which)
			return 1

	var console := ConsoleReporter.new()
	var history:HistoryReporter = null
	if not history_path.is_empty():
		history = HistoryReporter.new(history_path, target, which)
		if not history.open_error.is_empty():
			printerr(history.open_error)
			return 1

	var count := BenchLib.RunSpecifiedBenchmarks(console, history)
	if history != null:
		history.close()
		if not history.open_error.is_empty():
			return 1
	if count == 0:
		printerr("zero benchmarks")
		return 1
	print("%d benchmarks" % count)
	return 0


func _initialize() -> void:
	quit(run_from_args(OS.get_cmdline_user_args()))
