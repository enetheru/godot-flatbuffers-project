@tool


const MutexLib = preload("uid://bkxuuk1h7yrbg")
const Barrier = MutexLib.Barrier

const Statslib = preload("uid://c8w76q8bhpf8q")

const Counter = BenchLib.Counter
const Skipped = Statslib.Skipped

class ThreadManager:
	func _init(_num_thread:int) -> void:
		start_stop_barrier = Barrier.new(_num_thread)


	func StartStopBarrier() -> bool:
		var value:bool = await start_stop_barrier.wait()
		return value


	func NotifyThreadComplete() -> void:
		start_stop_barrier.removeThread()


	class Result:
		var iterations:int = 0 #IterationCount
		var real_time_used:float = 0
		var cpu_time_used:float = 0
		var manual_time_used:float = 0
		var complexity_n:int = 0
		var report_label:String
		var skip_message:String
		var skipped:Skipped = Skipped.NotSkipped
		var counters:Dictionary[String,Counter] # UserCounters

	#GUARDED_BY(GetBenchmarkMutex())
	var results := Result.new()

	var benchmark_mutex := Mutex.new()

	var start_stop_barrier:Barrier
