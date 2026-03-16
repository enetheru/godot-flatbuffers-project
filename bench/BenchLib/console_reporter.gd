@tool
extends BenchmarkReporter

# Simple reporter that outputs benchmark data to the console. This is the
# default reporter used by RunSpecifiedBenchmarks().

const State = BenchLib.State
const Benchmark = BenchLib.Benchmark
const FunctionBenchmark = BenchLib.FunctionBenchmark


enum OutputOptions {
	OO_None = 0,
	OO_Color = 1,
	OO_Tabular = 2,
	OO_ColorTabular = OO_Color | OO_Tabular,
	OO_Defaults = OO_ColorTabular
}

var _output_options:int
var _name_field_width:int
var _prev_counters:Dictionary
var _printed_header:bool


func _init( _opts:OutputOptions = OutputOptions.OO_Defaults) -> void:
	_output_options = _opts
	_name_field_width = 0
	_printed_header = false


static func FormatTime(time:float) -> String:
	# For the time columns of the console printer 13 digits are reserved. One of
	# them is a space and max two of them are the time unit (e.g ns). That puts
	# us at 10 digits usable for the number.
	# Align decimal places...
	if time < 1.0:
		return "%10.3f" % time
	if time < 10.0:
		return "%10.2f" % time
	if time < 100.0:
		return "%10.1f" % time
	# Assuming the time is at max 9.9999e+99 and we have 10 digits for the
	# number, we get 10-1(.)-1(e)-1(sign)-2(exponent) = 5 digits to print.
	if time > 9999999999: # max 10 digit number
		return "%1.4e" % time
	return "%10.0f" % time


# Function to return an string for the calculated complexity
func GetBigOString(complexity:BenchLib.BigO) -> String:
	match complexity:
		BenchLib.BigO.oN: return "N"
		BenchLib.BigO.oNSquared: return "N^2"
		BenchLib.BigO.oNCubed: return "N^3"
		BenchLib.BigO.oLogN: return "lgN"
		BenchLib.BigO.oNLogN: return "NlgN"
		BenchLib.BigO.o1: return "(1)"
		_: return "f(N)"


func GetTimeUnitString(unit:BenchLib.TimeUnit) -> String:
	match unit:
		BenchLib.TimeUnit.kSecond: return "s";
		BenchLib.TimeUnit.kMillisecond: return "ms";
		BenchLib.TimeUnit.kMicrosecond: return "us";
		BenchLib.TimeUnit.kNanosecond: return "ns";
		_: return ""


func ReportContext(context:Context) -> bool:
	_name_field_width = context.name_field_width
	_printed_header = false
	_prev_counters.clear();
	PrintBasicContext(context)
	return true;


func ReportRuns(reports:Array[Run]) -> void:
	for run in reports:
		# print the header:
		# --- if none was printed yet
		var print_header:bool =	not _printed_header
		# --- or if the format is tabular and this run
		#		 has different fields from the prev header
		print_header = print_header or ((_output_options & OutputOptions.OO_Tabular) != 0) and \
						(run.counters.keys() != _prev_counters.keys())
		if print_header:
			_printed_header = true
			_prev_counters = run.counters;
			PrintHeader(run);

		# As an alternative to printing the headers like this, we could sort
		# the benchmarks by header and then print. But this would require
		# waiting for the full results before printing, or printing twice.
		PrintRunData(run);


