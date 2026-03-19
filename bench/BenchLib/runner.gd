@tool
class_name BenchmarkRunner
# BenchTimeType { UNSPECIFIED, ITERS, TIME }
# This was a tagged union, but I'll let the return type as float or int do the
# talking

const RunResults = BenchLib.RunResults
const ProfileManager = BenchLib.ProfilerManager

const Instlib = preload("uid://dl8f6nc1cjmw6")
const BenchmarkInstance = Instlib.BenchmarkInstance

const Statelib = preload("uid://wwktui5nflyr")
const State = Statelib.State

const Statslib = preload("uid://c8w76q8bhpf8q")
const AggregationReportMode = StatsLib.AggregationReportMode

const PerfCounters = preload("uid://b57mx2pbhhtfa")
const PerfCountersMeasurement = PerfCounters.PerfCountersMeasurement

const CounterLib = preload("uid://ct2wyy7dxrm5")

const StatsLib = preload("uid://c8w76q8bhpf8q")

const Threadlib = preload("uid://hgmj8mo7h7dy")
const ThreadManager = Threadlib.ThreadManager

var kMaxIterations:int = 1000000

static var kDefaultMinTime:float = BenchLib.kDefaultMinTimeStr.to_float()

class IterationResults:
	var results:ThreadManager.Result
	var iters:int
	var seconds:float


func CreateRunReport(
			b_instance:BenchmarkInstance,
			results:ThreadManager.Result,
			memory_iterations:int, #STUB memory_iterations:IterationCount,
			memory_result:Variant, #STUB memory_result:MemoryManager.Result,
			seconds:float,
			repetition_index:int,
			num_repeats:int ) -> BenchmarkReporter.Run:
	# Create report about this benchmark run.
	var report := BenchmarkReporter.Run.new()

	report.run_name = b_instance.name
	report.family_index = b_instance._family_index
	report.per_family_instance_index = b_instance._per_family_instance_index
	report.skipped = results.skipped
	report.skip_message = results.skip_message
	report.report_label = results.report_label
	# This is the total iterations across all threads.
	report.iterations = results.iterations;
	report.time_unit = b_instance._time_unit
	report.threads = b_instance._threads
	report.repetition_index = repetition_index
	report.repetitions = num_repeats

	if report.skipped == 0:
		if b_instance._use_manual_time:
			report.real_accumulated_time = results.manual_time_used;
		else:
			report.real_accumulated_time = results.real_time_used;

		report.use_real_time_for_initial_big_o = b_instance._use_manual_time
		report.cpu_accumulated_time = results.cpu_time_used;
		report.complexity_n = results.complexity_n;
		report.complexity = b_instance._complexity
		report.complexity_lambda = b_instance._complexity_lambda
		report.statistics = b_instance._statistics
		report.counters = results.counters;

		if memory_iterations > 0:
			report.memory_result = memory_result
			if memory_iterations != 0:
				report.allocs_per_iter = \
					memory_result.num_allocs / memory_iterations
			else:
				report.allocs_per_iter = 0

		## The CPU time is the total time taken by all thread. If we used that as
		## the denominator, we'd be calculating the rate per thread here. This is
		## why we have to divide the total cpu_time by the number of threads for
		## global counters to get a global rate.
		var thread_seconds:float = seconds / b_instance._threads
		CounterLib.FinishUserCounters(report.counters, results.iterations, thread_seconds, b_instance._threads)

	return report;


## Execute one thread of benchmark b for the specified number of iterations.
## Adds the stats collected for the thread into manager->results.
static func RunInThread(
			b_instance:BenchmarkInstance,
			r_iters:int, #IterationCount
			thread_id:int,
			manager:ThreadManager,
			perf_counters_measurement:PerfCountersMeasurement,
			profiler_manager_:ProfileManager) -> void:
	var timer := ThreadTimer.CreateProcessCpuTime() \
		if b_instance._measure_process_cpu_time \
		else ThreadTimer.Create()

	var st:State = b_instance.Run(r_iters, thread_id, timer, manager, perf_counters_measurement, profiler_manager_)
	if not (st.skipped() or st.iterations() >= st.max_iterations):
		print("st.max_iterations: ", st.max_iterations)
		print("st.total_iterations_: ", st.total_iterations_)
		print("st.batch_leftover_: ", st.batch_leftover_)
		print("st.started_: ", st.started_)

		st.SkipWithError(
			"The benchmark didn't run, nor was it explicitly skipped. Please call "
			+ "'SkipWithXXX` in your benchmark as appropriate.")

	manager.benchmark_mutex.lock()
	var results:ThreadManager.Result = manager.results
	results.iterations += st.iterations()
	results.cpu_time_used += timer.cpu_time_used()
	results.real_time_used += timer.real_time_used()
	results.manual_time_used += timer.manual_time_used()
	results.complexity_n += st.complexity_length_n()
	CounterLib.Increment(results.counters, st.counters)
	manager.benchmark_mutex.unlock()

	manager.NotifyThreadComplete()


