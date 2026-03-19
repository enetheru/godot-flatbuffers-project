@tool

# Typically, we can only read a small number of counters. There is also a
# padding preceding counter values, when reading multiple counters with one
# syscall (which is desirable). PerfCounterValues abstracts these details.
# The implementation ensures the storage is inlined, and allows 0-based
# indexing into the counter values.
# The object is used in conjunction with a PerfCounters object, by passing it
# to Snapshot(). The Read() method relocates individual reads, discarding
# the initial padding from each group leader in the values buffer such that
# all user accesses through the [] operator are correct.
class PerfCounterValues:
	func _init(nr_counters:int) -> void:
		_nr_counters = nr_counters
		if _values.resize(16 * (kPadding + kMaxCounters)) != OK:
			push_error("Failed to resize _values")
		_values.fill(0)
		assert(_nr_counters <= kMaxCounters)

	# We are reading correctly now so the values don't need to skip padding
	#STUB uint64_t operator[](size_t pos) const { return values_[pos]; }
	# NOTE: I cant use operators in gdscript so I will sub with at(i)
	func at(pos:int) -> int: return _values[pos]

	# Increased the maximum to 32 only since the buffer
	# is std::array<> backed
	const kMaxCounters:int = 32

	# Get the byte buffer in which perf counters can be captured.
	# This is used by PerfCounters::Read
	#std::pair<char*, size_t> get_data_buffer() {
	#return {reinterpret_cast<char*>(values_.data()),
			#sizeof(uint64_t) * (kPadding + nr_counters_)};
	func get_data_buffer() -> Dictionary:
		return {_values.get_string_from_utf8(): 16 * (kPadding + _nr_counters)}

	# This reading is complex and as the goal of this class is to
	# abstract away the intrincacies of the reading process, this is
	# a better place for it
	func Read(_leaders:Array[int]) -> int: return 0

	# Move the padding to 2 due to the reading algorithm (1st padding plus a
	# current read padding)
	const kPadding:int = 2
	var _values:PackedByteArray
	var _nr_counters:int



# Collect PMU counters. The object, once constructed, is ready to be used by
# calling read(). PMU counter collection is enabled from the time create() is
# called, to obtain the object, until the object's destructor is called.
class PerfCounters:
	# True iff this platform supports performance counters.
	var kSupported:bool

	# Returns an empty object
	static func NoCounters() -> PerfCounters:
		return PerfCounters.new([], [], [])

	#STUB ~PerfCounters() { CloseCounters(); }
	#STUB PerfCounters() = default;
	#STUB PerfCounters(PerfCounters&&) = default;
	#STUB PerfCounters(const PerfCounters&) = delete;
	#STUB PerfCounters& operator=(PerfCounters&&) noexcept;
	#STUB PerfCounters& operator=(const PerfCounters&) = delete;

	# Platform-specific implementations may choose to do some library
	# initialization here.
	static func Initialize() -> bool: return false

	# Check if the given counter is supported, if the app wants to
	# check before passing
	static func IsCounterSupported(_name:String) -> bool: return false

	# Return a PerfCounters object ready to read the counters with the names
	# specified. The values are user-mode only. The counter name format is
	# implementation and OS specific.
	# In case of failure, this method will in the worst case return an
	# empty object whose state will still be valid.
	static func Create(_new_counter_names:Array[String]) -> PerfCounters:
		return PerfCounters.new([], [], [])


	# Take a snapshot of the current value of the counters into the provided
	# valid PerfCounterValues storage. The values are populated such that:
	# names()[i]'s value is (*values)[i]
	func Snapshot(values:PerfCounterValues) -> bool:
#ifndef BENCHMARK_OS_WINDOWS
		assert(values != null)
		return values.Read(_leader_ids) == _counter_ids.size()
#else
#STUB		(void)values;
#STUB		return false;
#endif

	func names() -> Array[String]: return _counter_names
	func num_counters() -> int: return _counter_names.size()


	func _init(
			counter_names:Array[String],
			counter_ids:Array[int],
			leader_ids:Array[int] ) -> void:
		_counter_ids	 = counter_ids
		_leader_ids		= leader_ids
		_counter_names = counter_names

	func CloseCounters() -> void:pass

	var _counter_ids:Array[int]
	var _leader_ids:Array[int]
	var _counter_names:Array[String]



# Typical usage of the above primitives.
class PerfCountersMeasurement:
	func _init(new_counter_names:Array[String]) -> void:
		_start_values = PerfCounterValues.new(new_counter_names.size())
		_end_values = PerfCounterValues.new(new_counter_names.size())
		_counters = PerfCounters.Create(new_counter_names)


	func num_counters() -> int: return _counters.num_counters()

	func names() -> Array[String]:
		return _counters.names()

	func Start() -> bool:
		if num_counters() == 0: return true
		_valid_read = _valid_read and _counters.Snapshot(_start_values)
		return _valid_read

	func Stop( measurements:Dictionary) -> bool:
		if num_counters() == 0: return true
		_valid_read = _valid_read and _counters.Snapshot(_end_values)

		for cname:String in _counters.names():
			measurements[cname] = _end_values[cname] - _start_values[cname]


		return _valid_read

	var _counters:PerfCounters
	var _valid_read:bool = true
	var _start_values:PerfCounterValues
	var _end_values:PerfCounterValues
