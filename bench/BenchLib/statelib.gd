@tool

# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#ifndef BENCHMARK_STATE_H_
#define BENCHMARK_STATE_H_

#if defined(_MSC_VER)
#pragma warning(push)
#pragma warning(disable : 4251 4324)
#endif

#include <cassert>
#include <string>
#include <vector>

#include "benchmark/counter.h"
#include "benchmark/macros.h"
#include "benchmark/statistics.h"
const Statslib = preload("uid://c8w76q8bhpf8q")
const Skipped = Statslib.Skipped

#include "benchmark/types.h"

#namespace benchmark {

#namespace internal {
#class BenchmarkInstance;
const BenchmarkInstance = BenchLib.BenchmarkInstance
#class ThreadTimer;
#class ThreadManager;
const Threadlib = preload("uid://hgmj8mo7h7dy")
const ThreadManager = Threadlib.ThreadManager

#class PerfCountersMeasurement;
const PerfCounters = preload("uid://b57mx2pbhhtfa")
const PerfCountersMeasurement = PerfCounters.PerfCountersMeasurement
const Counter = BenchLib.Counter
#}  // namespace internal

#class ProfilerManager;
const ProfilerManager = BenchLib.ProfilerManager

#class BENCHMARK_EXPORT BENCHMARK_INTERNAL_CACHELINE_ALIGNED State {
class State:
	# public:
	#  struct StateIterator;
	#  friend struct StateIterator;

	# Returns iterators used to run each iteration of a benchmark using a
	# C++11 ranged-based for loop. These functions should not be called directly.

	# REQUIRES: The benchmark has not started running yet. Neither begin nor end
	# have been called previously.

	# NOTE: KeepRunning may not be used after calling either of these functions.
	#inline BENCHMARK_ALWAYS_INLINE StateIterator begin() {
	#  return StateIterator(this);
	#}
	#inline BENCHMARK_ALWAYS_INLINE StateIterator end() {
	#  StartKeepRunning();
	#  return StateIterator();
	#}

	# NOTE: I dont think I can directly represent the begin() and end()
	# functions to retrieve iterators in gdscript. I might be able to hack it
	# but I'd had it for every location, so we'll see. so far I dont remember
	# seeing a location where begin and end are used, so I'll look.
	# it looks like we're not supposed to use the iterators directly. So i wonder
	# if the start and end keep running
	# I would think that the c++ standard range loop would be implemented using
	# the begin and end functions, so I will have to incorporate it into the
	# init and test.

	# NOTE: Support for a range based for loop in gdscript.
	func _iter_get(iter:Variant) -> Variant:
		return iter

	func _iter_init(iter:Array) -> bool:
		if skipped(): return false
		StartKeepRunning()
		iter[0] = max_iterations
		return iter[0] > 0

	func _iter_next(iter:Array) -> bool:
		assert(iter[0] >= 0)
		iter[0] -= 1
		if iter[0] == 0:
			FinishKeepRunning()
			return false
		return true


	#  inline bool KeepRunning();
	#inline BENCHMARK_ALWAYS_INLINE bool State::KeepRunning() {
	#  return KeepRunningInternal(1, /*is_batch=*/false);
	#}
	## Returns true if the benchmark should continue through another iteration.
	## NOTE: A benchmark may not return from the test until KeepRunning() has
	## returned false.
	func KeepRunning() -> bool:
		return KeepRunningInternal(1, false)


	#  inline bool KeepRunningBatch(IterationCount n);
	#inline BENCHMARK_ALWAYS_INLINE bool State::KeepRunningBatch(IterationCount n) {
	#  return KeepRunningInternal(n, /*is_batch=*/true);
	#}
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
	func KeepRunningBatch(n:int) -> bool: #n:IterationCount
		return KeepRunningInternal(n, true);


	#  void PauseTiming();
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

			for key:String in measurements.keys():
				var cnt:Counter = measurements.get(key)
				# Counter was inserted with `kAvgIterations` flag by the constructor.
				assert(counters.has(key))
				counters[key].value += cnt.value


	#  void ResumeTiming();
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


	#  void SkipWithMessage(const std::string& msg);
	## REQUIRES: 'SkipWithMessage(...)' or 'SkipWithError(...)' has not been
	##						called previously by the current thread.
	## Report the benchmark as resulting in being skipped with the specified
	## 'msg'.
	## After this call the user may explicitly 'return' from the benchmark.
	##
	## If the ranged-for style of benchmark loop is used, the user must explicitly
	## break from the loop, otherwise all future iterations will be run.
	## If the 'KeepRunning()' loop is used the current thread will automatically
	## exit the loop at the end of the current iteration.
	##
	## For threaded benchmarks only the current thread stops executing and future
	## calls to `KeepRunning()` will block until all threads have completed
	## the `KeepRunning()` loop. If multiple threads report being skipped only the
	## first skip message is used.
	##
	## NOTE: Calling 'SkipWithMessage(...)' does not cause the benchmark to exit
	## the current scope immediately. If the function is called from within
	## the 'KeepRunning()' loop the current iteration will finish. It is the users
	## responsibility to exit the scope as needed.
	func SkipWithMessage(_msg:String) -> void:
		print("STUB: State.SkipWithMessage")


	#  void SkipWithError(const std::string& msg);
	## REQUIRES: 'SkipWithMessage(...)' or 'SkipWithError(...)' has not been
	##						called previously by the current thread.
	## Report the benchmark as resulting in an error with the specified 'msg'.
	## After this call the user may explicitly 'return' from the benchmark.
	##
	## If the ranged-for style of benchmark loop is used, the user must explicitly
	## break from the loop, otherwise all future iterations will be run.
	## If the 'KeepRunning()' loop is used the current thread will automatically
	## exit the loop at the end of the current iteration.
	##
	## For threaded benchmarks only the current thread stops executing and future
	## calls to `KeepRunning()` will block until all threads have completed
	## the `KeepRunning()` loop. If multiple threads report an error only the
	## first error message is used.
	##
	## NOTE: Calling 'SkipWithError(...)' does not cause the benchmark to exit
	## the current scope immediately. If the function is called from within
	## the 'KeepRunning()' loop the current iteration will finish. It is the users
	## responsibility to exit the scope as needed.
	func SkipWithError(msg:String) -> void:
		skipped_ = Skipped.SkippedWithError
		manager_.benchmark_mutex.lock()
		if Skipped.NotSkipped == manager_.results.skipped:
			manager_.results.skip_message = msg
			manager_.results.skipped = skipped_
		manager_.benchmark_mutex.unlock()

		total_iterations_ = 0
		if timer_.running(): timer_.StopTimer()


	#  bool skipped() const { return internal::NotSkipped != skipped_; }
	## Returns true if 'SkipWithMessage(...)' or 'SkipWithError(...)' was called.
	func skipped() -> bool: return skipped_ != Skipped.NotSkipped


	#  bool error_occurred() const { return internal::SkippedWithError == skipped_; }
	## Returns true if an error has been reported with 'SkipWithError(...)'.
	func error_occurred() ->bool: return Skipped.SkippedWithError == skipped_


	#  void SetIterationTime(double seconds);
	## REQUIRES: called exactly once per iteration of the benchmarking loop.
	## Set the manually measured time for this benchmark iteration, which
	## is used instead of automatically measured time if UseManualTime() was
	## specified.
	##
	## For threaded benchmarks the final value will be set to the largest
	## reported values.
	func SetIterationTime(seconds:float) -> void:
		assert(started_ and not finished_ and not skipped())
		assert(timer_ != null)
		timer_.SetIterationTime(seconds)


	#  BENCHMARK_ALWAYS_INLINE
	#  void SetBytesProcessed(int64_t bytes) {
	#    counters["bytes_per_second"] =
	#        Counter(static_cast<double>(bytes), Counter::kIsRate, Counter::kIs1024);
	#  }
	## Set the number of bytes processed by the current benchmark
	## execution.	This routine is typically called once at the end of a
	## throughput oriented benchmark.
	##
	## REQUIRES: a benchmark has exited its benchmarking loop.
	func SetBytesProcessed(bytes:int) -> void:
		counters["bytes_per_second"] = \
			Counter.new(bytes, Counter.Flags.kIsRate, Counter.OneK.kIs1024)


	#  BENCHMARK_ALWAYS_INLINE
	#  int64_t bytes_processed() const {
	#    if (counters.find("bytes_per_second") != counters.end())
	#      return static_cast<int64_t>(counters.at("bytes_per_second"));
	#    return 0;
	#  }
	func bytes_processed() -> int:
		if counters.has("bytes_per_second"):
			return counters.get("bytes_per_second")
		return 0


	#  BENCHMARK_ALWAYS_INLINE
	#  void SetComplexityN(ComplexityN complexity_n) {
	#    complexity_n_ = complexity_n;
	#  }
	## If this routine is called with complexity_n > 0 and complexity report is
	## requested for the
	## family benchmark, then current benchmark will be part of the computation
	## and complexity_n will
	## represent the length of N.
	func SetComplexityN(complexity_n:int) -> void: #ComplexityN
		complexity_n_ = complexity_n


	#  BENCHMARK_ALWAYS_INLINE
	#  ComplexityN complexity_length_n() const { return complexity_n_; }
	func complexity_length_n() -> int: #ComplexityN
		return complexity_n_


	#  BENCHMARK_ALWAYS_INLINE
	#  void SetItemsProcessed(int64_t items) {
	#    counters["items_per_second"] =
	#        Counter(static_cast<double>(items), benchmark::Counter::kIsRate);
	#  }
	## If this routine is called with items > 0, then an items/s
	## label is printed on the benchmark report line for the currently
	## executing benchmark. It is typically called at the end of a processing
	## benchmark where a processing items/second output is desired.
	##
	## REQUIRES: a benchmark has exited its benchmarking loop.
	func SetItemsProcessed(items:int) -> void:
		counters["items_per_second"] = \
			Counter.new(items, Counter.Flags.kIsRate)


	#  BENCHMARK_ALWAYS_INLINE
	#  int64_t items_processed() const {
	#    if (counters.find("items_per_second") != counters.end())
	#      return static_cast<int64_t>(counters.at("items_per_second"));
	#    return 0;
	#  }
	func items_processed() -> int:
		if counters.has("items_per_second"):
			return counters.get("items_per_second")
		return 0;


	#  void SetLabel(const std::string& label);
	## If this routine is called, the specified label is printed at the
	## end of the benchmark report line for the currently executing
	## benchmark.	Example:
	##	static void BM_Compress(benchmark::State& state) {
	##		...
	##		double compress = input_size / output_size;
	##		state.SetLabel(StrFormat("compress:%.1f%%", 100.0*compression));
	##	}
	## Produces output that looks like:
	##	BM_Compress	 50				 50	 14115038	compress:27.3%
	##
	## REQUIRES: a benchmark has exited its benchmarking loop.
	func SetLabel(_label:String) -> void:
		print("STUB: State.SetLabel")


	#BENCHMARK_ALWAYS_INLINE
	#int64_t range(std::size_t pos = 0) const {
	#	assert(range_.size() > pos);
	#	return range_[pos];
	#}
	## Range arguments for this run. CHECKs if the argument has been set.
	func get_range(pos:int = 0) -> int:
		assert(_range.size() > pos, "_range.size():%d <= pos:%d" % [_range.size(), pos])
		return _range[pos]


	#  BENCHMARK_DEPRECATED_MSG("use 'range(0)' instead")
	#  int64_t range_x() const { return range(0); }


	#  BENCHMARK_DEPRECATED_MSG("use 'range(1)' instead")
	#  int64_t range_y() const { return range(1); }


	#  BENCHMARK_ALWAYS_INLINE
	#  int threads() const { return threads_; }
	## Number of threads concurrently executing the benchmark.
	func threads() -> int: return threads_


	#  BENCHMARK_ALWAYS_INLINE
	#  int thread_index() const { return thread_index_; }
	## Index of the executing thread. Values from [0, threads).
	func thread_index() -> int: return thread_index_


	#  BENCHMARK_ALWAYS_INLINE
	#  IterationCount iterations() const {
	#    if (BENCHMARK_BUILTIN_EXPECT(!started_, false)) {
	#      return 0;
	#    }
	#    return max_iterations - total_iterations_ + batch_leftover_;
	#  }
	func iterations() -> int:
		if not started_: return 0
		return max_iterations - total_iterations_ + batch_leftover_


	#  BENCHMARK_ALWAYS_INLINE
	#  std::string name() const { return name_; }
	func name() -> String: return name_


	#  size_t range_size() const { return range_.size(); }
	func range_size() -> int: return _range.size()


	# private:
	#  IterationCount total_iterations_;

	## items we expect on the first cache line (ie 64 bytes of the struct)
	## When total_iterations_ is 0, KeepRunning() and friends will return false.
	## May be larger than max_iterations.
	var total_iterations_:int = 0

	#  IterationCount batch_leftover_;
	## When using KeepRunningBatch(), batch_leftover_ holds the number of
	## iterations beyond max_iters that were run. Used to track
	## completed_iterations_ accurately.
	var batch_leftover_:int = 0
	#
	# public:
	#  const IterationCount max_iterations;
	var max_iterations:int

	# private:
	#  bool started_;
	var started_:bool = false
	#  bool finished_;
	var finished_:bool = false
	#  internal::Skipped skipped_;
	var skipped_:Skipped = Skipped.NotSkipped

	#  std::vector<int64_t> range_;
	## items we don't need on the first cache line
	var _range:Array[int]

	#  ComplexityN complexity_n_;
	var complexity_n_:int = 0 #ComplexityN

	# public:
	#  UserCounters counters;
	## Container for user-defined counters.
	var counters:Dictionary[String, Counter] #UserCounters
	#
	# private:
	#  State(std::string name, IterationCount max_iters,
	#        const std::vector<int64_t>& ranges, int thread_i, int n_threads,
	#        internal::ThreadTimer* timer, internal::ThreadManager* manager,
	#        internal::PerfCountersMeasurement* perf_counters_measurement,
	#        ProfilerManager* profiler_manager);
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
		_range                     = ranges
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

	#  void StartKeepRunning();
	func StartKeepRunning() ->void:
		assert(not started_ and not finished_)
		started_ = true;
		total_iterations_ = 0 if skipped() else max_iterations
		if profiler_manager_ != null:
			profiler_manager_.AfterSetupStart()
		@warning_ignore("return_value_discarded")
		manager_.StartStopBarrier()
		if not skipped(): ResumeTiming()

	#  inline bool KeepRunningInternal(IterationCount n, bool is_batch);
	## Implementation of KeepRunning() and KeepRunningBatch().
	## is_batch must be true unless n is 1.
	func KeepRunningInternal(n:int, is_batch:bool) -> bool: #n:IterationCount
		assert(n > 0);
		assert(is_batch || n == 1);
		if total_iterations_ >= n:
			total_iterations_ -= n;
			return true;

		if not started_:
			StartKeepRunning();
			if not skipped() and total_iterations_ >= n:
				total_iterations_ -= n
				return true
		if is_batch and total_iterations_ != 0:
			batch_leftover_ = n - total_iterations_
			total_iterations_ = 0
			return true

		FinishKeepRunning();
		return false;


	#  void FinishKeepRunning();
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

	#  const std::string name_;
	var name_:String
	#  const int thread_index_;
	var thread_index_:int
	#  const int threads_;
	var threads_:int

	#  internal::ThreadTimer* const timer_;
	var timer_:ThreadTimer
	#  internal::ThreadManager* const manager_;
	var manager_:ThreadManager
	#  internal::PerfCountersMeasurement* const perf_counters_measurement_;
	var perf_counters_measurement_:PerfCountersMeasurement
	#  ProfilerManager* const profiler_manager_;
	var profiler_manager_:ProfilerManager

	#  friend class internal::BenchmarkInstance;
	#};



