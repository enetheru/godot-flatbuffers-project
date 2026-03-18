@tool

const RegisterLib = preload("uid://ehhn1k7v0g6w")
const State = BenchLib.State
const Benchmark = BenchLib.Benchmark
const FunctionBenchmark = BenchLib.FunctionBenchmark
const ConsoleReporter = preload("uid://cp6jwltd8s2ur")

const CntFlags = BenchLib.Counter.Flags
const CntOneK = BenchLib.Counter.OneK

const FB = preload("fb_scripts/bench_generated.gd")
const CaseGdDict = preload("uid://dve0r6lgn2kft")

func _init() -> void:
	BenchLib.BenchmarkFamilies.GetInstance()._families.clear()
	BenchLib.FLAGS_benchmark_list_tests = false
	BenchLib.FLAGS_benchmark_dry_run = false
	BenchLib.kMaxIterations = 100

	# Standard Encode
	@warning_ignore_start("return_value_discarded")
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_Encode))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_Decode))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_ReadAll))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_RoundTrip))

	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_EncodePA))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_DecodePA))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_ReadAllPA))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_RoundTripPA))

	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_EncodeSR))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_DecodeSR))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_ReadAllSR))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_RoundTripSR))

	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_EncodePASR))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_DecodePASR))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_ReadAllPASR))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_RoundTripPASR))


	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_BuiltIn_Encode))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_BuiltIn_Decode))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_BuiltIn_ReadAll))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_BuiltIn_RoundTrip))

	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_GDict_Encode))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_GDict_Decode))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_GDict_ReadAll))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_GDict_RoundTrip)).Arg(1)


	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_MetadataOnly))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_BuiltIn_MetadataOnly))

	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_RandomElement))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_BuiltIn_RandomElement))
	@warning_ignore_restore("return_value_discarded")


func _run() -> void:
	var reporter := ConsoleReporter.new()
	var num_benchmarks:int = BenchLib.RunSpecifiedBenchmarks(reporter)
	if num_benchmarks == 0:
		printerr("zero benchmarks")
	else:
		print("%d benchmarks" % num_benchmarks)


# --- Encode ---
static func GenericEncode(state:State, bench:BenchCase) -> void:
	state.counters["bytes_size"] = BenchLib.Counter.new(
			bench.Encode().size(), CntFlags.kIsIterationInvariant, CntOneK.kIs1024)

	var throughput := BenchLib.Counter.new(0, CntFlags.kIsRate, CntOneK.kIs1024)
	state.counters["bytes/s"] = throughput

	for i in state:
		var buf:PackedByteArray = bench.Encode()
		throughput.value += buf.size()


static func BM_Flatbuffers_Encode(state:State) -> void:
	GenericEncode(state, FlatBuffersBench.new())

static func BM_Flatbuffers_EncodePA(state:State) -> void:
	GenericEncode(state, FlatBuffersBench.new({&'pre_allocate':true}))

static func BM_Flatbuffers_EncodeSR(state:State) -> void:
	GenericEncode(state, FlatBuffersBench.new({&'static_reader':true}))

static func BM_Flatbuffers_EncodePASR(state:State) -> void:
	GenericEncode(state, FlatBuffersBench.new(
		{&'pre_allocate':true, &'static_reader':true}))

static func BM_BuiltIn_Encode(state:State) -> void:
	GenericEncode(state, BuiltInBench.new())

static func BM_GDict_Encode(state:State) -> void:
	GenericEncode(state, CaseGdDict.new())


# --- Read-All ---
static func GenericReadAll(state:State, bench:BenchCase) -> void:
	var encoded:PackedByteArray = bench.Encode()
	var decoded:Variant = bench.Decode(encoded)
	var sum:int = 0
	for i:int in state:
		sum = bench.Use(decoded)
	if sum: pass

static func BM_Flatbuffers_ReadAll(state:State) -> void:
	GenericReadAll(state, FlatBuffersBench.new())

static func BM_Flatbuffers_ReadAllPA(state:State) -> void:
	GenericReadAll(state, FlatBuffersBench.new({&'pre_allocate':true}))

static func BM_Flatbuffers_ReadAllSR(state:State) -> void:
	GenericReadAll(state, FlatBuffersBench.new({&'static_reader':true}))

static func BM_Flatbuffers_ReadAllPASR(state:State) -> void:
	GenericReadAll(state, FlatBuffersBench.new(
		{&'pre_allocate':true, &'static_reader':true}))

static func BM_BuiltIn_ReadAll(state:State) -> void:
	GenericReadAll(state, BuiltInBench.new())

static func BM_GDict_ReadAll(state:State) -> void:
	GenericReadAll(state, CaseGdDict.new())

