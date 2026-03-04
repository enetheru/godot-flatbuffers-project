@tool
class_name BenchLib

const RegisterLib = preload("uid://ehhn1k7v0g6w")
const BenchmarkFamilies = RegisterLib.BenchmarkFamilies

const StatsLib = preload("uid://c8w76q8bhpf8q")
const PerfCounters = preload("uid://b57mx2pbhhtfa")
const PerfCountersMeasurement = PerfCounters.PerfCountersMeasurement


# Default number of minimum benchmark running time in seconds.
static var kDefaultMinTimeStr:String = "0.5s"
static var kMaxIterations:int = 1

static var FLAGS_benchmark_list_tests:bool = false

#BM_DECLARE_bool(benchmark_dry_run);
static var FLAGS_benchmark_dry_run:bool = false
#BM_DECLARE_string(benchmark_min_time);
static var FLAGS_benchmark_min_time:String = kDefaultMinTimeStr
#BM_DECLARE_double(benchmark_min_warmup_time);
static var FLAGS_benchmark_min_warmup_time:float
#BM_DECLARE_int32(benchmark_repetitions);
static var FLAGS_benchmark_repetitions:int = 1
#BM_DECLARE_bool(benchmark_report_aggregates_only);
static var FLAGS_benchmark_report_aggregates_only:bool = false
#BM_DECLARE_bool(benchmark_display_aggregates_only);
static var FLAGS_benchmark_display_aggregates_only:bool = false
#BM_DECLARE_string(benchmark_perf_counters);
static var FLAGS_benchmark_perf_counters:String = ""

static var global_context:Dictionary = {}

enum AggregationReportMode {
	# The mode has not been manually specified
	ARM_Unspecified = 0,
	# The mode is user-specified.
	# This may or may not be set when the following bit-flags are set.
	ARM_Default = 1 << 0,
	# File reporter should only output aggregates.
	ARM_FileReportAggregatesOnly = 1 << 1,
	# Display reporter should only output aggregates
	ARM_DisplayReportAggregatesOnly = 1 << 2,
	# Both reporters should only display aggregates.
	ARM_ReportAggregatesOnly = ARM_FileReportAggregatesOnly | ARM_DisplayReportAggregatesOnly
}

enum Skipped {
	NotSkipped = 0,
	SkippedWithMessage,
	SkippedWithError
}

enum TimeUnit {
	kNanosecond,
	kMicrosecond,
	kMillisecond,
	kSecond
}

const default_time_unit:TimeUnit = TimeUnit.kNanosecond;

# BigO is passed to a benchmark in order to specify the asymptotic
# computational
# complexity for the benchmark. In case oAuto is selected, complexity will be
# calculated automatically to the best fit.
enum BigO { oNone, o1, oN, oNSquared, oNCubed, oLogN, oNLogN, oAuto, oLambda };

# BigOFunc is passed to a benchmark in order to specify the asymptotic
# computational complexity for the benchmark.
#typedef double(BigOFunc)(ComplexityN);
# NOTE: ComplexityN = int64_t

# This is the container for the user-defined counters.
# typedef std::map<std::string, Counter> UserCounters;
# NOTE: using Dictionary


enum StatisticUnit {
	kTime,
	kPercentage
}


# If a ProfilerManager is registered (via RegisterProfilerManager()), the
# benchmark will be run an additional time under the profiler to collect and
# report profile metrics for the run of the benchmark.
@abstract
class ProfilerManager:
		# This is called after `Setup()` code and right before the benchmark is run.
	@abstract
	func AfterSetupStart() -> void

		# This is called before `Teardown()` code and right after the benchmark
		# completes.
	@abstract
	func BeforeTeardownStop() -> void



class CPUInfo:
	class CacheInfo:
		var type:String = ""
		var level:int = 0
		var size:int = 0
		var num_sharing:int = 0

	enum Scaling { UNKNOWN, ENABLED, DISABLED }

	var num_cpus:int = OS.get_processor_count()
	var scaling:Scaling = Scaling.UNKNOWN
	var cycles_per_second:float = 0
	var caches:Array[CacheInfo] = []
	var load_avg:Array[float] = []


# Adding Struct for System Information
class SystemInfo:
	enum ASLR { UNKNOWN, ENABLED, DISABLED }

	var name:String = ""
	var ASLRStatus:ASLR = ASLR.UNKNOWN


# Base class for user-defined multi-threading
@abstract
class ThreadRunnerBase:
	@abstract
	func RunThreads(fn:Callable) -> void


