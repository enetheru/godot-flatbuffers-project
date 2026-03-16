@tool

const RegisterLib = preload("uid://ehhn1k7v0g6w")
const State = BenchLib.State
const Benchmark = BenchLib.Benchmark
const FunctionBenchmark = BenchLib.FunctionBenchmark
const ConsoleReporter = preload("uid://cp6jwltd8s2ur")

const RB = preload("uid://ceg4ivov3pobi")

# new checksum, should be the same for both 2524655701620245727
# old checksum which was for the c++ version. 218812692406581874


func _init() -> void:
	BenchLib.BenchmarkFamilies.GetInstance()._families.clear()
	BenchLib.FLAGS_benchmark_list_tests = false
	BenchLib.FLAGS_benchmark_dry_run = false
	BenchLib.kMaxIterations = 1

	bench_BM_Flatbuffers_Encode = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new("BM_Flatbuffers_Encode", BM_Flatbuffers_Encode))
	bench_BM_Flatbuffers_Decode = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new("BM_Flatbuffers_Decode", BM_Flatbuffers_Decode))
	bench_BM_Flatbuffers_Use = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new("BM_Flatbuffers_Use", BM_Flatbuffers_Use))
	bench_BM_Raw_Encode = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new("BM_Raw_Encode", BM_Raw_Encode))
	bench_BM_Raw_Decode = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new("BM_Raw_Decode", BM_Raw_Decode))
	bench_BM_Raw_Use = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new("BM_Raw_Use", BM_Raw_Use))



func _run() -> void:
	var reporter := ConsoleReporter.new()

	var num_benchmarks:int = BenchLib.RunSpecifiedBenchmarks(reporter)
	if num_benchmarks == 0:
		push_error("zero benchmarks")
	else:
		print("%d benchmarks" % num_benchmarks)


static func Encode( state:State, bench:BenchBase, buffer:PackedByteArray ) -> void:
	for i in state:
		var _buf:PackedByteArray = bench.Encode(buffer);



static func Decode( state:State, bench:BenchBase, buffer:PackedByteArray) -> void:
	# int64_t length;
	# uint8_t* encoded = bench->Encode(buffer, length);
	var encoded:PackedByteArray = bench.Encode(buffer)
	# for (auto _ : state) {
	for i:int in state:
	# 	void* decoded = bench->Decode(encoded, length);
		var _decoded:Variant = bench.Decode(encoded)


static func Use( state:State, bench:BenchBase, buffer:PackedByteArray, _check_sum:int ) -> void:
	var encoded:PackedByteArray = bench.Encode(buffer);
	var decoded:Variant = bench.Decode(encoded)
	var sum:int = 0
	for i:int in state:
		sum = bench.Use(decoded)

	if sum: pass # shut up the warning about unused variable.
	##if sum != check_sum:
		##state.SkipWithError("Checksum did not match: %s != %s" % [check_sum, sum])
		##state.


static func BM_Flatbuffers_Encode(state:State) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchBase = FlatBuffersBench.new(kBufferLength);
	Encode(state, bench, buffer);

static var bench_BM_Flatbuffers_Encode:Benchmark



static func BM_Flatbuffers_Decode(state:State) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchBase = FlatBuffersBench.new(kBufferLength)
	Decode(state, bench, buffer)

static var bench_BM_Flatbuffers_Decode:Benchmark



static func BM_Flatbuffers_Use(state:State) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchBase = FlatBuffersBench.new(kBufferLength)
	Use(state, bench, buffer, 2524655701620245727);

static var bench_BM_Flatbuffers_Use:Benchmark




static func BM_Raw_Encode(state:State) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchBase = RB.NewRawBench()
	Encode(state, bench, buffer);

static var bench_BM_Raw_Encode:Benchmark


static func BM_Raw_Decode(state:State) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchBase = RB.NewRawBench()
	Decode(state, bench, buffer);


static var bench_BM_Raw_Decode:Benchmark


static func BM_Raw_Use(state:State) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchBase = RB.NewRawBench()
	Use(state, bench, buffer, 2524655701620245727)

static var bench_BM_Raw_Use:Benchmark
