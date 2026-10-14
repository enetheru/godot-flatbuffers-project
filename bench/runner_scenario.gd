const RegisterLib = preload("uid://ehhn1k7v0g6w")
const FunctionBenchmark = RegisterLib.FunctionBenchmark

const CntFlags = Counter.Flags
const CntOneK = Counter.OneK

## Save, load, spawn, update, and one-field peek on one 64-record payload.
## FlatBuffers, Godot objects (var_to_bytes_with_objects), and a Dictionary
## (var_to_bytes) see the same field values. The original suite is untouched.
static var _payload_error:String = ""


func _init() -> void:
	RegisterLib.ClearRegisteredBenchmarks()
	var work := CompareWork.new()
	_payload_error = work.check_payload()
	if not _payload_error.is_empty():
		printerr(_payload_error)

	@warning_ignore_start("return_value_discarded")
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_Store))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_BuiltIn_Store))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_GDict_Store))

	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_Load))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_BuiltIn_Load))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_GDict_Load))

	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_Spawn))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_BuiltIn_Spawn))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_GDict_Spawn))

	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_Update))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_BuiltIn_Update))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_GDict_Update))

	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_Flatbuffers_Peek))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_BuiltIn_Peek))
	RegisterLib.RegisterBenchmarkInternal(FunctionBenchmark.new(BM_GDict_Peek))
	@warning_ignore_restore("return_value_discarded")


static func _fail(state:State) -> bool:
	if _payload_error.is_empty():
		return false
	state.SkipWithError(_payload_error)
	return true


static func _measure(state:State, size:int) -> Counter:
	state.counters["bytes_size"] = Counter.new(
			size, CntFlags.kIsIterationInvariant, CntOneK.kIs1024)
	var throughput := Counter.new(0, CntFlags.kIsRate, CntOneK.kIs1024)
	state.counters["bytes/s"] = throughput
	return throughput


static func BM_Flatbuffers_Store(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var sample := work.encode_flat()
	var throughput := _measure(state, sample.size())
	for _i in state:
		throughput.value += work.encode_flat().size()


static func BM_BuiltIn_Store(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var objects := work.make_objects()
	var sample := work.encode_objects(objects)
	var throughput := _measure(state, sample.size())
	for _i in state:
		throughput.value += work.encode_objects(objects).size()


static func BM_GDict_Store(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var data := work.make_dict()
	var sample := work.encode_dict(data)
	var throughput := _measure(state, sample.size())
	for _i in state:
		throughput.value += work.encode_dict(data).size()


static func BM_Flatbuffers_Load(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_flat()
	var expected := work.flat_sum(buf)
	var throughput := _measure(state, buf.size())
	for _i in state:
		var sum := work.flat_sum(buf)
		throughput.value += buf.size()
		if sum != expected:
			state.SkipWithError("flat load checksum %d != %d" % [sum, expected])
			return


static func BM_BuiltIn_Load(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_objects(work.make_objects())
	var expected := work.object_sum_bytes(buf)
	var throughput := _measure(state, buf.size())
	for _i in state:
		var sum := work.object_sum_bytes(buf)
		throughput.value += buf.size()
		if sum != expected:
			state.SkipWithError("object load checksum %d != %d" % [sum, expected])
			return


static func BM_GDict_Load(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_dict(work.make_dict())
	var expected := work.dict_sum_bytes(buf)
	var throughput := _measure(state, buf.size())
	for _i in state:
		var sum := work.dict_sum_bytes(buf)
		throughput.value += buf.size()
		if sum != expected:
			state.SkipWithError("dict load checksum %d != %d" % [sum, expected])
			return


static func BM_Flatbuffers_Spawn(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_flat()
	var throughput := _measure(state, buf.size())
	for _i in state:
		var spawned := work.spawn_flat(buf)
		throughput.value += buf.size()
		if spawned.is_empty():
			state.SkipWithError("flat spawn was empty")
			return


static func BM_BuiltIn_Spawn(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_objects(work.make_objects())
	var throughput := _measure(state, buf.size())
	for _i in state:
		var spawned := work.spawn_objects(buf)
		throughput.value += buf.size()
		if spawned == null:
			state.SkipWithError("object spawn failed")
			return


static func BM_GDict_Spawn(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_dict(work.make_dict())
	var throughput := _measure(state, buf.size())
	for _i in state:
		var spawned := work.spawn_dict(buf)
		throughput.value += buf.size()
		if spawned.is_empty():
			state.SkipWithError("dict spawn was empty")
			return


static func BM_Flatbuffers_Update(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_flat()
	var dest := work.make_dict()
	var throughput := _measure(state, buf.size())
	for _i in state:
		work.apply_flat(buf, dest)
		throughput.value += buf.size()


static func BM_BuiltIn_Update(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_objects(work.make_objects())
	var dest := work.make_objects()
	var throughput := _measure(state, buf.size())
	for _i in state:
		work.apply_objects(buf, dest)
		throughput.value += buf.size()


static func BM_GDict_Update(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_dict(work.make_dict())
	var dest := work.make_dict()
	var throughput := _measure(state, buf.size())
	for _i in state:
		work.apply_dict(buf, dest)
		throughput.value += buf.size()


static func BM_Flatbuffers_Peek(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_flat()
	var expected := work.peek_flat(buf)
	var throughput := _measure(state, buf.size())
	for _i in state:
		var rating := work.peek_flat(buf)
		throughput.value += buf.size()
		if rating != expected:
			state.SkipWithError("flat peek %d != %d" % [rating, expected])
			return


static func BM_BuiltIn_Peek(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_objects(work.make_objects())
	var expected := work.peek_objects(buf)
	var throughput := _measure(state, buf.size())
	for _i in state:
		var rating := work.peek_objects(buf)
		throughput.value += buf.size()
		if rating != expected:
			state.SkipWithError("object peek %d != %d" % [rating, expected])
			return


static func BM_GDict_Peek(state:State) -> void:
	if _fail(state):
		return
	var work := CompareWork.new()
	var buf := work.encode_dict(work.make_dict())
	var expected := work.peek_dict(buf)
	var throughput := _measure(state, buf.size())
	for _i in state:
		var rating := work.peek_dict(buf)
		throughput.value += buf.size()
		if rating != expected:
			state.SkipWithError("dict peek %d != %d" % [rating, expected])
			return