# This class is used for user-defined counters.
class Counter:
	enum Flags {
		kDefaults = 0,
		# Mark the counter as a rate. It will be presented divided
		# by the duration of the benchmark.
		kIsRate = 1 << 0,
		# Mark the counter as a thread-average quantity. It will be
		# presented divided by the number of threads.
		kAvgThreads = 1 << 1,
		# Mark the counter as a thread-average rate. See above.
		kAvgThreadsRate = kIsRate | kAvgThreads,
		# Mark the counter as a constant value, valid/same for *every* iteration.
		# When reporting, it will be *multiplied* by the iteration count.
		kIsIterationInvariant = 1 << 2,
		# Mark the counter as a constant rate.
		# When reporting, it will be *multiplied* by the iteration count
		# and then divided by the duration of the benchmark.
		kIsIterationInvariantRate = kIsRate | kIsIterationInvariant,
		# Mark the counter as a iteration-average quantity.
		# It will be presented divided by the number of iterations.
		kAvgIterations = 1 << 3,
		# Mark the counter as a iteration-average rate. See above.
		kAvgIterationsRate = kIsRate | kAvgIterations,

		# In the end, invert the result. This is always done last!
		kInvert = 1 << 31
	}

	enum OneK {
		# 1'000 items per 1k
		kIs1000 = 1000,
		# 1'024 items per 1k
		kIs1024 = 1024
	}

	var value:float
	var flags:Flags
	var oneK:OneK = OneK.kIs1000


	func _init(v:float = 0., f:Flags = Flags.kDefaults, k:OneK = OneK.kIs1000) -> void:
		value = v
		flags = f
		oneK = k


