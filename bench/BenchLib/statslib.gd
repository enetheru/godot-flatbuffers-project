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

#ifndef BENCHMARK_STATISTICS_H_
#define BENCHMARK_STATISTICS_H_

#include <string>
#include <vector>

#include "benchmark/types.h"

#namespace benchmark {

# BigO is passed to a benchmark in order to specify the asymptotic
# computational
# complexity for the benchmark. In case oAuto is selected, complexity will be
# calculated automatically to the best fit.
enum BigO { oNone, o1, oN, oNSquared, oNCubed, oLogN, oNLogN, oAuto, oLambda }

#typedef int64_t ComplexityN;

enum StatisticUnit { kTime, kPercentage }

#typedef double(BigOFunc)(ComplexityN);

#typedef double(StatisticsFunc)(const std::vector<double>&);

#namespace internal {
#struct Statistics {
class Statistics:
	#  std::string name_;
	var _name:String
	#  StatisticsFunc* compute_;
	var _compute:Callable
	#  StatisticUnit unit_;
	var _unit:StatisticUnit

	#  Statistics(const std::string& name, StatisticsFunc* compute,
	#             StatisticUnit unit = kTime)
	#      : name_(name), compute_(compute), unit_(unit) {}
	func _init(name:String, compute:Callable,
				unit:StatisticUnit = StatisticUnit.kTime) -> void:
		_name = name; _compute = compute; _unit = unit
#};


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

#}  // namespace internal
#}  // namespace benchmark
#endif  // BENCHMARK_STATISTICS_H_



const Counter = BenchLib.Counter

#typedef double(StatisticsFunc)(const std::vector<double>&);
#const StatisticsFunc = Callable # FIXME, cannot be done

# const auto StatisticsSum = [](const std::vector<double>& v) {
#	return std::accumulate(v.begin(), v.end(), 0.0);
# };
static func StatisticsSum(v:Array[float]) -> float:
	return v.reduce(func(x:float,a:float=0)->float:return a+x)


# double StatisticsMean(const std::vector<double>& v) {
#	if (v.empty()) {
#		return 0.0;
#	}
#	return StatisticsSum(v) * (1.0 / static_cast<double>(v.size()));
# }
static func StatisticsMean(v:Array[float]) -> float:
	if v.is_empty(): return 0.0;
	return StatisticsSum(v) * (1.0 / v.size());



# double StatisticsMedian(const std::vector<double>& v) {
#	if (v.size() < 3) {
#		return StatisticsMean(v);
#	}
#	std::vector<double> copy(v);
#
#	auto center = copy.begin() + v.size() / 2;
#	std::nth_element(copy.begin(), center, copy.end());
#
#	// Did we have an odd number of samples?	If yes, then center is the median.
#	// If not, then we are looking for the average between center and the value
#	// before.	Instead of resorting, we just look for the max value before it,
#	// which is not necessarily the element immediately preceding `center` Since
#	// `copy` is only partially sorted by `nth_element`.
#	if (v.size() % 2 == 1) {
#		return *center;
#	}
#	auto center2 = std::max_element(copy.begin(), center);
#	return (*center + *center2) / 2.0;
# }
static func StatisticsMedian(v:Array[float]) -> float:
	if v.size() < 3: return StatisticsMean(v);

	var copy:Array[float] = v.duplicate(true)
	copy.sort()

	var center_idx:int = int(copy.size() / 2.0) # iterator for the centre.

	# Did we have an odd number of samples?	If yes, then center is the median.
	# If not, then we are looking for the average between center and the value
	# before.	Instead of re-sorting, we just look for the max value before it,
	# which is not necessarily the element immediately preceding `center` Since
	# `copy` is only partially sorted by `nth_element`.
	if copy.size() % 2 == 1: return copy[center_idx]
	return (copy[center_idx] + copy[center_idx+1]) / 2.0;


# // Return the sum of the squares of this sample set
# const auto SumSquares = [](const std::vector<double>& v) {
#	return std::inner_product(v.begin(), v.end(), v.begin(), 0.0);
# };
static func SumSquares(v:Array[float]) -> float:
	return v.reduce(func(x:float,a:float = 0)->float: return a + x*x)