# --- Round-Trip ---
static func GenericRoundTrip(state:State, bench:BenchCase) -> void:
	var check_sum:int = 2524655701620275826
	for i in state:
		var encoded:PackedByteArray = bench.Encode()
		var decoded:Variant = bench.Decode(encoded)
		var sum:int = bench.Use(decoded)
		if sum != check_sum:
			state.SkipWithError("Checksum did not match: %s != %s" % [check_sum, sum])

static func BM_Flatbuffers_RoundTrip(state:State) -> void:
	GenericRoundTrip(state, FlatBuffersBench.new())

static func BM_Flatbuffers_RoundTripPA(state:State) -> void:
	GenericRoundTrip(state, FlatBuffersBench.new({&'pre_allocate':true}))

static func BM_Flatbuffers_RoundTripSR(state:State) -> void:
	GenericRoundTrip(state, FlatBuffersBench.new({&'static_reader':true}))

static func BM_Flatbuffers_RoundTripPASR(state:State) -> void:
	GenericRoundTrip(state, FlatBuffersBench.new(
		{&'pre_allocate':true, &'static_reader':true}))

static func BM_BuiltIn_RoundTrip(state:State) -> void:
	GenericRoundTrip(state, BuiltInBench.new())

static func BM_GDict_RoundTrip(state:State) -> void:
	GenericRoundTrip(state, CaseGdDict.new())

# --- Decode ---
static func GenericDecode(state:State, bench:BenchCase) -> void:
	var encoded:PackedByteArray = bench.Encode()
	for i:int in state:
		var _decoded:Variant = bench.Decode(encoded)

static func BM_Flatbuffers_Decode(state:State) -> void:
	GenericDecode(state, FlatBuffersBench.new())

static func BM_Flatbuffers_DecodePA(state:State) -> void:
	GenericDecode(state, FlatBuffersBench.new({&'pre_allocate':true}))

static func BM_Flatbuffers_DecodeSR(state:State) -> void:
	GenericDecode(state, FlatBuffersBench.new({&'static_reader':true}))

static func BM_Flatbuffers_DecodePASR(state:State) -> void:
	GenericDecode(state, FlatBuffersBench.new(
		{&'pre_allocate':true, &'static_reader':true}))

static func BM_BuiltIn_Decode(state:State) -> void:
	GenericDecode(state, BuiltInBench.new())

static func BM_GDict_Decode(state:State) -> void:
	GenericDecode(state, CaseGdDict.new())


# --- Metadata Only ---
# TODO If I want to keep this test, move the function to the BenchCase abstract
static func BM_Flatbuffers_MetadataOnly(state:State) -> void:
	var bench:BenchCase = FlatBuffersBench.new()
	var encoded:PackedByteArray = bench.Encode()
	for i in state:
		var foobarcontainer:FB.FBFooBarContainer = FB.get_FBFooBarContainer(encoded)
		var _initialised:bool = foobarcontainer.initialized()
		var _fruit:FB.Enum = foobarcontainer.fruit()
		var _loc_len:int = foobarcontainer.location().length()


static func BM_BuiltIn_MetadataOnly(state:State) -> void:
	var bench:BenchCase = BuiltInBench.new()
	var encoded:PackedByteArray = bench.Encode()
	for i in state:
		var foobarcontainer:FooBarContainer = bytes_to_var_with_objects(encoded)
		var _initialised:bool = foobarcontainer.initialized
		var _fruit:FooBarContainer.Enum = foobarcontainer.fruit
		var _loc_len:int = foobarcontainer.location.length()

# --- Random Element ---
# TODO If I want to keep this test, move the function to the BenchCase abstract
static func BM_Flatbuffers_RandomElement(state:State) -> void:
	var bench:BenchCase = FlatBuffersBench.new()
	var encoded:PackedByteArray = bench.Encode()
	for i in state:
		var foobarcontainer:FB.FBFooBarContainer = FB.get_FBFooBarContainer(encoded)
		var list_size:int = foobarcontainer.list_size()
		if list_size > 0:
			var foobar:FB.FBFooBar = foobarcontainer.list_at(int(list_size / 2.0))
			var _rating:float = foobar.rating()
			var _postfix:int = foobar.postfix()


static func BM_BuiltIn_RandomElement(state:State) -> void:
	var bench:BenchCase = BuiltInBench.new()
	var encoded:PackedByteArray = bench.Encode()
	for i in state:
		var foobarcontainer:FooBarContainer = bytes_to_var_with_objects(encoded)
		var list:Array = foobarcontainer.list
		var list_size:int = list.size()
		if list_size > 0:
			var foobar:FooBar = list[int(list_size / 2.0)]
			var _rating:float = foobar.rating
			var _postfix:int = foobar.postfix
