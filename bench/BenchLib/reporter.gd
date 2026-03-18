@tool
@abstract
class_name BenchmarkReporter

const Statistics = BenchLib.Statistics
const StatisticUnit = BenchLib.StatisticUnit
const Skipped = BenchLib.Skipped
const TimeUnit = BenchLib.TimeUnit
const BigO = BenchLib.BigO
const Counter = BenchLib.Counter
const MemoryManager = BenchLib.MemoryManager
const CPUInfo = BenchLib.CPUInfo
const SystemInfo = BenchLib.SystemInfo

# Interface for custom benchmark result printers.
# By default, benchmark reports are printed to stdout. However an application
# can control the destination of the reports by calling
# RunSpecifiedBenchmarks and passing it a custom reporter object.
# The reporter object must implement the following interface.

func divi(a:int,b:int) -> int:
	@warning_ignore("integer_division")
	return a/b

class Context:
	static var cpu_info := CPUInfo.new()
	static var sys_info := SystemInfo.new()
	# The number of chars in the longest benchmark name.
	var name_field_width:int = 0
	static var executable_name:String = OS.get_executable_path()

	func _to_string() -> String:
		return "STUB Context._to_string"


class Run:
	const no_repetition_index:int = -1
	enum RunType { RT_Iteration, RT_Aggregate };

	func benchmark_name() -> String:
		return '_'.join([str(run_name), aggregate_name]) \
			if run_type == RunType.RT_Aggregate \
			else str(run_name)

	var run_name:BenchLib.BenchmarkName
	var family_index:int
	var per_family_instance_index:int
	var run_type:RunType = RunType.RT_Iteration
	var aggregate_name:String
	var aggregate_unit:StatisticUnit = StatisticUnit.kTime
	var report_label:String	# Empty if not set by benchmark.
	var skipped:Skipped = Skipped.NotSkipped
	var skip_message:String;

	var iterations:int = 1
	var threads:int = 1
	var repetition_index:int
	var repetitions:int
	var time_unit:TimeUnit = BenchLib.default_time_unit
	var real_accumulated_time:float = 0
	var cpu_accumulated_time:float = 0

	# Return a value representing the real time per iteration in the unit
	# specified by 'time_unit'.
	# NOTE: If 'iterations' is zero the returned value represents the
	# accumulated time.
	func GetAdjustedRealTime() -> float:
		var new_time:float = real_accumulated_time * BenchLib.GetTimeUnitMultiplier(time_unit);
		if iterations != 0:
			new_time /= iterations
		return new_time;


	# Return a value representing the cpu time per iteration in the unit
	# specified by 'time_unit'.
	# NOTE: If 'iterations' is zero the returned value represents the
	# accumulated time.
	func GetAdjustedCPUTime() -> float:
		var new_time:float = cpu_accumulated_time * BenchLib.GetTimeUnitMultiplier(time_unit);
		if iterations != 0:
			new_time /= iterations
		return new_time;


	# This is set to 0.0 if memory tracing is not enabled.
	var max_heapbytes_used:float = 0

	# By default Big-O is computed for CPU time, but that is not what you want
	# to happen when manual time was requested, which is stored as real time.
	var use_real_time_for_initial_big_o:bool = false

	# Keep track of arguments to compute asymptotic complexity
	var complexity:BigO = BigO.oNone
	var complexity_lambda:Callable
	var complexity_n:int = 0

	# what statistics to compute from the measurements
	var statistics:Array[Statistics]

	# Inform print function whether the current run is a complexity report
	var report_big_o:bool = false
	var report_rms:bool = false

	# UserCounters counters
	var counters:Dictionary[String,Counter]

	# Memory metrics.
	var memory_result: MemoryManager.Result
	var allocs_per_iter:float = 0.0


class PerFamilyRunReports:
	# How many runs will all instances of this benchmark perform?
	var num_runs_total:int = 0

	# How many runs have happened already?
	var num_runs_done:int = 0

	# The reports about (non-errneous!) runs of this family.
	var Runs:Array[Run]


# Construct a BenchmarkReporter with the output stream set to 'std::cout'
# and the error stream set to 'std::cerr'
func _init() -> void:pass

# Called once for every suite of benchmarks run.
# The parameter "context" contains information that the
# reporter may wish to use when generating its report, for example the
# platform under which the benchmarks are running. The benchmark run is
# never started if this function returns false, allowing the reporter
# to skip runs based on the context information.
@abstract
func ReportContext( context:Context ) -> bool

	# Called once for each group of benchmark runs, gives information about
# the configurations of the runs.
func ReportRunsConfig(
	_min_time:float, _has_explicit_iters:bool, _iters:int) -> void: pass

# Called once for each group of benchmark runs, gives information about
# cpu-time and heap memory usage during the benchmark run. If the group
# of runs contained more than two entries then 'report' contains additional
# elements representing the mean and standard deviation of those runs.
# Additionally if this group of runs was the last in a family of benchmarks
# 'reports' contains additional entries representing the asymptotic
# complexity and RMS of that benchmark family.
@abstract
func ReportRuns(report:Array[Run]) -> void

# Called once and only once after ever group of benchmarks is run and
# reported.
func Finalize() -> void: pass # Left blank on purpose. can be overridden in derived class.


# Print a human readable string representing the specified 'context'
func PrintBasicContext( context:Context ) -> void:
	# Date/time information is not available on QuRT.
	# Attempting to get it via this call cause the binary to crash.
	var lines:Array[String] = ['', Time.get_datetime_string_from_system()]

	if not Context.executable_name.is_empty():
		lines.append( "Running %s" % Context.executable_name )

	var info:CPUInfo = context.cpu_info
	lines.append( "Run on (%d X %f MHz CPU%s)" % [
		info.num_cpus,
		(info.cycles_per_second / 1000000.0),
		's' if info.num_cpus > 1 else ''])

	if not info.caches.is_empty():
		lines.append( "CPU Caches:")
		for CInfo in info.caches:
			var line:String = "\t\tL%d %s %d KiB" % [CInfo.level, CInfo.type, divi(CInfo.size , 1024)]
			if CInfo.num_sharing != 0:
				line += " (x%d)" % [divi(info.num_cpus , CInfo.num_sharing)]
			lines.append(line)

	if not info.load_avg.is_empty():
		var line:String = "Load Average: "
		line += ','.join(info.load_avg.map(func(la:float)->String:return "%.2f" % la ))
		lines.append(line)

	for key:String in BenchLib.global_context:
		var val:String = BenchLib.global_context[key]
		lines.append( ':'.join([key,val]) )

	if info.scaling == CPUInfo.Scaling.ENABLED:
		lines.append(' '.join(["***WARNING*** CPU scaling is enabled, the benchmark",
			"real time measurements may be noisy and will incur extra overhead."]))


	var sysinfo:SystemInfo = context.sys_info
	if sysinfo.ASLRStatus == SystemInfo.ASLR.ENABLED:
		lines.append(' '.join(["***WARNING*** ASLR is enabled, the results may",
		 "have unreproducible noise in them."]))

	if OS.is_debug_build():
		lines.append("***WARNING*** Library was built as DEBUG. Timings may be affected.")

	print('\n'.join(lines))