class State:
	# struct StateIterator;
	# friend struct StateIterator;

	# Returns iterators used to run each iteration of a benchmark using a
	# C++11 ranged-based for loop. These functions should not be called directly.

	# REQUIRES: The benchmark has not started running yet. Neither begin nor end
	# have been called previously.

	# NOTE: KeepRunning may not be used after calling either of these functions.
	# inline BENCHMARK_ALWAYS_INLINE StateIterator begin();
	# inline BENCHMARK_ALWAYS_INLINE StateIterator end();
	
	# NOTE: I dont think I can directly represent the begin() and end()
	# functions to retrieve iterators in gdscript. I might be able to hack it
	# but I'd had it for every location, so we'll see. so far I dont remember
	# seeing a location where begin and end are used, so I'll look.
	# it looks like we're not supposed to use the iterators directly. So i wonder
	# if the start and end keep running
	# I would think that the c++ standard range loop would be implemented using
	# the begin and end functions, so I will have to incorporate it into the 
	# init and test.
	
	# NOTE: I can support the range based  for loop for gdscript.
	func _iter_get(iter:Variant) -> Variant:
		return iter

	func _iter_init(iter:Array) -> bool:
		iter[0] = 0 if skipped() else max_iterations
		StartKeepRunning()
		return true

	func _iter_next(iter:Array) -> bool:
		assert(iter[0] > 0) # This  might assert when we reach the end.
		iter[0] -= 1
		if iter[0] > 0: return true
		FinishKeepRunning()
		return false


	## Returns true if the benchmark should continue through another iteration.
	## NOTE: A benchmark may not return from the test until KeepRunning() has
	## returned false.
	func KeepRunning() -> bool:
		print("STUB: State.KeepRunning")
		return false

	## Returns true iff the benchmark should run n more iterations.
	## REQUIRES: 'n' > 0.
	## NOTE: A benchmark must not return from the test until KeepRunningBatch()
	## has returned false.
	## NOTE: KeepRunningBatch() may overshoot by up to 'n' iterations.
	##
	## Intended usage:
	##	 while (state.KeepRunningBatch(1000)) {
	##		 // process 1000 elements
	##	 }
	func KeepRunningBatch(_n:int) -> bool: #n:IterationCount
		print("STUB: State.IterationCount")
		return false

	## REQUIRES: timer is running and 'SkipWithMessage(...)' or
	##	 'SkipWithError(...)' has not been called by the current thread.
	## Stop the benchmark timer.	If not called, the timer will be
	## automatically stopped after the last iteration of the benchmark loop.
	##
	## For threaded benchmarks the PauseTiming() function only pauses the timing
	## for the current thread.
	##
	## NOTE: The "real time" measurement is per-thread. If different threads
	## report different measurements the largest one is reported.
	##
	## NOTE: PauseTiming()/ResumeTiming() are relatively
	## heavyweight, and so their use should generally be avoided
	## within each benchmark iteration, if possible.
	func PauseTiming() -> void:
		# Add in time accumulated so far
		assert(started_ and not finished_ and not skipped())
		timer_.StopTimer()
		if perf_counters_measurement_ != null:
			var measurements:Dictionary
			if not perf_counters_measurement_.Stop(measurements):
				assert(false, "Perf counters read the value failed.")
			
			for mname:String in measurements.keys():
				var mvalue:float = measurements[mname]
				# Counter was inserted with `kAvgIterations` flag by the constructor.
				assert(counters.has(mname))
				counters[name].value += mvalue


	## REQUIRES: timer is not running and 'SkipWithMessage(...)' or
	##	 'SkipWithError(...)' has not been called by the current thread.
	## Start the benchmark timer.	The timer is NOT running on entrance to the
	## benchmark function. It begins running after control flow enters the
	## benchmark loop.
	##
	## NOTE: PauseTiming()/ResumeTiming() are relatively
	## heavyweight, and so their use should generally be avoided
	## within each benchmark iteration, if possible.
	func ResumeTiming() -> void:
		assert(started_ and not finished_ and not skipped())
		timer_.StartTimer()
		if perf_counters_measurement_ != null:
			@warning_ignore("return_value_discarded")
			perf_counters_measurement_.Start()

	# REQUIRES: 'SkipWithMessage(...)' or 'SkipWithError(...)' has not been
	#						called previously by the current thread.
	# Report the benchmark as resulting in being skipped with the specified
	# 'msg'.
	# After this call the user may explicitly 'return' from the benchmark.
	#
	# If the ranged-for style of benchmark loop is used, the user must explicitly
	# break from the loop, otherwise all future iterations will be run.
	# If the 'KeepRunning()' loop is used the current thread will automatically
	# exit the loop at the end of the current iteration.
	#
	# For threaded benchmarks only the current thread stops executing and future
	# calls to `KeepRunning()` will block until all threads have completed
	# the `KeepRunning()` loop. If multiple threads report being skipped only the
	# first skip message is used.
	#
	# NOTE: Calling 'SkipWithMessage(...)' does not cause the benchmark to exit
	# the current scope immediately. If the function is called from within
	# the 'KeepRunning()' loop the current iteration will finish. It is the users
	# responsibility to exit the scope as needed.
	func SkipWithMessage(_msg:String) -> void:
		print("STUB: State.SkipWithMessage")

	# REQUIRES: 'SkipWithMessage(...)' or 'SkipWithError(...)' has not been
	#						called previously by the current thread.
	# Report the benchmark as resulting in an error with the specified 'msg'.
	# After this call the user may explicitly 'return' from the benchmark.
	#
	# If the ranged-for style of benchmark loop is used, the user must explicitly
	# break from the loop, otherwise all future iterations will be run.
	# If the 'KeepRunning()' loop is used the current thread will automatically
	# exit the loop at the end of the current iteration.
	#
	# For threaded benchmarks only the current thread stops executing and future
	# calls to `KeepRunning()` will block until all threads have completed
	# the `KeepRunning()` loop. If multiple threads report an error only the
	# first error message is used.
	#
	# NOTE: Calling 'SkipWithError(...)' does not cause the benchmark to exit
	# the current scope immediately. If the function is called from within
	# the 'KeepRunning()' loop the current iteration will finish. It is the users
	# responsibility to exit the scope as needed.
	func SkipWithError(msg:String) -> void:
		skipped_ = Skipped.SkippedWithError
		manager_.benchmark_mutex.lock()
		if Skipped.NotSkipped == manager_.results.skipped:
			manager_.results.skip_message = msg
			manager_.results.skipped = skipped_
		manager_.benchmark_mutex.unlock()
		
		total_iterations_ = 0
		if timer_.running(): timer_.StopTimer()


	# Returns true if 'SkipWithMessage(...)' or 'SkipWithError(...)' was called.
	func skipped() -> bool: return skipped_ != Skipped.NotSkipped

	# Returns true if an error has been reported with 'SkipWithError(...)'.
	func error_occurred() ->bool: return Skipped.SkippedWithError == skipped_

	# REQUIRES: called exactly once per iteration of the benchmarking loop.
	# Set the manually measured time for this benchmark iteration, which
	# is used instead of automatically measured time if UseManualTime() was
	# specified.
	#
	# For threaded benchmarks the final value will be set to the largest
	# reported values.
	func SetIterationTime(_seconds:float) -> void:
		print("STUB: State.SetIterationTime")

	# Set the number of bytes processed by the current benchmark
	# execution.	This routine is typically called once at the end of a
	# throughput oriented benchmark.
	#
	# REQUIRES: a benchmark has exited its benchmarking loop.
	func SetBytesProcessed(bytes:int) -> void:
		counters["bytes_per_second"] = \
			Counter.new(bytes, Counter.Flags.kIsRate, Counter.OneK.kIs1024)


	func bytes_processed() -> int:
		if counters.has("bytes_per_second"):
			return counters.get("bytes_per_second")
		return 0


	# If this routine is called with complexity_n > 0 and complexity report is
	# requested for the
	# family benchmark, then current benchmark will be part of the computation
	# and complexity_n will
	# represent the length of N.
	func SetComplexityN(complexity_n:int) -> void: #ComplexityN
		complexity_n_ = complexity_n


	func complexity_length_n() -> int: #ComplexityN
		return complexity_n_

	# If this routine is called with items > 0, then an items/s
	# label is printed on the benchmark report line for the currently
	# executing benchmark. It is typically called at the end of a processing
	# benchmark where a processing items/second output is desired.
	#
	# REQUIRES: a benchmark has exited its benchmarking loop.
	func SetItemsProcessed(items:int) -> void:
		counters["items_per_second"] = \
			Counter.new(items, Counter.Flags.kIsRate)


	func items_processed() -> int:
		if counters.has("items_per_second"):
			return counters.get("items_per_second")
		return 0;


	# If this routine is called, the specified label is printed at the
	# end of the benchmark report line for the currently executing
	# benchmark.	Example:
	#	static void BM_Compress(benchmark::State& state) {
	#		...
	#		double compress = input_size / output_size;
	#		state.SetLabel(StrFormat("compress:%.1f%%", 100.0*compression));
	#	}
	# Produces output that looks like:
	#	BM_Compress	 50				 50	 14115038	compress:27.3%
	#
	# REQUIRES: a benchmark has exited its benchmarking loop.
	func SetLabel(_label:String) -> void:
		print("STUB: State.SetLabel")

	# Range arguments for this run. CHECKs if the argument has been set.
	func GetRange(pos:int = 0) -> int:
		assert(range_.size() > pos)
		return range_[pos]


	#BENCHMARK_DEPRECATED_MSG("use 'range(0)' instead")
	#int64_t range_x() const { return range(0); }
