@tool
#ifndef BENCHMARK_API_INTERNAL_H
#define BENCHMARK_API_INTERNAL_H

#include <cmath>
#include <iosfwd>
#include <limits>
#include <memory>
#include <string>
#include <vector>

#include "benchmark/benchmark_api.h"
#include "benchmark/reporter.h"
#include "benchmark/sysinfo.h"
#include "commandlineflags.h"
const Benchmark = BenchLib.Benchmark
const ProfilerManager = BenchLib.ProfilerManager
const BenchmarkName = BenchLib.BenchmarkName
const TimeUnit = BenchLib.TimeUnit
const Counter = BenchLib.Counter

const Statslib = preload("uid://c8w76q8bhpf8q")
const Statistics = Statslib.Statistics

const Statelib = preload("uid://wwktui5nflyr")
const State = Statelib.State

const Perflib = preload("uid://b57mx2pbhhtfa")
const PerfCountersMeasurement = Perflib.PerfCountersMeasurement

const Threadlib = preload("uid://hgmj8mo7h7dy")
const ThreadManager = Threadlib.ThreadManager

#namespace benchmark {
#namespace internal {

#class BenchmarkInstance {
## Information kept per benchmark we may want to run
class BenchmarkInstance:
	# public:
	#  BenchmarkInstance(benchmark::Benchmark* benchmark, int family_idx,
	#                    int per_family_instance_idx,
	#                    const std::vector<int64_t>& args, int thread_count);
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
			name.args += str(arg)
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


	#  const BenchmarkName& name() const { return name_; }
	#  int family_index() const { return family_index_; }
	#  int per_family_instance_index() const { return per_family_instance_index_; }
	#  AggregationReportMode aggregation_report_mode() const {
	#    return aggregation_report_mode_;
	#  }
	#  TimeUnit time_unit() const { return time_unit_; }
	#  bool measure_process_cpu_time() const { return measure_process_cpu_time_; }
	#  bool use_real_time() const { return use_real_time_; }
	#  bool use_manual_time() const { return use_manual_time_; }
	#  BigO complexity() const { return complexity_; }
	#  BigOFunc* complexity_lambda() const { return complexity_lambda_; }
	#  const std::vector<Statistics>& statistics() const { return statistics_; }
	#  int repetitions() const { return repetitions_; }
	#  double min_time() const { return min_time_; }
	#  double min_warmup_time() const { return min_warmup_time_; }
	#  IterationCount iterations() const { return iterations_; }
	#  int threads() const { return threads_; }

	#  void Setup() const;
	func Setup() -> void:
		if _setup != null and _setup.is_valid():
			var st := State.new( name.function_name, 1, _args, 0, _threads,
					null, null, null, null)
			_setup.call(st)

	#  void Teardown() const;
	func Teardown() -> void:
		if _teardown != null and _teardown.is_valid():
			var st := State.new( name.function_name,  1, _args,  0, _threads,
					null, null, null, null)
			_teardown.call(st)

	#  const auto& GetUserThreadRunnerFactory() const {
	#    return benchmark_.threadrunner_;
	#  }
	func GetUserThreadRunnerFactory() -> Callable:
		return _benchmark.threadrunner


	#  State Run(IterationCount iters, int thread_id, internal::ThreadTimer* timer,
	#            internal::ThreadManager* manager,
	#            internal::PerfCountersMeasurement* perf_counters_measurement,
	#            ProfilerManager* profiler_manager) const;
	func Run( iters:int, thread_id:int, timer:ThreadTimer,
				manager:ThreadManager,
				perf_counters_measurement:PerfCountersMeasurement,
				profiler_manager:ProfilerManager) -> State:
		var st := State.new(
			name.function_name, iters, _args, thread_id, _threads, timer,
			manager, perf_counters_measurement, profiler_manager)
		_benchmark.Run(st)
		return st;


	# private:
	#  BenchmarkName name_;
	var name := BenchmarkName.new()
	#  benchmark::Benchmark& benchmark_;
	var _benchmark:Benchmark
	#  const int family_index_;
	var _family_index:int
	#  const int per_family_instance_index_;
	var _per_family_instance_index:int
	#  AggregationReportMode aggregation_report_mode_;
	var _aggregation_report_mode:int # from enum AggregationReportMode
	#  const std::vector<int64_t>& args_;
	var _args:PackedInt64Array
	#  TimeUnit time_unit_;
	var _time_unit:TimeUnit
	#  bool measure_process_cpu_time_;
	var _measure_process_cpu_time:bool
	#  bool use_real_time_;
	var _use_real_time:bool
	#  bool use_manual_time_;
	var _use_manual_time:bool
	#  BigO complexity_;
	var _complexity:Statslib.BigO
	#  BigOFunc* complexity_lambda_;
	var _complexity_lambda:Callable
	#  UserCounters counters_;
	@warning_ignore("unused_private_class_variable")
	var _counters:Dictionary[String, Counter]
	#  const std::vector<Statistics>& statistics_;
	var _statistics:Array[Statistics]
	#  int repetitions_;
	var _repetitions:int
	#  double min_time_;
	var _min_time:float
	#  double min_warmup_time_;
	var _min_warmup_time:float
	#  IterationCount iterations_;
	var _iterations:int
	#  int threads_;  // Number of concurrent threads to us
	var _threads:int	# Number of concurrent threads to us

	#  callback_function setup_;
	var _setup:Callable
	#  callback_function teardown_;
	var _teardown:Callable
#};

#bool FindBenchmarksInternal(const std::string& re,
#                            std::vector<BenchmarkInstance>* benchmarks,
#                            std::ostream* Err);
#
#bool IsZero(double n);

#BENCHMARK_EXPORT
#ConsoleReporter::OutputOptions GetOutputOptions(bool force_no_color = false);

#}  // end namespace internal
#}  // end namespace benchmark

#endif  // BENCHMARK_API_INTERNAL_H