func _init(
			_b:BenchmarkInstance,
			_pcm:PerfCountersMeasurement,
			_reports_for_family:BenchmarkReporter.PerFamilyRunReports) -> void:
	b = _b
	reports_for_family = _reports_for_family
	parsed_benchtime_flag = ParseBenchMinTime(BenchLib.FLAGS_benchmark_min_time)
	if BenchLib.FLAGS_benchmark_dry_run: min_time = 0
	else: min_time = ComputeMinTime(_b, parsed_benchtime_flag)

	if BenchLib.FLAGS_benchmark_dry_run:
		min_warmup_time = 0
	elif b._min_time != 0 and b._min_warmup_time > 0.0:
		min_warmup_time = b._min_warmup_time
	else:
		min_warmup_time = BenchLib.FLAGS_benchmark_min_warmup_time

	warmup_done = true if BenchLib.FLAGS_benchmark_dry_run else not (min_warmup_time > 0.0)

	if BenchLib.FLAGS_benchmark_dry_run: repeats = 1
	elif b._repetitions != 0: repeats = b._repetitions
	else: repeats = BenchLib.FLAGS_benchmark_repetitions

	has_explicit_iteration_count = (b._iterations != 0)

	thread_runner = GetThreadRunner(b.GetUserThreadRunnerFactory(), b._threads)

	if BenchLib.FLAGS_benchmark_dry_run:
		iters = 1
	elif has_explicit_iteration_count:
		iters = ComputeIters(_b, parsed_benchtime_flag)
	else:
		iters = 1

	perf_counters_measurement_ptr = _pcm

	run_results.display_report_aggregates_only = \
		BenchLib.FLAGS_benchmark_report_aggregates_only \
		or BenchLib.FLAGS_benchmark_display_aggregates_only
	run_results.file_report_aggregates_only = \
		BenchLib.FLAGS_benchmark_report_aggregates_only

	if b._aggregation_report_mode != AggregationReportMode.ARM_Unspecified:
		run_results.display_report_aggregates_only = \
			((b._aggregation_report_mode & AggregationReportMode.ARM_DisplayReportAggregatesOnly) != 0);
		run_results.file_report_aggregates_only = \
			((b._aggregation_report_mode & AggregationReportMode.ARM_FileReportAggregatesOnly) != 0);
		#BM_CHECK(FLAGS_benchmark_perf_counters.empty() or (perf_counters_measurement_ptr->num_counters() == 0)), "Perf counters were requested but could not be set up.";


func HasRepeatsRemaining() -> bool:
	return repeats != num_repetitions_done

func DoOneRepetition() -> void:
	assert(HasRepeatsRemaining(), "Already done all repetitions?")

	var is_the_first_repetition:bool = num_repetitions_done == 0;

	# In case a warmup phase is requested by the benchmark, run it now.
	# After running the warmup phase the BenchmarkRunner should be in a state as
	# this warmup never happened except the fact that warmup_done is set. Every
	# other manipulation of the BenchmarkRunner instance would be a bug! Please
	# fix it.
	if not warmup_done: RunWarmUp()

	var i:IterationResults
	# We *may* be gradually increasing the length (iteration count)
	# of the benchmark until we decide the results are significant.
	# And once we do, we report those last results and exit.
	# Please do note that the if there are repetitions, the iteration count
	# is *only* calculated for the *first* repetition, and other repetitions
	# simply use that precomputed iteration count.
	while true:

		b.Setup();
		i = DoNIterations();
		b.Teardown();
		assert( i, "missing iteration results" )

		# Do we consider the results to be significant?
		# If we are doing repetitions, and the first repetition was already done,
		# it has calculated the correct iteration time, so we have run that very
		# iteration count just now. No need to calculate anything. Just report.
		# Else, the normal rules apply.
		var results_are_significant:bool = \
			(not is_the_first_repetition) \
			or has_explicit_iteration_count \
			or ShouldReportIterationResults(i)

		# Good, let's report them!
		if results_are_significant: break

		# Nope, bad iteration. Let's re-estimate the hopefully-sufficient
		# iteration count, and run the benchmark again...

		iters = PredictNumItersNeeded(i);
		assert(iters > i.iters,
			"if we did more iterations than we want to do the next time, " +
			"then we should have accepted the current iteration run.")


	# Produce memory measurements if requested.
	#STUB var memory_result:BenchLib.MemoryManager.Result
	#var memory_iterations:int = 0;
	#if memory_manager != null:
		## Only run a few iterations to reduce the impact of one-time
		## allocations in benchmarks that are not properly managed.
		##STUB memory_iterations = std::min<IterationCount>(16, iters);
		#memory_result = RunMemoryManager(memory_iterations);

	#STUB if profiler_manager != null:
		## We want to externally profile the benchmark for the same number of
		## iterations because, for example, if we're tracing the benchmark then we
		## want trace data to reasonably match PMU data.
		#RunProfilerManager(iters);

	# Ok, now actually report.
	var report:BenchmarkReporter.Run = \
		CreateRunReport(b, i.results,
			#STUB memory_iterations, memory_result,
			0, null,
			i.seconds, num_repetitions_done, repeats);

	if reports_for_family != null:
		reports_for_family.num_runs_done += 1
		if report.skipped == 0:
			reports_for_family.Runs.push_back(report);

	run_results.non_aggregates.push_back(report);

	num_repetitions_done += 1