#
	#BENCHMARK_DEPRECATED_MSG("use 'range(1)' instead")
	#int64_t range_y() const { return range(1); }

	# Number of threads concurrently executing the benchmark.
	func threads() -> int: return threads_

	# Index of the executing thread. Values from [0, threads).
	func thread_index() -> int: return thread_index_

	func iterations() -> int:
		if not started_: return 0
		return max_iterations - total_iterations_ + batch_leftover_

	func name() -> String: return name_

	func range_size() -> int: return range_.size()


	# items we expect on the first cache line (ie 64 bytes of the struct)
	# When total_iterations_ is 0, KeepRunning() and friends will return false.
	# May be larger than max_iterations.
	var total_iterations_:int = 0

	# When using KeepRunningBatch(), batch_leftover_ holds the number of
	# iterations beyond max_iters that were run. Used to track
	# completed_iterations_ accurately.
	var batch_leftover_:int = 0

	var max_iterations:int

	var started_:bool = false
	var finished_:bool = false
	var skipped_:Skipped = Skipped.NotSkipped

	# items we don't need on the first cache line
	var range_:Array[int]

	var complexity_n_:int = 0 #ComplexityN

	# Container for user-defined counters.
	var counters:Dictionary #UserCounters

	func _init(
				new_name:String,
				max_iters:int, #IterationCount
				ranges:Array[int],
				thread_i:int,
				n_threads:int,
				timer:ThreadTimer,
				manager:ThreadManager,
				perf_counters_measurement:PerfCountersMeasurement,
				profiler_manager:ProfilerManager) -> void:
		max_iterations             = max_iters
		range_                     = ranges
		name_                      = new_name
		thread_index_              = thread_i
		threads_                   = n_threads
		timer_                     = timer
		manager_                   = manager
		perf_counters_measurement_ = perf_counters_measurement
		profiler_manager_          = profiler_manager

		assert(max_iterations != 0, "At least one iteration must be run")
		assert(thread_index_ < threads_, "thread_index must be less than threads")

		# Add counters with correct flag now.	If added with `counters[name]` in
		# `PauseTiming`, a new `Counter` will be inserted the first time, which
		# won't have the flag.	Inserting them now also reduces the allocations
		# during the benchmark.
		if perf_counters_measurement_ != null:
			for counter_name:String in perf_counters_measurement_.names():
				counters[counter_name] = Counter.new(0.0, Counter.Flags.kAvgIterations);


		# Note: The use of offsetof below is technically undefined until C++17
		# because State is not a standard layout type. However, all compilers
		# currently provide well-defined behavior as an extension (which is
		# demonstrated since constexpr evaluation must diagnose all undefined
		# behavior). However, GCC and Clang also warn about this use of offsetof,
		# which must be suppressed.
		# NOTE: I remoted a lot of preprocessor directives here.
		# Offset tests to ensure commonly accessed data is on the first cache line.
		#var cache_line_size:int = 64
		#assert(offsetof(State, skipped_) <= (cache_line_size - sizeof(skipped_)), "")

	func StartKeepRunning() ->void:
		assert(not started_ and not finished_)
		started_ = true;
		total_iterations_ = 0 if skipped() else max_iterations
		if profiler_manager_ != null:
			profiler_manager_.AfterSetupStart()
		@warning_ignore("return_value_discarded")
		manager_.StartStopBarrier()
		if not skipped(): ResumeTiming()


	# Implementation of KeepRunning() and KeepRunningBatch().
	# is_batch must be true unless n is 1.
	func KeepRunningInternal(_n:int, _is_batch:bool) -> bool: #n:IterationCount
		print("STUB State.KeepRunningInternal")
		return false

	func FinishKeepRunning() -> void:
		assert(started_ and (not finished_ or skipped()))
		if not skipped(): PauseTiming()
		# Total iterations has now wrapped around past 0. Fix this.
		total_iterations_ = 0
		finished_ = true
		@warning_ignore("return_value_discarded")
		manager_.StartStopBarrier()
		if profiler_manager_ != null:
			profiler_manager_.BeforeTeardownStop()

	var name_:String
	var thread_index_:int
	var threads_:int

	var timer_:ThreadTimer
	var manager_:ThreadManager
	var perf_counters_measurement_:PerfCountersMeasurement
	var profiler_manager_:ProfilerManager