# const auto Sqr = [](const double dat) { return dat * dat; };
static func Sqr(dat:float) -> float: return dat * dat

# const auto Sqrt = [](const double dat) {
#	// Avoid NaN due to imprecision in the calculations
#	if (dat < 0.0) {
#		return 0.0;
#	}
#	return std::sqrt(dat);
# };
static func Sqrt(dat:float) -> float:
	# Avoid NaN due to imprecision in the calculations
	if dat < 0.0: return 0.0
	return sqrt(dat);


# double StatisticsStdDev(const std::vector<double>& v) {
#	const auto mean = StatisticsMean(v);
#	if (v.empty()) {
#		return mean;
#	}
#
#	// Sample standard deviation is undefined for n = 1
#	if (v.size() == 1) {
#		return 0.0;
#	}
#
#	const double avg_squares =
#			SumSquares(v) * (1.0 / static_cast<double>(v.size()));
#	return Sqrt(static_cast<double>(v.size()) /
#					(static_cast<double>(v.size()) - 1.0) *
#					(avg_squares - Sqr(mean)));
# }
static func StatisticsStdDev(v:Array[float]) -> float:
	var mean:float = StatisticsMean(v);
	if v.is_empty(): return mean

	# Sample standard deviation is undefined for n = 1
	if v.size() == 1:
		return 0.0

	var avg_squares:float = SumSquares(v) * (1.0 / v.size())
	return Sqrt(v.size() / (v.size() - 1.0) * (avg_squares - Sqr(mean)))


# double StatisticsCV(const std::vector<double>& v) {
#	if (v.size() < 2) {
#		return 0.0;
#	}
#
#	const auto stddev = StatisticsStdDev(v);
#	const auto mean = StatisticsMean(v);
#
#	if (std::fpclassify(mean) == FP_ZERO) {
#		return 0.0;
#	}
#
#	return stddev / mean;
# }
static func StatisticsCV(v:Array[float]) -> float:
	if v.size() < 2: return 0.0

	var stddev:float = StatisticsStdDev(v)
	var mean:float = StatisticsMean(v)

	#if std::fpclassify(mean) == FP_ZERO): return 0.0
	if is_zero_approx(mean): return 0.0

	return stddev / mean