#struct State::StateIterator {
#  struct BENCHMARK_UNUSED Value {};
#  typedef std::forward_iterator_tag iterator_category;
#  typedef Value value_type;
#  typedef Value reference;
#  typedef Value pointer;
#  typedef std::ptrdiff_t difference_type;

# private:
#  friend class State;
#  BENCHMARK_ALWAYS_INLINE
#  StateIterator() : cached_(0), parent_() {}

#  BENCHMARK_ALWAYS_INLINE
#  explicit StateIterator(State* st)
#      : cached_(st->skipped() ? 0 : st->max_iterations), parent_(st) {}

# public:
#  BENCHMARK_ALWAYS_INLINE
#  Value operator*() const { return Value(); }

#  BENCHMARK_ALWAYS_INLINE
#  StateIterator& operator++() {
#    assert(cached_ > 0);
#    --cached_;
#    return *this;
#  }

#  BENCHMARK_ALWAYS_INLINE
#  bool operator!=(StateIterator const&) const {
#    if (BENCHMARK_BUILTIN_EXPECT(cached_ != 0, true)) return true;
#    parent_->FinishKeepRunning();
#    return false;
#  }

# private:
#  IterationCount cached_;
#  State* const parent_;
#};

#}  // namespace benchmark

#if defined(_MSC_VER)
#pragma warning(pop)
#endif

#endif  // BENCHMARK_STATE_H_