@abstract
class Benchmark:
	func _init( name:String ) -> void:
		_name = name
		@warning_ignore_start("return_value_discarded")
		ComputeStatistics("mean", StatsLib.StatisticsMean)
		ComputeStatistics("median", StatsLib.StatisticsMedian)
		ComputeStatistics("stddev", StatsLib.StatisticsStdDev)
		ComputeStatistics("cv", StatsLib.StatisticsCV, StatisticUnit.kPercentage)
		@warning_ignore_restore("return_value_discarded")


	@warning_ignore_start("unused_private_class_variable")
	var _name:String
	var _aggregation_report_mode:AggregationReportMode = \
			AggregationReportMode.ARM_Unspecified
	var _arg_names:PackedStringArray	# Args for all benchmark runs
	var _args:Array[PackedInt64Array] # Args for all benchmark runs

	var _time_unit:TimeUnit = default_time_unit

	var _use_default_time_unit:bool = true

	var _range_multiplier:int = RegisterLib.kRangeMultiplier
	var _min_time:float = 0
	var _min_warmup_time:float = 0
	var _iterations:int = 0
	var _repetitions:int = 0
	var _measure_process_cpu_time:bool = false
	var _use_real_time:bool = false
	var _use_manual_time:bool = false
	var _complexity:BigO = BigO.oNone
	var _complexity_lambda:Callable #BigOFunc
	var _statistics:Array[Statistics] = []
	var _thread_counts:Array[int] = []

	var _setup:Callable
	var _teardown:Callable

	var threadrunner:Callable = Callable() #threadrunner_factory
	@warning_ignore_restore("unused_private_class_variable")


	@abstract
	func Run( state:State ) -> void

	func ArgsCnt() -> int:
		if _args.is_empty():
			if _arg_names.is_empty():
				return -1
			return _arg_names.size()
		var front:PackedInt64Array = _args.front()
		return front.size()


	func ComputeStatistics(
				name:String, statistics:Callable, #StatisticsFunc
				unit:StatisticUnit = StatisticUnit.kTime ) -> Benchmark:
		_statistics.push_back(Statistics.new(name, statistics, unit))
		return self


class FunctionBenchmark extends Benchmark:
	var _func:Callable

	func _init( new_name:String, new_func:Callable ) -> void:
		_name = new_name
		_func = new_func

	func Run( state:State ) -> void:
		_func.call(state)


class BenchmarkName:
	# Return the full name of the benchmark with each non-empty
	# field separated by a '/'
	func _to_string() -> String:
		return '/'.join([function_name, args, min_time, min_warmup_time,
			iterations, repetitions, time_type, threads].filter(
				func(p:String)->bool: return not p.is_empty()))

	var function_name:String
	var args:String
	var min_time:String
	var min_warmup_time:String
	var iterations:String
	var repetitions:String
	var time_type:String
	var threads:String


