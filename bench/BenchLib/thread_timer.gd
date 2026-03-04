@tool
class_name ThreadTimer

func _init(measure_process_cpu_time_:bool) -> void:
	measure_process_cpu_time = measure_process_cpu_time_

static func Create() -> ThreadTimer:
	return ThreadTimer.new(false) # measure_process_cpu_time_


static func CreateProcessCpuTime() -> ThreadTimer:
	return ThreadTimer.new(true)  # /*measure_process_cpu_time_=*/


# Called by each thread
func StartTimer() -> void:
	running_ = true;
	start_real_time_ = Time.get_ticks_usec() # ChronoClockNow();
	start_cpu_time_ = ReadCpuTimerOfChoice()


# Called by each thread
func StopTimer() -> void:
	assert(running_)
	running_ = false;
	#real_time_used_ += ChronoClockNow() - start_real_time_;
	real_time_used_ += Time.get_ticks_usec() - start_real_time_;
	
	# Floating point error can result in the subtraction producing a negative
	# time. Guard against that.
	cpu_time_used_ += \
		maxi(ReadCpuTimerOfChoice() - start_cpu_time_, 0)


# Called by each thread
func SetIterationTime(micros:float) -> void: manual_time_used_ += int(micros * 1000000)

func running() -> bool: return running_

# REQUIRES: timer is not running
func real_time_used() -> float:
	assert( not running_)
	return real_time_used_ / 1000000.0

# REQUIRES: timer is not running
func cpu_time_used() -> float:
	assert(not running_);
	return cpu_time_used_ / 1000000.0

# REQUIRES: timer is not running
func manual_time_used() -> float:
	assert(not running_)
	return manual_time_used_ / 1000000.0


func ReadCpuTimerOfChoice() -> int:
	#STUB if measure_process_cpu_time: return ProcessCPUUsage()
	#STUB return ThreadCPUUsage()
	return Time.get_ticks_usec()


# should the thread, or the process, time be measured?
var measure_process_cpu_time:bool

var running_:bool = false;        # Is the timer running
var start_real_time_:int = 0;   # If running_
var start_cpu_time_:int = 0;    # If running_

# Accumulated time so far (does not contain current slice if running_)
var real_time_used_:int = 0;
var cpu_time_used_:int = 0;
# Manually set iteration time. User sets this with SetIterationTime(seconds).
var manual_time_used_:int = 0;