# std::vector<BenchmarkReporter::Run> ComputeStats(
#		const std::vector<BenchmarkReporter::Run>& reports) {
#	typedef BenchmarkReporter::Run Run;
#	std::vector<Run> results;
#
#	auto error_count = std::count_if(reports.begin(), reports.end(),
#										 [](Run const& run) { return run.skipped; });
#
#	if (reports.size() - static_cast<size_t>(error_count) < 2) {
#		// We don't report aggregated data if there was a single run.
#		return results;
#	}
#
#	// Accumulators.
#	std::vector<double> real_accumulated_time_stat;
#	std::vector<double> cpu_accumulated_time_stat;
#
#	real_accumulated_time_stat.reserve(reports.size());
#	cpu_accumulated_time_stat.reserve(reports.size());
#
#	// All repetitions should be run with the same number of iterations so we
#	// can take this information from the first benchmark.
#	const IterationCount run_iterations = reports.front().iterations;
#	// create stats for user counters
#	struct CounterStat {
#		Counter c;
#		std::vector<double> s;
#	};
#	std::map<std::string, CounterStat> counter_stats;
#	for (Run const& r : reports) {
#		for (auto const& cnt : r.counters) {
#			auto it = counter_stats.find(cnt.first);
#			if (it == counter_stats.end()) {
#				it = counter_stats
#								 .emplace(cnt.first,
#													CounterStat{cnt.second, std::vector<double>{}})
#								 .first;
#				it->second.s.reserve(reports.size());
#			} else {
#				BM_CHECK_EQ(it->second.c.flags, cnt.second.flags);
#			}
#		}
#	}
#
#	// Populate the accumulators.
#	for (Run const& run : reports) {
#		BM_CHECK_EQ(reports[0].benchmark_name(), run.benchmark_name());
#		BM_CHECK_EQ(run_iterations, run.iterations);
#		if (run.skipped != 0u) {
#			continue;
#		}
#		real_accumulated_time_stat.emplace_back(run.real_accumulated_time);
#		cpu_accumulated_time_stat.emplace_back(run.cpu_accumulated_time);
#		// user counters
#		for (auto const& cnt : run.counters) {
#			auto it = counter_stats.find(cnt.first);
#			BM_CHECK_NE(it, counter_stats.end());
#			it->second.s.emplace_back(cnt.second);
#		}
#	}
#
#	// Only add label if it is same for all runs
#	std::string report_label = reports[0].report_label;
#	for (std::size_t i = 1; i < reports.size(); i++) {
#		if (reports[i].report_label != report_label) {
#			report_label = "";
#			break;
#		}
#	}
#
#	const double iteration_rescale_factor =
#			static_cast<double>(reports.size()) / static_cast<double>(run_iterations);
#
#	for (const auto& Stat : *reports[0].statistics) {
#		// Get the data from the accumulator to BenchmarkReporter::Run's.
#		Run data;
#		data.run_name = reports[0].run_name;
#		data.family_index = reports[0].family_index;
#		data.per_family_instance_index = reports[0].per_family_instance_index;
#		data.run_type = BenchmarkReporter::Run::RT_Aggregate;
#		data.threads = reports[0].threads;
#		data.repetitions = reports[0].repetitions;
#		data.repetition_index = Run::no_repetition_index;
#		data.aggregate_name = Stat.name_;
#		data.aggregate_unit = Stat.unit_;
#		data.report_label = report_label;
#
#		// It is incorrect to say that an aggregate is computed over
#		// run's iterations, because those iterations already got averaged.
#		// Similarly, if there are N repetitions with 1 iterations each,
#		// an aggregate will be computed over N measurements, not 1.
#		// Thus it is best to simply use the count of separate reports.
#		data.iterations = static_cast<IterationCount>(reports.size());
#
#		data.real_accumulated_time = Stat.compute_(real_accumulated_time_stat);
#		data.cpu_accumulated_time = Stat.compute_(cpu_accumulated_time_stat);
#
#		if (data.aggregate_unit == StatisticUnit::kTime) {
#			// We will divide these times by data.iterations when reporting, but the
#			// data.iterations is not necessarily the scale of these measurements,
#			// because in each repetition, these timers are sum over all the iters.
#			// And if we want to say that the stats are over N repetitions and not
#			// M iterations, we need to multiply these by (N/M).
#			data.real_accumulated_time *= iteration_rescale_factor;
#			data.cpu_accumulated_time *= iteration_rescale_factor;
#		}
#
#		data.time_unit = reports[0].time_unit;
#
#		// user counters
#		for (auto const& kv : counter_stats) {
#			// Do *NOT* rescale the custom counters. They are already properly scaled.
#			const auto uc_stat = Stat.compute_(kv.second.s);
#			auto c = Counter(uc_stat, counter_stats[kv.first].c.flags,
#											 counter_stats[kv.first].c.oneK);
#			data.counters[kv.first] = c;
#		}
#
#		results.push_back(data);
#	}
#
#	return results;
# }

# create stats for user counters
class CounterStat:
	var c:Counter
	var s:Array[float]
	func _init(c_:Counter, s_:Array[float]) -> void: c=c_; s=s_