## Information kept per benchmark we may want to run
class BenchmarkInstance:

	func _init( benchmark:Benchmark, family_idx:int, per_family_instance_idx:int,
				args:PackedInt64Array, thread_count:int) -> void:

		_benchmark = benchmark
		_family_index = family_idx
		_per_family_instance_index = per_family_instance_idx
		_aggregation_report_mode = _benchmark._aggregation_report_mode
		_args = args
		_time_unit = _benchmark._time_unit
		_measure_process_cpu_time = _benchmark._measure_process_cpu_time
		_use_real_time = _benchmark._use_real_time
		_use_manual_time = _benchmark._use_manual_time
		_complexity = _benchmark._complexity
		_complexity_lambda = _benchmark._complexity_lambda
		_statistics = _benchmark._statistics
		_repetitions = _benchmark._repetitions
		_min_time = _benchmark._min_time
		_min_warmup_time = _benchmark._min_warmup_time
		_iterations = _benchmark._iterations
		_threads = thread_count
		_setup = _benchmark._setup
		_teardown = _benchmark._teardown

		name.function_name = _benchmark._name

		var arg_i:int = 0;
		for arg	in args:
			if not name.args.is_empty():
				name.args += '/'

			if arg_i < benchmark._arg_names.size():
				var arg_name:String = _benchmark._arg_names[arg_i]
				if not arg_name.is_empty():
					name.args += "%s:" % arg_name

			#_name.args += StrFormat("%" PRId64, arg);
			name.args += "%" % arg
			arg_i += 1

		if not is_zero_approx(benchmark._min_time):
			name.min_time = "min_time:%0.3f" % _benchmark._min_time

		if not is_zero_approx(benchmark._min_warmup_time):
			name.min_warmup_time = \
				"min_warmup_time:%0.3f" % _benchmark._min_warmup_time

		if _benchmark._iterations != 0:
			name.iterations = "iterations:%lu" % _benchmark._iterations

		if _benchmark._repetitions != 0:
			name.repetitions = "repeats:%d" % _benchmark._repetitions

		if _benchmark._measure_process_cpu_time:
			name.time_type = "process_time"

		if _benchmark._use_manual_time:
			if not name.time_type.is_empty():
				name.time_type += '/'
			name.time_type += "manual_time"
		elif _benchmark._use_real_time:
			if not name.time_type.is_empty():
				name.time_type += '/'
			name.time_type += "real_time"

		if not _benchmark._thread_counts.is_empty():
			name.threads = "threads:%d" % _threads


	func Setup() -> void:
		if _setup != null and _setup.is_valid():
			var st := State.new( name.function_name, 1, _args, 0, _threads, 
					null, null, null, null)
			_setup.call(st)


	func Teardown() -> void:
		if _teardown != null and _teardown.is_valid():
			var st := State.new( name.function_name,  1, _args,  0, _threads, 
					null, null, null, null)
			_teardown.call(st)
	
		
	func GetUserThreadRunnerFactory() -> Callable:
		return _benchmark.threadrunner


	func Run(	iters:int, #IterationCount
				thread_id:int,
				timer:ThreadTimer,
				manager:ThreadManager,
				perf_counters_measurement:PerfCountersMeasurement,
				profiler_manager:ProfilerManager) -> State:

		var st := State.new(
			name.function_name, iters, _args, thread_id, _threads, timer,
			manager, perf_counters_measurement, profiler_manager)
		_benchmark.Run(st)
		return st;


	var name := BenchmarkName.new()
	var _benchmark:Benchmark
	var _family_index:int
	var _per_family_instance_index:int
	@warning_ignore("unused_private_class_variable")
	var _aggregation_report_mode:int # from enum AggregationReportMode
	var _args:PackedInt64Array
	var _time_unit:TimeUnit
	var _measure_process_cpu_time:bool
	var _use_real_time:bool
	var _use_manual_time:bool
	var _complexity:BigO
	var _complexity_lambda:Callable
	#var _counters:Dictionary
	var _statistics:Array[Statistics]
	var _repetitions:int
	var _min_time:float
	var _min_warmup_time:float
	var _iterations:int
	var _threads:int	# Number of concurrent threads to us

	var _setup:Callable
	var _teardown:Callable

class Statistics:
	var _name:String
	var _compute:Callable
	var _unit:StatisticUnit

	func _init(name:String, compute:Callable,
				unit:StatisticUnit = StatisticUnit.kTime) -> void:
		_name = name; _compute = compute; _unit = unit


class RunResults:
	var non_aggregates:Array[BenchmarkReporter.Run]
	var aggregates_only:Array[BenchmarkReporter.Run]
	var display_report_aggregates_only:bool = false
	var file_report_aggregates_only:bool = false

