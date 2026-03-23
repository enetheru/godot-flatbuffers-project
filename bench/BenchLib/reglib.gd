@tool
# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#				 http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

const BenchmarkInstance = BenchLib.BenchmarkInstance

const Statslib = preload("uid://c8w76q8bhpf8q")
const Check = preload("uid://no47e6pld06k")
const Log = preload("uid://dccn5dspfd8q4")




## For non-dense Range, intermediate values are powers of kRangeMultiplier.
const kRangeMultiplier:int = 8

## The size of a benchmark family determines is the number of inputs to repeat
## the benchmark on. If this is "large" then warn the user during configuration.
const kMaxFamilySize:int = 100

const kDisabledPrefix:String = "DISABLED_"


## Class for managing registered benchmarks. Note that each registered
## benchmark identifies a family of related benchmarks to run.
class BenchmarkFamilies:
	## Registers a benchmark family and returns the index assigned to it.
	func AddBenchmark(family:Benchmark) -> int:
		_mutex.lock()
		var index:int = _families.size()
		_families.push_back(family)
		_mutex.unlock()
		return index;

	## Clear all registered benchmark families.
	func ClearBenchmarks() -> void:
		_mutex.lock()
		_families.clear();
		_mutex.unlock()

	## Extract the list of benchmark instances that match the specified
	## regular expression.
	func FindBenchmarks(spec:String, benchmarks:Array[BenchLib.BenchmarkInstance]) -> bool:
		assert(not spec.is_empty(), "spec must not be an empty string")
		# Make regular expression out of command-line flag
		var re := RegEx.new()
		var is_negative_filter:bool = false
		if spec[0] == '-':
			spec = spec.trim_prefix('-')
			is_negative_filter = true

		if re.compile(spec, true) != OK:
			push_error( "Could not compile benchmark RegEx")
			return false

		# Special list of thread counts to use when none are specified
		const one_thread:Array[int] = [1]

		var next_family_index:int = 0

		_mutex.lock()
		for family:Benchmark in _families:
			var family_index:int = next_family_index
			var per_family_instance_index:int = 0

			# Family was deleted or benchmark doesn't match
			if not is_instance_valid(family):
				push_error("invalid instance")
				continue

			if family.ArgsCnt() == -1:
				family._args = [[]]

			var thread_counts:Array[int] = one_thread \
				if family._thread_counts.is_empty() else family._thread_counts

			var family_size:int = family._args.size() * thread_counts.size()

			# The benchmark will be run at least 'family_size' different inputs.
			# If 'family_size' is very large warn the user.
			if family_size > kMaxFamilySize:
				push_error("The number of inputs is very large. ", family._name,
					" will be repeated at least ", family_size, " times")

			# reserve in the special case the regex ".", since we know the final
			# family size. this doesn't take into account any disabled benchmarks
			# so worst case we reserve more than we need.
			var benchmarks_last:int = benchmarks.size()
			if spec == ".":
				if benchmarks.resize(benchmarks_last + family_size) != OK:
					push_error("Failure to resize benchmarks")
					return false

			for args:PackedInt64Array in family._args:
				for num_threads:int in thread_counts:
					var binstance := BenchLib.BenchmarkInstance.new(
						family, family_index, per_family_instance_index,
						args, num_threads)

					var full_name:String = str(binstance.name)
					var re_match := re.search(full_name)
					if full_name.rfind(kDisabledPrefix, 0) != 0 \
					and (re_match and not is_negative_filter) \
					or (not re_match and is_negative_filter):
						if benchmarks_last <= benchmarks.size() -1:
							benchmarks[benchmarks_last] = binstance
							benchmarks_last += 1
						else:
							benchmarks.push_back(binstance)

						per_family_instance_index += 1

						# Only bump the next family index once we've established that
						# at least one instance of this family will be run.
						if next_family_index == family_index:
							next_family_index += 1
		_mutex.unlock()
		return true;

	var _families:Array[Benchmark]
	var _mutex := Mutex.new()


static func RegisterBenchmarkInternal( bench:Benchmark ) -> Benchmark:
	var families := BenchLib.GetInstance();
	var _index:int = families.AddBenchmark(bench);
	return bench


#=============================================================================//
#  Benchmark
#=============================================================================//

