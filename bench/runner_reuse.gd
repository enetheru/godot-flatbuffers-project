const RegisterLib = preload("uid://ehhn1k7v0g6w")
const FunctionBenchmark = RegisterLib.FunctionBenchmark

const CntFlags = Counter.Flags
const CntOneK = Counter.OneK

## Load, Spawn, and Update on the 64-record scenario payload. Each reuses
## one FBFooBar, one FBBar, and one FBFoo. Store and Peek do not.
static var _payload_error:String = ""
static var _spawn_error:String = ""
static var _update_error:String = ""


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
		else:
			var spawned := work.spawn_flat_reuse(buf, readers)
			var plain := work.dict_sum(work.spawn_flat(buf))
			var reused_sum := -1 if spawned.is_empty() else work.dict_sum(spawned)
			if spawned.is_empty() or reused_sum != plain:
				_spawn_error = "reuse spawn checksum %d != %d" % [reused_sum, plain]
			var probe := work.make_dict()
			probe.location = ""
			var applied := work.apply_flat_reuse(buf, probe, readers)
			var update_sum := -1 if not applied else work.dict_sum(probe)
			var plain_dest := work.make_dict()
			plain_dest.location = ""
			work.apply_flat(buf, plain_dest)
			var update_plain := work.dict_sum(plain_dest)
			if not applied or update_sum != update_plain:
				_update_error = "reuse update checksum %d != %d" % [update_sum, update_plain]
	if not _payload_error.is_empty():
		printerr(_payload_error)
	if not _spawn_error.is_empty():
		printerr(_spawn_error)
	if not _update_error.is_empty():
		printerr(_update_error)

	@warning_ignore_start("return_value_discarded")
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_LoadReuse))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_SpawnReuse))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_UpdateReuse))
	@warning_ignore_restore("return_value_discarded")


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


static func BM_Flatbuffers_SpawnReuse(state:State) -> void:
	if not _payload_error.is_empty():
		state.SkipWithError(_payload_error)
		return
	if not _spawn_error.is_empty():
		state.SkipWithError(_spawn_error)
		return
	var work := CompareWork.new()
	var buf := work.encode_flat()
	var readers := work.make_readers()
	var spawned := work.spawn_flat_reuse(buf, readers)
	var plain := work.dict_sum(work.spawn_flat(buf))
	var reused_sum := -1 if spawned.is_empty() else work.dict_sum(spawned)
	if spawned.is_empty() or reused_sum != plain:
		state.SkipWithError("reuse spawn checksum %d != %d" % [reused_sum, plain])
		return
	var throughput := Counter.new(0, CntFlags.kIsRate, CntOneK.kIs1024)
	state.counters["bytes_size"] = Counter.new(
			buf.size(), CntFlags.kIsIterationInvariant, CntOneK.kIs1024)
	state.counters["bytes/s"] = throughput
	for _i in state:
		spawned = work.spawn_flat_reuse(buf, readers)
		throughput.value += buf.size()
		if spawned.is_empty():
			state.SkipWithError("reuse spawn was empty")
			return


static func BM_Flatbuffers_UpdateReuse(state:State) -> void:
	if not _payload_error.is_empty():
		state.SkipWithError(_payload_error)
		return
	if not _update_error.is_empty():
		state.SkipWithError(_update_error)
		return
	var work := CompareWork.new()
	var buf := work.encode_flat()
	var readers := work.make_readers()
	var probe := work.make_dict()
	probe.location = ""
	var applied := work.apply_flat_reuse(buf, probe, readers)
	var reused_sum := -1 if not applied else work.dict_sum(probe)
	var plain_dest := work.make_dict()
	plain_dest.location = ""
	work.apply_flat(buf, plain_dest)
	var plain := work.dict_sum(plain_dest)
	if not applied or reused_sum != plain:
		state.SkipWithError("reuse update checksum %d != %d" % [reused_sum, plain])
		return
	var dest := work.make_dict()
	var throughput := Counter.new(0, CntFlags.kIsRate, CntOneK.kIs1024)
	state.counters["bytes_size"] = Counter.new(
			buf.size(), CntFlags.kIsIterationInvariant, CntOneK.kIs1024)
	state.counters["bytes/s"] = throughput
	for _i in state:
		work.apply_flat_reuse(buf, dest, readers)
		throughput.value += buf.size()
