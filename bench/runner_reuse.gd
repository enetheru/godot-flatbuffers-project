const RegisterLib = preload("uid://ehhn1k7v0g6w")
const FunctionBenchmark = RegisterLib.FunctionBenchmark

const CntFlags = Counter.Flags
const CntOneK = Counter.OneK

## Load on the 64-record scenario payload. The walk reuses one FBFooBar,
## one FBBar, and one FBFoo. The other scenario operations are unchanged.
static var _payload_error:String = ""


func _init() -> void:
	RegisterLib.ClearRegisteredBenchmarks()
	var work := CompareWork.new()
	_payload_error = work.check_payload()
	if _payload_error.is_empty():
		var buf := work.encode_flat()
		var readers := work.make_readers()
		var expected := work.flat_sum(buf)
		var reuse := work.flat_sum_reuse(buf, readers)
		if reuse != expected:
			_payload_error = "reuse load checksum %d != %d" % [reuse, expected]
	if not _payload_error.is_empty():
		printerr(_payload_error)

	@warning_ignore("return_value_discarded")
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_LoadReuse))


static func BM_Flatbuffers_LoadReuse(state:State) -> void:
	if not _payload_error.is_empty():
		state.SkipWithError(_payload_error)
		return
	var work := CompareWork.new()
	var buf := work.encode_flat()
	var readers := work.make_readers()
	var expected := work.flat_sum(buf)
	state.counters["bytes_size"] = Counter.new(
			buf.size(), CntFlags.kIsIterationInvariant, CntOneK.kIs1024)
	var throughput := Counter.new(0, CntFlags.kIsRate, CntOneK.kIs1024)
	state.counters["bytes/s"] = throughput
	for _i in state:
		var sum := work.flat_sum_reuse(buf, readers)
		throughput.value += buf.size()
		if sum != expected:
			state.SkipWithError("reuse load checksum %d != %d" % [sum, expected])
			return