@abstract
class Benchmark:

	@warning_ignore_start("unused_private_class_variable")
	var _name:String
	var _aggregation_report_mode:Statslib.AggregationReportMode = \
			Statslib.AggregationReportMode.ARM_Unspecified
	var _arg_names:PackedStringArray	# Args for all benchmark runs
	var _args:Array[PackedInt64Array] # Args for all benchmark runs

	var _time_unit:BenchLib.TimeUnit = BenchLib.default_time_unit

	var _use_default_time_unit:bool = true

	var _range_multiplier:int = kRangeMultiplier
	var _min_time:float = 0
	var _min_warmup_time:float = 0
	var _iterations:int = 0
	var _repetitions:int = 0
	var _measure_process_cpu_time:bool = false
	var _use_real_time:bool = false
	var _use_manual_time:bool = false
	var _complexity:Statslib.BigO = Statslib.BigO.oNone
	var _complexity_lambda:Callable #BigOFunc
	var _statistics:Array[BenchLib.Statistics] = []
	var _thread_counts:Array[int] = []

	var _setup:Callable
	var _teardown:Callable

	var threadrunner:Callable = Callable() #threadrunner_factory
	@warning_ignore_restore("unused_private_class_variable")

	# Benchmark::Benchmark(const std::string& name)
	# 			: name_(name),
	# 					aggregation_report_mode_(internal::ARM_Unspecified),
	# 					time_unit_(GetDefaultTimeUnit()),
	# 					use_default_time_unit_(true),
	# 					range_multiplier_(kRangeMultiplier),
	# 					min_time_(0),
	# 					min_warmup_time_(0),
	# 					iterations_(0),
	# 					repetitions_(0),
	# 					measure_process_cpu_time_(false),
	# 					use_real_time_(false),
	# 					use_manual_time_(false),
	# 					complexity_(oNone),
	# 					complexity_lambda_(nullptr) {
	# 	ComputeStatistics("mean", StatisticsMean);
	# 	ComputeStatistics("median", StatisticsMedian);
	# 	ComputeStatistics("stddev", StatisticsStdDev);
	# 	ComputeStatistics("cv", StatisticsCV, kPercentage);
	# }

	func _init( name:String ) -> void:
		_name = name
		@warning_ignore_start("return_value_discarded")
		ComputeStatistics("mean", Statslib.StatisticsMean)
		ComputeStatistics("median", Statslib.StatisticsMedian)
		ComputeStatistics("stddev", Statslib.StatisticsStdDev)
		ComputeStatistics("cv", Statslib.StatisticsCV, Statslib.StatisticUnit.kPercentage)
		@warning_ignore_restore("return_value_discarded")

	#Benchmark::~Benchmark() {}

	@abstract
	func Run( state:BenchLib.State ) -> void

	# Benchmark* Benchmark::Name(const std::string& name) {
	# 	SetName(name);
	# 	return this;
	# }
	func Name(name:String) ->  Benchmark:
		SetName(name)
		return self

	# Benchmark* Benchmark::Arg(int64_t x) {
	# 	BM_CHECK(ArgsCnt() == -1 || ArgsCnt() == 1);
	# 	args_.push_back({x});
	# 	return this;
	# }
	func Arg(x:int) -> Benchmark:
		@warning_ignore("return_value_discarded")
		Check.BM_CHECK(ArgsCnt() == -1 or ArgsCnt() == 1)
		_args.push_back([x])
		return self

	# Benchmark* Benchmark::Unit(TimeUnit unit) {
	# 	time_unit_ = unit;
	# 	use_default_time_unit_ = false;
	# 	return this;
	# }

	# Benchmark* Benchmark::Range(int64_t start, int64_t limit) {
	# 	BM_CHECK(ArgsCnt() == -1 || ArgsCnt() == 1);
	# 	std::vector<int64_t> arglist;
	# 	internal::AddRange(&arglist, start, limit, range_multiplier_);
	# 	for (int64_t i : arglist) {
	# 			args_.push_back({i});
	# 	}
	# 	return this;
	# }

	func AddRange(start:int, limit:int) -> Benchmark:
		assert(ArgsCnt() == -1 or ArgsCnt() == 1)
		var arglist:PackedInt64Array
		arglist = MakeRange(arglist, start, limit, _range_multiplier)
		for i:int in arglist:
			_args.push_back([i])
		return self


	#void AddRange(std::vector<T>* dst, T lo, T hi, int mult) {
	func MakeRange(dst:Array, lo:int, hi:int, mult:int) -> PackedInt64Array:
		assert( hi >= lo )
		assert( mult >= 2 )

		# Add "lo"
		dst.push_back(lo);

		# Handle lo == hi as a special case, so we then know
		# lo < hi and so it is safe to add 1 to lo and subtract 1
		# from hi without falling outside of the range of T.
		if lo == hi: return dst

		# Ensure that lo_inner <= hi_inner below.
		if lo + 1 == hi:
			dst.push_back(hi)
			return dst

		# Add all powers of 'mult' in the range [lo+1, hi-1] (inclusive).
		var lo_inner:int = lo + 1
		var hi_inner:int = hi - 1

		# Insert negative values
		if lo_inner < 0:
			dst.append_array(AddNegatedPowers(lo_inner, mini(hi_inner, -1), mult))

		# Treat 0 as a special case (see discussion on #762).
		if lo < 0 and hi >= 0: dst.push_back(0)

		# Insert positive values
		if hi_inner > 0:
			dst.append_array(AddPowers(maxi(lo_inner, 1), hi_inner, mult))

		# Add "hi" (if different from last value).
		if hi != dst.back(): dst.push_back(hi)

		return dst


	# Append the powers of 'mult' in the closed interval [lo, hi].
	# Returns iterator to the start of the inserted range.
	#typename std::vector<T>::iterator AddPowers(std::vector<T>* dst, T lo, T hi,
											#int mult) {
	func AddPowers(lo:int, hi:int, mult:int) -> Array:
		var _l:Log.LogType = Check.BM_CHECK_GE(lo, 0)
		_l = Check.BM_CHECK_GE(hi, lo)
		_l = Check.BM_CHECK_GE(mult, 2)

		var dst:Array = []

		#static const T kmax = std::numeric_limits<T>::max();
		const kmax:int = 0x7FFFFFFFFFFFFFFF

		# Space out the values in multiples of "mult"
		#for (T i = static_cast<T>(1); i <= hi; i = static_cast<T>(i * mult)) {
		var i:int = 1
		while i < hi:
			if i >= lo: dst.push_back(i)
			# Break the loop here since multiplying by
			# 'mult' would move outside of the range of T
			i = i * mult
			if i > kmax / mult: break

		return dst


	func AddNegatedPowers(lo:int, hi:int, mult:int) -> Array:
		# We negate lo and hi so we require that they cannot be equal to 'min'.
		#BM_CHECK_GT(lo, std::numeric_limits<T>::min());
		#BM_CHECK_GT(hi, std::numeric_limits<T>::min());
		var _l:Log.LogType = Check.BM_CHECK_GE(hi, lo)
		_l = Check.BM_CHECK_LE(hi, 0)

		# Add positive powers, then negate and reverse.
		# Casts necessary since small integers get promoted
		# to 'int' when negating.
		var lo_complement:int = -lo
		var hi_complement:int = -hi

		var _powers:Array = AddPowers(hi_complement, lo_complement, mult)
		var dst:Array = _powers.map(func(i:int)->int:return i * -1)
		dst.reverse()
		return dst


	# Benchmark* Benchmark::Ranges(
	# 			const std::vector<std::pair<int64_t, int64_t>>& ranges) {
	# 	BM_CHECK(ArgsCnt() == -1 || ArgsCnt() == static_cast<int>(ranges.size()));
	# 	std::vector<std::vector<int64_t>> arglists(ranges.size());
	# 	for (std::size_t i = 0; i < ranges.size(); i++) {
	# 		internal::AddRange(&arglists[i], ranges[i].first, ranges[i].second,
	# 				range_multiplier_);
	# 	}
	# 	ArgsProduct(arglists);
	# 	return this;
	# }
	func AddRanges( ...ranges:Array) -> Benchmark:
		#BM_CHECK(ArgsCnt() == -1 || ArgsCnt() == static_cast<int>(ranges.size()));
		assert(ArgsCnt() == -1 or ArgsCnt() == ranges.size())
		#std::vector<std::vector<int64_t>> arglists(ranges.size());
		var arglists:Array[PackedInt64Array]
		if arglists.resize(ranges.size()) != OK:
			printerr("Failed to resize arglists")
		#for (std::size_t i = 0; i < ranges.size(); i++) {
		for i:int in ranges.size():
			#internal::AddRange(&arglists[i], ranges[i].first, ranges[i].second,
					#range_multiplier_);
			var r:PackedInt64Array = ranges[i]
			arglists[i] = MakeRange(arglists[i], r[0], r[1], _range_multiplier)
		return ArgsProduct(arglists)


	# Benchmark* Benchmark::ArgsProduct(
	# 			const std::vector<std::vector<int64_t>>& arglists) {
	# 	BM_CHECK(ArgsCnt() == -1 || ArgsCnt() == static_cast<int>(arglists.size()));
	func ArgsProduct( arglists:Array[PackedInt64Array] ) -> Benchmark:
		assert(ArgsCnt() == -1 or ArgsCnt() == arglists.size())

	# 	std::vector<std::size_t> indices(arglists.size());
		var indices:PackedInt64Array
		if indices.resize(arglists.size()) != OK:
			printerr("Failed to resize indices list.")
	# 	const std::size_t total = std::accumulate(
	# 					std::begin(arglists), std::end(arglists), std::size_t{1},
	# 					[](const std::size_t res, const std::vector<int64_t>& arglist) {
	# 							return res * arglist.size();
	# 					});
		var total:int = arglists.reduce(
			func(res:int, arglist:Array) -> int:
				return res * arglist.size(),
			1)
	# 	std::vector<int64_t> args;
		var args:PackedInt64Array
	# 	args.reserve(arglists.size());
		if args.resize(arglists.size()) != OK:
			printerr("Failed to resize args list.")
	# 	for (std::size_t i = 0; i < total; i++) {
		for i:int in total:
	# 		for (std::size_t arg = 0; arg < arglists.size(); arg++) {
			for arg:int in arglists.size():
	# 			args.push_back(arglists[arg][indices[arg]]);
				var arglist:Array = arglists[arg]
				var value:int = arglist[indices[arg]]
				args[arg] = value
	# 		args_.push_back(args);
			_args.push_back(args.duplicate())
	# 		args.clear();
			#NOTE: Clearing in gdscript shrinks the array.
			# which we dont want to do.

	# 		std::size_t arg = 0;
			var arg:int = 0

	# 		do {
	# 				indices[arg] = (indices[arg] + 1) % arglists[arg].size();
	# 		} while (indices[arg++] == 0 && arg < arglists.size());

			# Increment the least-significant "digit" first
			while arg < arglists.size():
				indices[arg] += 1
				if indices[arg] < arglists[arg].size():
					break                               # no carry, done
				indices[arg] = 0                        # carry: reset this digit
				arg += 1                                # move to next higher digit

		return self


	# Benchmark* Benchmark::ArgName(const std::string& name) {
	# 	BM_CHECK(ArgsCnt() == -1 || ArgsCnt() == 1);
	# 	arg_names_ = {name};
	# 	return this;
	# }

	# Benchmark* Benchmark::ArgNames(const std::vector<std::string>& names) {
	# 	BM_CHECK(ArgsCnt() == -1 || ArgsCnt() == static_cast<int>(names.size()));
	# 	arg_names_ = names;
	# 	return this;
	# }

	# Benchmark* Benchmark::DenseRange(int64_t start, int64_t limit, int step) {
	# 	BM_CHECK(ArgsCnt() == -1 || ArgsCnt() == 1);
	# 	BM_CHECK_LE(start, limit);
	# 	for (int64_t arg = start; arg <= limit; arg += step) {
	# 			args_.push_back({arg});
	# 	}
	# 	return this;
	# }
	func DenseRange(start:int, limit:int, step:int) -> Benchmark:
		#BM_CHECK(ArgsCnt() == -1 || ArgsCnt() == 1);
		#BM_CHECK_LE(start, limit);
		#for (int64_t arg = start; arg <= limit; arg += step) {
				#args_.push_back({arg});
		for arg in range( start, limit, step):
			_args.push_back([arg])

		return self

	# Benchmark* Benchmark::Args(const std::vector<int64_t>& args);
	func Args(args:PackedInt64Array) -> Benchmark:
		#BM_CHECK(ArgsCnt() == -1 || ArgsCnt() == static_cast<int>(args.size()));
		assert( ArgsCnt() == -1 or ArgsCnt() == args.size() )
		_args.push_back(args);
		return self

	# Benchmark* Benchmark::Apply(
	# 			const std::function<void(Benchmark* benchmark)>& custom_arguments) {
	# 	custom_arguments(this);
	# 	return this;
	# }

	# Benchmark* Benchmark::Setup(callback_function&& setup) {
	# 	BM_CHECK(setup != nullptr);
	# 	setup_ = std::forward<callback_function>(setup);
	# 	return this;
	# }

	# Benchmark* Benchmark::Setup(const callback_function& setup) {
	# 	BM_CHECK(setup != nullptr);
	# 	setup_ = setup;
	# 	return this;
	# }

	# Benchmark* Benchmark::Teardown(callback_function&& teardown) {
	# 	BM_CHECK(teardown != nullptr);
	# 	teardown_ = std::forward<callback_function>(teardown);
	# 	return this;
	# }

	# Benchmark* Benchmark::Teardown(const callback_function& teardown) {
	# 	BM_CHECK(teardown != nullptr);
	# 	teardown_ = teardown;
	# 	return this;
	# }

	# Benchmark* Benchmark::RangeMultiplier(int multiplier);
	func RangeMultiplier(multiplier:int) -> Benchmark:
		#Check.BM_CHECK(multiplier > 1)
		assert( multiplier > 1)
		_range_multiplier = multiplier;
		return self

	# Benchmark* Benchmark::MinTime(double t) {
	# 	BM_CHECK(t > 0.0);
	# 	BM_CHECK(iterations_ == 0);
	# 	min_time_ = t;
	# 	return this;
	# }

	# Benchmark* Benchmark::MinWarmUpTime(double t) {
	# 	BM_CHECK(t >= 0.0);
	# 	BM_CHECK(iterations_ == 0);
	# 	min_warmup_time_ = t;
	# 	return this;
	# }

	# Benchmark* Benchmark::Iterations(IterationCount n) {
	# 	BM_CHECK(n > 0);
	# 	BM_CHECK(internal::IsZero(min_time_));
	# 	BM_CHECK(internal::IsZero(min_warmup_time_));
	# 	iterations_ = n;
	# 	return this;
	# }

	# Benchmark* Benchmark::Repetitions(int n) {
	# 	BM_CHECK(n > 0);
	# 	repetitions_ = n;
	# 	return this;
	# }

	# Benchmark* Benchmark::ReportAggregatesOnly(bool value) {
	# 	aggregation_report_mode_ =
	# 					value ? internal::ARM_ReportAggregatesOnly : internal::ARM_Default;
	# 	return this;
	# }

	# Benchmark* Benchmark::DisplayAggregatesOnly(bool value) {
	# 	// If we were called, the report mode is no longer 'unspecified', in any case.
	# 	using internal::AggregationReportMode;
	# 	aggregation_report_mode_ = static_cast<AggregationReportMode>(
	# 					aggregation_report_mode_ | internal::ARM_Default);
	#
	# 	if (value) {
	# 			aggregation_report_mode_ = static_cast<AggregationReportMode>(
	# 							aggregation_report_mode_ | internal::ARM_DisplayReportAggregatesOnly);
	# 	} else {
	# 			aggregation_report_mode_ = static_cast<AggregationReportMode>(
	# 							aggregation_report_mode_ & ~internal::ARM_DisplayReportAggregatesOnly);
	# 	}
	#
	# 	return this;
	# }

	# Benchmark* Benchmark::MeasureProcessCPUTime() {
	# 	// Can be used together with UseRealTime() / UseManualTime().
	# 	measure_process_cpu_time_ = true;
	# 	return this;
	# }

	# Benchmark* Benchmark::UseRealTime() {
	# 	BM_CHECK(!use_manual_time_)
	# 					<< "Cannot set UseRealTime and UseManualTime simultaneously.";
	# 	use_real_time_ = true;
	# 	return this;
	# }

	# Benchmark* Benchmark::UseManualTime() {
	# 	BM_CHECK(!use_real_time_)
	# 					<< "Cannot set UseRealTime and UseManualTime simultaneously.";
	# 	use_manual_time_ = true;
	# 	return this;
	# }

	# Benchmark* Benchmark::Complexity(BigO complexity) {
	# 	complexity_ = complexity;
	# 	return this;
	# }

	# Benchmark* Benchmark::Complexity(BigOFunc* complexity) {
	# 	complexity_lambda_ = complexity;
	# 	complexity_ = oLambda;
	# 	return this;
	# }

	# Benchmark* Benchmark::ComputeStatistics(const std::string& name,
	# 			StatisticsFunc* statistics,
	# 			StatisticUnit unit) {
	# 	statistics_.emplace_back(name, statistics, unit);
	# 	return this;
	# }
	func ComputeStatistics(
				name:String, statistics:Callable, #StatisticsFunc
				unit:Statslib.StatisticUnit = Statslib.StatisticUnit.kTime ) -> Benchmark:
		_statistics.push_back(BenchLib.Statistics.new(name, statistics, unit))
		return self

	# Benchmark* Benchmark::Threads(int t) {
	# 	BM_CHECK_GT(t, 0);
	# 	thread_counts_.push_back(t);
	# 	return this;
	# }

	# Benchmark* Benchmark::ThreadRange(int min_threads, int max_threads) {
	# 	BM_CHECK_GT(min_threads, 0);
	# 	BM_CHECK_GE(max_threads, min_threads);
	#
	# 	internal::AddRange(&thread_counts_, min_threads, max_threads, 2);
	# 	return this;
	# }

	# Benchmark* Benchmark::DenseThreadRange(int min_threads, int max_threads,
	# 																																					 int stride) {
	# 	BM_CHECK_GT(min_threads, 0);
	# 	BM_CHECK_GE(max_threads, min_threads);
	# 	BM_CHECK_GE(stride, 1);
	#
	# 	for (auto i = min_threads; i < max_threads; i += stride) {
	# 			thread_counts_.push_back(i);
	# 	}
	# 	thread_counts_.push_back(max_threads);
	# 	return this;
	# }

	# Benchmark* Benchmark::ThreadPerCpu() {
	# 	thread_counts_.push_back(CPUInfo::Get().num_cpus);
	# 	return this;
	# }

	# Benchmark* Benchmark::ThreadRunner(threadrunner_factory&& factory) {
	# 	threadrunner_ = std::move(factory);
	# 	return this;
	# }

	# void Benchmark::SetName(const std::string& name) { name_ = name; }
	func SetName(name:String) -> void: _name = name

	# const char* Benchmark::GetName() const { return name_.c_str(); }
	func GetName() -> String: return _name

	# int Benchmark::ArgsCnt() const;
	func ArgsCnt() -> int:
		if _args.is_empty():
			if _arg_names.is_empty():
				return -1
			return _arg_names.size()
		var front:PackedInt64Array = _args.front()
		return front.size()

	# const char* Benchmark::GetArgName(int arg) const {
	# 	BM_CHECK_GE(arg, 0);
	# 	size_t uarg = static_cast<size_t>(arg);
	# 	BM_CHECK_LT(uarg, arg_names_.size());
	# 	return arg_names_[uarg].c_str();
	# }

	# TimeUnit Benchmark::GetTimeUnit() const {
	# 	return use_default_time_unit_ ? GetDefaultTimeUnit() : time_unit_;
	# }

# namespace internal {

# =============================================================================//
# 																												FunctionBenchmark
# =============================================================================//

	# void FunctionBenchmark::Run(State& st) { func_(st); }

#}		// end namespace internal

# void ClearRegisteredBenchmarks() {
# 	internal::BenchmarkFamilies::GetInstance()->ClearBenchmarks();
# }

# std::vector<int64_t> CreateRange(int64_t lo, int64_t hi, int multi) {
# 	std::vector<int64_t> args;
# 	internal::AddRange(&args, lo, hi, multi);
# 	return args;
# }

# std::vector<int64_t> CreateDenseRange(int64_t start, int64_t limit, int step) {
# 	BM_CHECK_LE(start, limit);
# 	std::vector<int64_t> args;
# 	for (int64_t arg = start; arg <= limit; arg += step) {
# 		args.push_back(arg);
# 	}
# 	return args;
# }

# }		// end namespace benchmark
