@tool

const RegisterLib = preload("uid://ehhn1k7v0g6w")
const State = BenchLib.State
const Benchmark = BenchLib.Benchmark
const FunctionBenchmark = BenchLib.FunctionBenchmark
const ConsoleReporter = preload("uid://cp6jwltd8s2ur")

# new checksum, should be the same for both 2524655701620245727
# old checksum which was for the c++ version. 218812692406581874


func _init() -> void:
	BenchLib.GetInstance()._families.clear()
	BenchLib.FLAGS_benchmark_list_tests = false
	BenchLib.FLAGS_benchmark_dry_run = false
	BenchLib.kMaxIterations = 1

	bench_BM_Flatbuffers_Encode = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new(BM_Flatbuffers_Encode))
	bench_BM_Flatbuffers_Decode = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new(BM_Flatbuffers_Decode))
	bench_BM_Flatbuffers_Use = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new(BM_Flatbuffers_Use))
	bench_BM_Raw_Encode = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new(BM_Raw_Encode))
	bench_BM_Raw_Decode = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new(BM_Raw_Decode))
	bench_BM_Raw_Use = \
		RegisterLib.RegisterBenchmarkInternal(
			FunctionBenchmark.new(BM_Raw_Use))



func _run() -> void:
	var reporter := ConsoleReporter.new()

	var num_benchmarks:int = BenchLib.RunSpecifiedBenchmarks(reporter)
	if num_benchmarks == 0:
		push_error("zero benchmarks")
	else:
		print("%d benchmarks" % num_benchmarks)


static func Encode( state:State, bench:BenchCase, _buffer:PackedByteArray ) -> void:
	for i in state:
		var _buf:PackedByteArray = bench.Encode();



static func Decode( state:State, bench:BenchCase, _buffer:PackedByteArray) -> void:
	# int64_t length;
	# uint8_t* encoded = bench->Encode(buffer, length);
	var encoded:PackedByteArray = bench.Encode()
	# for (auto _ : state) {
	for i:int in state:
	# 	void* decoded = bench->Decode(encoded, length);
		var _decoded:Variant = bench.Decode(encoded)


static func Use( state:State, bench:BenchCase, _buffer:PackedByteArray, _check_sum:int ) -> void:
	var encoded:PackedByteArray = bench.Encode();
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

	var bench:BenchCase = FlatBuffersBench.new();
	Encode(state, bench, buffer);

static var bench_BM_Flatbuffers_Encode:Benchmark



static func BM_Flatbuffers_Decode(state:State) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchCase = FlatBuffersBench.new()
	Decode(state, bench, buffer)

static var bench_BM_Flatbuffers_Decode:Benchmark



static func BM_Flatbuffers_Use(state:State) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchCase = FlatBuffersBench.new()
	Use(state, bench, buffer, 2524655701620245727);

static var bench_BM_Flatbuffers_Use:Benchmark




static func BM_Raw_Encode(state:State) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchCase = BuiltInBench.new()
	Encode(state, bench, buffer);

static var bench_BM_Raw_Encode:Benchmark


static func BM_Raw_Decode(state:State) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchCase = BuiltInBench.new()
	Decode(state, bench, buffer);


static var bench_BM_Raw_Decode:Benchmark


static func BM_Raw_Use(state:State) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchCase = BuiltInBench.new()
	Use(state, bench, buffer, 2524655701620245727)

static var bench_BM_Raw_Use:Benchmark
