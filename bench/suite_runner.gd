@tool

const RegisterLib = preload("uid://ehhn1k7v0g6w")
const State = BenchLib.State
const Benchmark = BenchLib.Benchmark
const FunctionBenchmark = BenchLib.FunctionBenchmark
const ConsoleReporter = preload("uid://cp6jwltd8s2ur")

const RB = preload("uid://ceg4ivov3pobi")
const FB = preload("bench_generated.gd")

func _init() -> void:
	BenchLib.BenchmarkFamilies.GetInstance()._families.clear()
	BenchLib.FLAGS_benchmark_list_tests = false
	BenchLib.FLAGS_benchmark_dry_run = false
	BenchLib.kMaxIterations = 1

	# Standard Encode
	@warning_ignore_start("return_value_discarded")
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Flatbuffers_Encode", BM_Flatbuffers_Encode))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Raw_Encode", BM_Raw_Encode))

	# Scaling Encode (Example: 64 elements)
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Flatbuffers_Encode_64", BM_Flatbuffers_Encode_64))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Raw_Encode_64", BM_Raw_Encode_64))

	# Decode / OpenView
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Flatbuffers_OpenView", BM_Flatbuffers_OpenView))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Raw_Deserialize", BM_Raw_Deserialize))

	# ReadAll (Aligned Use)
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Flatbuffers_ReadAll", BM_Flatbuffers_ReadAll))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Raw_ReadAll", BM_Raw_ReadAll))

	# Scaling ReadAll (Example: 64 elements)
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Flatbuffers_ReadAll_64", BM_Flatbuffers_ReadAll_64))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Raw_ReadAll_64", BM_Raw_ReadAll_64))

	# RoundTrip
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Flatbuffers_RoundTrip", BM_Flatbuffers_RoundTrip))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Raw_RoundTrip", BM_Raw_RoundTrip))

	# Access-pattern focused
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Flatbuffers_MetadataOnly", BM_Flatbuffers_MetadataOnly))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Raw_MetadataOnly", BM_Raw_MetadataOnly))

	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Flatbuffers_RandomElement", BM_Flatbuffers_RandomElement))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new("BM_Raw_RandomElement", BM_Raw_RandomElement))
	@warning_ignore_restore("return_value_discarded")


func _run() -> void:
	var reporter := ConsoleReporter.new()
	var num_benchmarks:int = BenchLib.RunSpecifiedBenchmarks(reporter)
	if num_benchmarks == 0:
		push_error("zero benchmarks")
	else:
		print("%d benchmarks" % num_benchmarks)


# --- Helper Methods ---

static func Encode(state:State, bench:BenchBase, buffer:PackedByteArray) -> void:
	for i in state:
		var _buf:PackedByteArray = bench.Encode(buffer)

static func Decode(state:State, bench:BenchBase, buffer:PackedByteArray) -> void:
	var encoded:PackedByteArray = bench.Encode(buffer)
	for i:int in state:
		var _decoded:Variant = bench.Decode(encoded)

static func Use(state:State, bench:BenchBase, buffer:PackedByteArray) -> void:
	var encoded:PackedByteArray = bench.Encode(buffer)
	var decoded:Variant = bench.Decode(encoded)
	var sum:int = 0
	for i:int in state:
		sum = bench.Use(decoded)
	if sum: pass

static func RoundTrip(state:State, bench:BenchBase, buffer:PackedByteArray) -> void:
	for i in state:
		var encoded:PackedByteArray = bench.Encode(buffer)
		var decoded:Variant = bench.Decode(encoded)
		var sum:int = bench.Use(decoded)
		if sum: pass

# --- Benchmark Implementations ---

static func BM_Flatbuffers_Encode(state:State) -> void:
	var bench:BenchBase = FlatBuffersBench.new(1024)
	Encode(state, bench, [])

static func BM_Raw_Encode(state:State) -> void:
	var bench:BenchBase = RB.NewRawBench()
	Encode(state, bench, [])

static func BM_Flatbuffers_OpenView(state:State) -> void:
	var bench:BenchBase = FlatBuffersBench.new(1024)
	Decode(state, bench, [])

static func BM_Raw_Deserialize(state:State) -> void:
	var bench:BenchBase = RB.NewRawBench()
	Decode(state, bench, [])

static func BM_Flatbuffers_ReadAll(state:State) -> void:
	var bench:BenchBase = FlatBuffersBench.new(1024)
	Use(state, bench, [])

static func BM_Raw_ReadAll(state:State) -> void:
	var bench:BenchBase = RB.NewRawBench()
	Use(state, bench, [])

static func BM_Flatbuffers_RoundTrip(state:State) -> void:
	var bench:BenchBase = FlatBuffersBench.new(1024)
	RoundTrip(state, bench, [])

static func BM_Raw_RoundTrip(state:State) -> void:
	var bench:BenchBase = RB.NewRawBench()
	RoundTrip(state, bench, [])

static func BM_Flatbuffers_Encode_64(state:State) -> void:
	var bench:BenchBase = FlatBuffersBench.new(4096, 64)
	Encode(state, bench, [])

static func BM_Raw_Encode_64(state:State) -> void:
	var bench:BenchBase = RB.NewRawBench(64)
	Encode(state, bench, [])

static func BM_Flatbuffers_ReadAll_64(state:State) -> void:
	var bench:BenchBase = FlatBuffersBench.new(4096, 64)
	Use(state, bench, [])

static func BM_Raw_ReadAll_64(state:State) -> void:
	var bench:BenchBase = RB.NewRawBench(64)
	Use(state, bench, [])

# --- Specialized Access ---

static func BM_Flatbuffers_MetadataOnly(state:State) -> void:
	var bench:BenchBase = FlatBuffersBench.new(1024)
	var encoded:PackedByteArray = bench.Encode([])

	for i in state:
		var foobarcontainer:FB.FBFooBarContainer = FB.get_FBFooBarContainer(encoded)
		var _initialised:bool = foobarcontainer.initialized()
		var _fruit:FB.Enum = foobarcontainer.fruit()
		var _loc_len:int = foobarcontainer.location().length()

static func BM_Raw_MetadataOnly(state:State) -> void:
	var bench:BenchBase = RB.NewRawBench()
	var encoded:PackedByteArray = bench.Encode([])
	for i in state:
		var foobarcontainer:FooBarContainer = bytes_to_var_with_objects(encoded)
		var _initialised:bool = foobarcontainer.initialized
		var _fruit:FooBarContainer.Enum = foobarcontainer.fruit
		var _loc_len:int = foobarcontainer.location.length()

static func BM_Flatbuffers_RandomElement(state:State) -> void:
	var bench:BenchBase = FlatBuffersBench.new(1024)
	var encoded:PackedByteArray = bench.Encode([])
	for i in state:
		var foobarcontainer:FB.FBFooBarContainer = FB.get_FBFooBarContainer(encoded)
		var list_size:int = foobarcontainer.list_size()
		if list_size > 0:
			var foobar:FB.FBFooBar = foobarcontainer.list_at(int(list_size / 2.0))
			var _rating:float = foobar.rating()
			var _postfix:int = foobar.postfix()

static func BM_Raw_RandomElement(state:State) -> void:
	var bench:BenchBase = RB.NewRawBench()
	var encoded:PackedByteArray = bench.Encode([])
	for i in state:
		var foobarcontainer:FooBarContainer = bytes_to_var_with_objects(encoded)
		var list:Array = foobarcontainer.list
		var list_size:int = list.size()
		if list_size > 0:
			var foobar:FooBar = list[int(list_size / 2.0)]
			var _rating:float = foobar.rating
			var _postfix:int = foobar.postfix