# If a MemoryManager is registered (via RegisterMemoryManager()),
# it can be used to collect and report allocation metrics for a run of the
# benchmark.
@abstract
class MemoryManager:
	const TombstoneValue:int = 0x7FFFFFFFFFFFFFFF

	class Result:

		# The number of allocations made in total between Start and Stop.
		var num_allocs:int = 0

		# The peak memory use between Start and Stop.
		var max_bytes_used:int = 0

		# The total memory allocated, in bytes, between Start and Stop.
		# Init'ed to TombstoneValue if metric not available.
		var total_allocated_bytes:int = TombstoneValue

		# The net changes in memory, in bytes, between Start and Stop.
		# ie., total_allocated_bytes - total_deallocated_bytes.
		# Init'ed to TombstoneValue if metric not available.
		var net_heap_growth:int = TombstoneValue

		var memory_iterations:int = 0


	#STUB virtual ~MemoryManager() {}

	# Implement this to start recording allocation information.
	@abstract
	func Start() -> void

	# Implement this to stop recording and fill out the given Result structure.
	@abstract
	func Stop(result:Result) -> void


static func RunSpecifiedBenchmarks(
			display_reporter:BenchmarkReporter,
			file_reporter:BenchmarkReporter = null,
			spec:String = '.' ) -> int:
	if spec.is_empty() or spec == 'all':
		spec = '.' # Regexp that matches all benchmarks

	var benchmarks:Array[BenchmarkInstance]
	if not BenchmarkFamilies.GetInstance().FindBenchmarks(spec, benchmarks):
		return 0;

	if benchmarks.is_empty():
		push_error("Failed to match any benchmarks against regex: ", spec)
		return 0

	if FLAGS_benchmark_list_tests:
		for benchmark in benchmarks:
			print( str(benchmark.name) )
	else:
		RunBenchmarks(benchmarks, display_reporter, file_reporter)

	return benchmarks.size();


static func ComputeBigO(reports:Array[BenchmarkReporter.Run]) -> Array[BenchmarkReporter.Run]:
	print("STUB: ComputeBigO()")
	return reports


static func RunBenchmarks(
			benchmarks:Array[BenchmarkInstance],
			display_reporter:BenchmarkReporter,
			file_reporter:BenchmarkReporter) -> void:

	# Note the file_reporter can be null.
	assert( display_reporter != null )

	# Determine the width of the name field using a minimum width of 10.
	var might_have_aggregates:bool = FLAGS_benchmark_repetitions > 1
	var name_field_width:int = 10
	var stat_field_width:int = 0
	for benchmark:BenchmarkInstance in benchmarks:
		name_field_width = maxi(name_field_width, str(benchmark.name).length())
		might_have_aggregates = might_have_aggregates or (benchmark._repetitions > 1);

		for Stat:Statistics in benchmark._statistics:
			stat_field_width = maxi(stat_field_width, Stat._name.length())

	if might_have_aggregates:
		name_field_width += 1 + stat_field_width;

	# Print header here
	var context := BenchmarkReporter.Context.new()
	context.name_field_width = name_field_width

	# Keep track of running times of all instances of each benchmark family.
	var per_family_reports:Dictionary[int, BenchmarkReporter.PerFamilyRunReports]

	if display_reporter.ReportContext(context) \
	and (file_reporter == null \
	or file_reporter.ReportContext(context)):
		var num_repetitions_total:int = 0

		# This perfcounters object needs to be created before the runners vector
		# below so it outlasts their lifetime.
		var perfcounters := PerfCountersMeasurement.new(
				FLAGS_benchmark_perf_counters.split(',') )

		# Vector of benchmarks to run
		var runners:Array[BenchmarkRunner]
		if runners.resize(benchmarks.size()) != OK:
			push_error("Faield to resize runners")
			return
		var runner_idx:int = 0

		# Count the number of benchmarks with threads to warn the user in case
		# performance counters are used.
		var benchmarks_with_threads:int = 0

		# Loop through all benchmarks
		for benchmark:BenchmarkInstance in benchmarks:
			var reports_for_family:BenchmarkReporter.PerFamilyRunReports = null
			if benchmark._complexity != BigO.oNone:
				reports_for_family = per_family_reports[benchmark._family_index]

			benchmarks_with_threads += (1 if benchmark._threads > 1 else 0)
			var runner := BenchmarkRunner.new(benchmark, perfcounters, reports_for_family)
			runners[runner_idx] = runner
			runner_idx += 1

			var num_repeats_of_this_instance:int = runner.repeats
			num_repetitions_total += num_repeats_of_this_instance
			if reports_for_family != null:
				reports_for_family.num_runs_total += num_repeats_of_this_instance

		assert(runners.size() == benchmarks.size(), "Unexpected runner count.")

		# The use of performance counters with threads would be unintuitive for
		# the average user so we need to warn them about this case
		if benchmarks_with_threads > 0 \
		and perfcounters.num_counters() > 0:
			print(("***WARNING*** There are %d benchmarks with threads and %d " +
				"performance counters were requested. Beware counters will " +
				"reflect the combined usage across all threads.") % [
					benchmarks_with_threads, perfcounters.num_counters()])

		var repetition_indices:Array[int]
		var rep_idx:int = 0
		if repetition_indices.resize(num_repetitions_total) != OK:
			push_error("Failure to resize repetition_indices")
			return

		for runner_index:int in runners.size():
			var runner:BenchmarkRunner = runners[runner_index]
			for i in runner.repeats:
				repetition_indices[rep_idx] = runner_index
				rep_idx += 1

		assert(repetition_indices.size() == num_repetitions_total,
			("%d != %d\n" %	[repetition_indices.size(), num_repetitions_total]) +
			"Unexpected number of repetition indexes.")

		#STUB if (FLAGS_benchmark_enable_random_interleaving) {
		#STUB 	std::random_device rd;
		#STUB 	std::mt19937 g(rd());
		#STUB 	std::shuffle(repetition_indices.begin(), repetition_indices.end(), g);
		#STUB }

		for repetition_index:int in repetition_indices:
			var runner:BenchmarkRunner = runners[repetition_index]
			runner.DoOneRepetition()
			if runner.HasRepeatsRemaining(): continue

			# FIXME: report each repetition separately, not all of them in bulk.
			display_reporter.ReportRunsConfig(
					runner.min_time, 
					runner.has_explicit_iteration_count, 
					runner.iters)
					
			if file_reporter != null:
				file_reporter.ReportRunsConfig(
					runner.min_time, 
					runner.has_explicit_iteration_count, 
					runner.iters)

			var run_results:RunResults = runner.GetResults()

			# Maybe calculate complexity report
			var reports_for_family := runner.reports_for_family
			if reports_for_family:
				if reports_for_family.num_runs_done == reports_for_family.num_runs_total:
					var additional_run_stats:Array = ComputeBigO(reports_for_family.Runs)
					run_results.aggregates_only.append_array(additional_run_stats)
					if not per_family_reports.erase( reports_for_family.Runs.front().family_index):
						push_warning("item not found in per_family_reports")

			Report(display_reporter, file_reporter, run_results);

	display_reporter.Finalize()
	#STUB if file_reporter != nullptr:
	#STUB 	file_reporter.Finalize();