func GetResults() -> RunResults:
	assert( not HasRepeatsRemaining(), "Did not run all repetitions yet?")
	# Calculate additional statistics over the repetitions of this instance.
	run_results.aggregates_only = StatsLib.ComputeStats(run_results.non_aggregates)
	return run_results


var run_results := RunResults.new()

var b:BenchmarkInstance
var reports_for_family:BenchmarkReporter.PerFamilyRunReports

var parsed_benchtime_flag:Variant # Originally a tagged union of IterationCount or double
var min_time:float
var min_warmup_time:float
var warmup_done:bool
var repeats:int
var has_explicit_iteration_count:bool

var num_repetitions_done:int = 0;

var thread_runner:BenchLib.ThreadRunnerBase

var iters:int # preserved between repetitions!
# So only the first repetition has to find/calculate it,
# the other repetitions will just use that precomputed iteration count.

var perf_counters_measurement_ptr:PerfCountersMeasurement = null


func DoNIterations() -> IterationResults:
	#print("Running ", b.name, " for ", iters)

	#manager.reset(new internal::ThreadManager(b.threads()))
	#var manager:ThreadManager = ThreadManager.new(b._threads)
	var manager:ThreadManager = ThreadManager.new(0)
	assert( manager )

	thread_runner.RunThreads(
		func(thread_idx:int) -> void:
			RunInThread(
				b, iters, thread_idx, manager, perf_counters_measurement_ptr,
					null)) # profiler_manager

	var i := IterationResults.new()

	# Acquire the measurements/counters from the manager, UNDER THE LOCK!
	manager.benchmark_mutex.lock()
	i.results = manager.results
	manager.benchmark_mutex.unlock()

	# And get rid of the manager.
	manager = null

	#STUB BM_VLOG(2) << "Ran in " << i.results.cpu_time_used << "/"
			 #<< i.results.real_time_used << "\n";

	# By using KeepRunningBatch a benchmark can iterate more times than
	# requested, so take the iteration count from i.results.
	@warning_ignore("integer_division")
	i.iters = i.results.iterations / b._threads

	# Base decisions off of real time if requested by this benchmark.
	i.seconds = i.results.cpu_time_used;
	if b._use_manual_time:
		i.seconds = i.results.manual_time_used
	elif b._use_real_time:
		i.seconds = i.results.real_time_used;

	return i

func RunMemoryManager( _memory_iterations:int ) -> BenchLib.MemoryManager.Result:
	print("STUB BenchmarkRunner.RunMemoryManager")
	return null

func RunProfilerManager( _profile_iterations:int ) -> void:
	print("STUB BenchmarkRunner.RunProfilerManager")


func PredictNumItersNeeded( i:IterationResults) -> int:
	# See how much iterations should be increased by.
	# Note: Avoid division by zero with max(seconds, 1ns).
	var multiplier:float = GetMinTimeToApply() * 1.4 / max(i.seconds, 1e-9)

	# If our last run was at least 10% of FLAGS_benchmark_min_time then we
	# use the multiplier directly.
	# Otherwise we use at most 10 times expansion.
	# NOTE: When the last run was at least 10% of the min time the max
	# expansion should be 14x.
	var is_significant:bool = (i.seconds / GetMinTimeToApply()) > 0.1
	if not is_significant:
		multiplier = minf(multiplier, 10.0)

	# So what seems to be the sufficiently-large iteration count? Round up.
	var max_next_iters:int = roundi(maxf(multiplier * i.iters, i.iters + 1.0))
	# But we do have *some* limits though..
	var next_iters:int = min(max_next_iters, kMaxIterations);

	#BM_VLOG(3) << "Next iters: " << next_iters << ", " << multiplier << "\n";
	return next_iters;  # round up before conversion to integer.