func PrintRunData(result:Run) -> void:
	var parts:Array[String] = []
	var name_color:Color
	if result.report_big_o or result.report_rms:
		name_color = Color.BLUE
	else: name_color = Color.GREEN
	var error_color:String = Color.RED.to_html()
	var skipped_color:String = Color.WHITE.to_html()
	var yellow_color:String = Color.YELLOW.to_html()
	var cyan_color:String = Color.CYAN.to_html()

	parts.append("[color=%s]%s [/color]" % [
		name_color.to_html(true),
		result.benchmark_name().rpad(_name_field_width)])

	if BenchLib.Skipped.SkippedWithError == result.skipped:
		parts.append("[color=%s]ERROR OCCURRED: '%s'[/color]" % [
				error_color, result.skip_message])
		print_rich(''.join(parts))
		return

	if BenchLib.Skipped.SkippedWithMessage == result.skipped:
		parts.append("[color=%s]SKIPPED: '%s'[/color]" % [
				skipped_color, result.skip_message])
		print_rich(''.join(parts))
		return

	var real_time:float = result.GetAdjustedRealTime()
	var cpu_time:float = result.GetAdjustedCPUTime()
	var real_time_str:String = FormatTime(real_time)
	var cpu_time_str:String = FormatTime(cpu_time)

	if result.report_big_o:
		var big_o:String = GetBigOString(result.complexity);
		#printer( Color.YELLOW, "%10.2f %-4s %10.2f %-4s ", real_time,
				#big_o, cpu_time, big_o);
		parts.append("[color=%s]%10.2f %-4s %10.2f %-4s [/color]" % [
				yellow_color, real_time, big_o, cpu_time, big_o])
	elif result.report_rms:
		#printer( Color.YELLOW, "%10.0f %-4s %10.0f %-4s ", real_time * 100, "%",
				#cpu_time * 100, "%");
		parts.append("[color=%s]%10.0f %-4s %10.0f %-4s [/color]" % [
				yellow_color, real_time * 100, "%", cpu_time * 100, "%"])
	elif result.run_type != Run.RunType.RT_Aggregate or \
			 result.aggregate_unit == StatisticUnit.kTime:
		var timeLabel:String = GetTimeUnitString(result.time_unit)
		#printer( Color.YELLOW, "%s %-4s %s %-4s ", real_time_str,
				#timeLabel, cpu_time_str, timeLabel);
		parts.append("[color=%s]%s %-4s %s %-4s [/color]" % [
				yellow_color, real_time_str, timeLabel, cpu_time_str, timeLabel])
	else:
		assert(result.aggregate_unit == StatisticUnit.kPercentage)
		#printer( Color.YELLOW, "%10.2f %-4s %10.2f %-4s ",
				#(100. * result.real_accumulated_time), "%",
				#(100. * result.cpu_accumulated_time), "%")
		parts.append("[color=%s]%10.2f %-4s %10.2f %-4s [/color]" % [
				yellow_color,
				(100. * result.real_accumulated_time), "%",
				(100. * result.cpu_accumulated_time), "%"])

	if not result.report_big_o and not result.report_rms:
		parts.append("[color=%s]%10d[/color]" % [cyan_color, result.iterations])

	for ckey:String in result.counters.keys():
		var cnt:Counter = result.counters.get(ckey)
		var cNameLen:int = max(10, ckey.length())
		var s:String;
		var unit:String = "";
		if result.run_type == Run.RunType.RT_Aggregate \
		and result.aggregate_unit == StatisticUnit.kPercentage:
				s = "%.2f" % [100.0 * cnt.value]
				unit = "%"
		else:
			# FIXME, this is suposed to be time, not size
			s = String.humanize_size(int(cnt.value))

		if (cnt.flags & BenchLib.Counter.Flags.kIsRate) != 0:
			unit = "s" if (cnt.flags & BenchLib.Counter.Flags.kInvert) != 0 else "/s"

		if (_output_options & OutputOptions.OO_Tabular) != 0:
			parts.append((" %s%s" % [s, unit]).lpad(cNameLen - unit.length()))
		else:
			parts.append(" %s=%s%s" % [ckey, s, unit])

	if not result.report_label.is_empty():
		parts.append(" "+result.report_label)

	print_rich(''.join(parts))


func PrintHeader(run:Run) -> void:
	var header:String = "%s %s %s %s" % [
		"Benchmark".rpad(_name_field_width),
		"Time".lpad(13), "CPU".lpad(15), "Iterations".lpad(12)]
	if not run.counters.is_empty():
		if (_output_options & OutputOptions.OO_Tabular) != 0:
			for ckey:String in run.counters.keys():
				header += " %s" % str(ckey)
		else:
			header += " UserCounters..."

	var line:String = '-'.repeat(header.length())
	print('\n'.join([line,header,line]))