static func ReportOne(
				reporter:BenchmarkReporter,
				aggregates_only:bool,
				results:RunResults) -> void:
		assert(reporter);
		# If there are no aggregates, do output non-aggregates.
		aggregates_only = aggregates_only and not results.aggregates_only.is_empty()
		if not aggregates_only:
			reporter.ReportRuns(results.non_aggregates)

		if not results.aggregates_only.is_empty():
			reporter.ReportRuns(results.aggregates_only)


# Reports in both display and file reporters.
static func Report(display_reporter:BenchmarkReporter,
			file_reporter:BenchmarkReporter,
			run_results:RunResults ) -> void:

	ReportOne(
		display_reporter,
		run_results.display_report_aggregates_only,
		run_results);

	if file_reporter != null:
		ReportOne(
			file_reporter,
			run_results.file_report_aggregates_only,
			run_results);


#STUB # Disable deprecated warnings temporarily because we need to reference
#STUB # CSVReporter but don't want to trigger -Werror=-Wdeprecated-declarations
#STUB BENCHMARK_DISABLE_DEPRECATED_WARNING
#STUB
#STUB std::unique_ptr<BenchmarkReporter> CreateReporter(
#STUB		std::string const& name, ConsoleReporter::OutputOptions output_opts) {
#STUB	typedef std::unique_ptr<BenchmarkReporter> PtrType;
#STUB	if (name == "console") {
#STUB		return PtrType(new ConsoleReporter(output_opts));
#STUB	}
#STUB	if (name == "json") {
#STUB		return PtrType(new JSONReporter());
#STUB	}
#STUB	if (name == "csv") {
#STUB		return PtrType(new CSVReporter());
#STUB	}
#STUB	std::cerr << "Unexpected format: '" << name << "'\n";
#STUB	std::flush(std::cerr);
#STUB	std::exit(1);

static func GetTimeUnitString(unit:TimeUnit) -> String:
	match unit:
		TimeUnit.kSecond: return "s"
		TimeUnit.kMillisecond: return "ms"
		TimeUnit.kMicrosecond: return "us"
		TimeUnit.kNanosecond: return "ns"
	return ''


static func GetTimeUnitMultiplier(unit:TimeUnit) -> float:
	match unit:
		TimeUnit.kSecond: return 1;
		TimeUnit.kMillisecond: return 1e3;
		TimeUnit.kMicrosecond: return 1e6;
		TimeUnit.kNanosecond: return 1e9;
	return 1