func ShouldReportIterationResults(i:IterationResults) -> bool:
	# Determine if this run should be reported;
	# Either it has run for a sufficient amount of time
	# or because an error was reported.
	if i.results.skipped != Statslib.Skipped.NotSkipped: return true
	if BenchLib.FLAGS_benchmark_dry_run: return true
	# Too many iterations already.
	if i.iters >= kMaxIterations:  return true
	# The elapsed time is large enough.
	if i.seconds >= GetMinTimeToApply(): return true
	# CPU time is specified but the elapsed real time greatly exceeds
	# the minimum time.
	# Note that user provided timers are except from this test.
	return ((i.results.real_time_used >= 5 * GetMinTimeToApply()) \
		and not b._use_manual_time)



func GetMinTimeToApply() -> float:
	# In order to reuse functionality to run and measure benchmarks for running
	# a warmup phase of the benchmark, we need a way of telling whether to apply
	# min_time or min_warmup_time. This function will figure out if we are in the
	# warmup phase and therefore need to apply min_warmup_time or if we already
	# in the benchmarking phase and min_time needs to be applied.
	return min_time if warmup_done else min_warmup_time


func FinishWarmUp(_i:int) -> void:
	print("STUB BenchmarkRunner.FinishWarmUp")


func RunWarmUp() -> void:
	print("STUB BenchmarkRunner.RunWarmUp")


func GetThreadRunner(
			userThreadRunnerFactory:Variant,
			num_threads:int ) -> BenchLib.ThreadRunnerBase:

	if userThreadRunnerFactory != null \
	and userThreadRunnerFactory is Callable:
		var threadFactory:Callable = userThreadRunnerFactory
		if threadFactory.is_valid():
			return threadFactory.call(num_threads)

	return ThreadRunnerDefault.new(num_threads)


static func ParseBenchMinTime(value:String) -> Variant:
	if value.is_empty():
		return 0.0

	if value.ends_with('x'):
		var num_iters:int = value.to_int()

		# After a valid parse, p_end should have been set to
		# point to the 'x' suffix.
		assert(num_iters > 0,
				("Malformed iters value passed to --benchmark_min_time: `%s`." +
				" Expected --benchmark_min_time=<integer>x.") % value)
		return num_iters

	assert( value.ends_with('s'), "Value passed to --benchmark_min_time should have a suffix. Eg., `30s` for 30-seconds.")
	var _min_time:float = value.to_float()

	# After a successful parse, p_end should point to the suffix 's',
	# or the end of the string if the suffix was omitted.
	assert(_min_time > 0, ("Malformed seconds value passed to --benchmark_min_time: `%s`." % value) +
		" Expected --benchmark_min_time=<float>x.")

	return _min_time


static func ComputeMinTime(b_instance:BenchmarkInstance, iters_or_time:Variant) -> float:
	if not is_zero_approx(b_instance._min_time):
		return b_instance._min_time
	# If the flag was used to specify number of iters, then return the default
	# min_time.
	return iters_or_time if typeof(iters_or_time) == TYPE_FLOAT \
		else kDefaultMinTime


func ComputeIters( b_instance:BenchmarkInstance, iters_or_time:Variant) -> int:
	if b_instance._iterations != 0: return b_instance._iterations
	# We've already concluded that this flag is currently used to pass
	# iters but do a check here again anyway.
	#BM_CHECK(iters_or_time.tag == BenchTimeType::ITERS);
	return iters_or_time;


class ThreadRunnerDefault extends BenchLib.ThreadRunnerBase:
	func _init( num_threads:int ) ->void:
		if pool.resize( num_threads - 1 ) != OK:
			push_error("Unable to resize ThreadRunnerDefault.pool")

	func RunThreads(fn:Callable) -> void:

	# Called using:
	#thread_runner.RunThreads( func(thread_idx:int) -> void:
		#RunInThread( b, iters, thread_idx, manager, perf_counters_measurement_ptr, null)) # profiler_manager

		# Run all but one thread in separate threads
		for ti:int in pool.size():
			#pool[ti] = thread(fn, ti + 1);
			var thread := Thread.new()
			pool[ti] = thread
			if thread.start(fn.bind(ti+1)) != OK:
				push_error("Failed to start thread")

		# And run one thread here directly.
		# (If we were asked to run just one thread, we don't create new threads.)
		# Yes, we need to do this here *after* we start the separate threads.
		fn.call(0)

		# The main thread has finished. Now let's wait for the other threads.
		for thread in pool:
			thread.wait_to_finish();

	var pool:Array[Thread]
