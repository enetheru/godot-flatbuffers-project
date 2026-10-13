@tool
#extends EditorScript

const RegisterLib = preload("uid://ehhn1k7v0g6w")
const Benchmark = RegisterLib.Benchmark
const FunctionBenchmark = RegisterLib.FunctionBenchmark
const ConsoleReporter = preload("uid://cp6jwltd8s2ur")

const CntFlags = Counter.Flags
const CntOneK = Counter.OneK

const FB = preload("fb_scripts/bench_generated.gd")
const CaseGdDict = preload("uid://dve0r6lgn2kft")

func _init() -> void:
	RegisterLib.ClearRegisteredBenchmarks()
	BenchLib.FLAGS_benchmark_list_tests = false
	BenchLib.FLAGS_benchmark_dry_run = false
	BenchLib.kMaxIterations = 100

	# Standard Encode
	var _bm := RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_Encode)) \
		.AddRanges([1,2],[3,4])


func _run() -> void:
	var reporter := ConsoleReporter.new()
	var benchmarks:int = BenchLib.RunSpecifiedBenchmarks(reporter)
	print("Processed %d benchmarks" % benchmarks)


# --- Encode ---
static func GenericEncode(state:State, bench:BenchCase) -> void:
	state.counters["bytes_size"] = Counter.new(
			bench.Encode().size(), CntFlags.kIsIterationInvariant, CntOneK.kIs1024)

	var throughput := Counter.new(0, CntFlags.kIsRate, CntOneK.kIs1024)
	state.counters["bytes/s"] = throughput

	for i in state:
		var buf:PackedByteArray = bench.Encode()
		throughput.value += buf.size()


static func BM_Flatbuffers_Encode(state:State) -> void:
	GenericEncode(state,
		FlatBuffersBench.new({
			&'kPreAllocateSize':state.get_range(0)
		}))