static func ComputeStats(reports:Array[BenchmarkReporter.Run]) -> Array[BenchmarkReporter.Run]:
	const Run = BenchmarkReporter.Run
	var results:Array[Run]

	var error_count:int = 0
	for report:Run in reports:
		if report.skipped: error_count += 1

	if (reports.size() - error_count) < 2:
		# We don't report aggregated data if there was a single run.
		return results;

	# Accumulators.
	var real_accumulated_time_stat:Array[float]
	var cpu_accumulated_time_stat:Array[float]

	if real_accumulated_time_stat.resize(reports.size()) != OK:
		push_error("Failed to reserve space for real_accumulated_time_stat")
		return []

	if cpu_accumulated_time_stat.resize(reports.size()) != OK:
		push_error("Failed to reserve space for cpu_accumulated_time_stat")
		return []

	# All repetitions should be run with the same number of iterations so we
	# can take this information from the first benchmark.
	var run_iterations:int = reports.front().iterations

	# create stats for user counters
	var counter_stats:Dictionary[String,CounterStat]
	for r:Run in reports:
		for cnt:String in r.counters.keys():
			var val:Counter = r.counters.get(cnt)
			var cntst:CounterStat = counter_stats.get(cnt)
			if cntst == null:
				cntst = CounterStat.new(val, [])
				counter_stats[cnt] = cntst
				if cntst.s.resize(reports.size())  != OK:
					push_error("failed to reserve space for counter_stat.s")
					return []
			else:
				assert(cntst.c.flags == val.flags)

	# Populate the accumulators.
	for run:Run in reports:
		#STUB BM_CHECK_EQ(reports[0].benchmark_name(), run.benchmark_name());
		#STUB BM_CHECK_EQ(run_iterations, run.iterations);
		if run.skipped != 0: continue;

		# FIXME, because we reserved space before I dont know if godot will
		# put the data in the correct location
		real_accumulated_time_stat.push_back(run.real_accumulated_time);
		cpu_accumulated_time_stat.push_back(run.cpu_accumulated_time);
		# user counters
		for cnt_key:String in run.counters.keys():
			var cnt:Counter = run.counters.get(cnt_key)
			# STUB BM_CHECK_NE(it, counter_stats.end())
			var cntst:CounterStat = counter_stats.get(cnt_key)
			cntst.s.push_back(cnt)


	# Only add label if it is same for all runs
	var report_label:String = reports[0].report_label
	for i:int in reports.size():
		if reports[i].report_label != report_label:
			report_label = ""
			break

	var iteration_rescale_factor:float = reports.size() / float(run_iterations)

	for Stat in reports[0].statistics:
		# Get the data from the accumulator to BenchmarkReporter::Run's.
		var data := Run.new()
		data.run_name = reports[0].run_name;
		data.family_index = reports[0].family_index;
		data.per_family_instance_index = reports[0].per_family_instance_index;
		data.run_type = Run.RunType.RT_Aggregate
		data.threads = reports[0].threads;
		data.repetitions = reports[0].repetitions;
		data.repetition_index = Run.no_repetition_index;
		data.aggregate_name = Stat._name;
		data.aggregate_unit = Stat._unit;
		data.report_label = report_label;

		# It is incorrect to say that an aggregate is computed over
		# run's iterations, because those iterations already got averaged.
		# Similarly, if there are N repetitions with 1 iterations each,
		# an aggregate will be computed over N measurements, not 1.
		# Thus it is best to simply use the count of separate reports.
		data.iterations = reports.size()

		data.real_accumulated_time = Stat._compute.call(real_accumulated_time_stat)
		data.cpu_accumulated_time = Stat._compute.call(cpu_accumulated_time_stat)

		if data.aggregate_unit == StatisticUnit.kTime:
			# We will divide these times by data.iterations when reporting, but the
			# data.iterations is not necessarily the scale of these measurements,
			# because in each repetition, these timers are sum over all the iters.
			# And if we want to say that the stats are over N repetitions and not
			# M iterations, we need to multiply these by (N/M).
			data.real_accumulated_time *= iteration_rescale_factor;
			data.cpu_accumulated_time *= iteration_rescale_factor;

		data.time_unit = reports[0].time_unit;

		# user counters
		for kv:String in counter_stats:
			var cntst:CounterStat = counter_stats.get(kv)
			# Do *NOT* rescale the custom counters. They are already properly scaled.
			var uc_stat:float = Stat._compute.call(cntst.s)
			var c := Counter.new(uc_stat, cntst.c.flags, cntst.c.one_k)
			data.counters[kv] = c

		results.push_back(data);

	return results;
