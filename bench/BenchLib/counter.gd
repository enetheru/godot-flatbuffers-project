@tool

const Benchlib = preload("uid://oxy2u2g2m8qu")
const Counter = BenchLib.Counter

static func FinishCounter(
			c:Counter, 
			iterations:int, # IterationCount 
			cpu_time:float,
			num_threads:float ) -> float:
	var v:float = c.value
	if (c.flags & Counter.Flags.kIsRate) != 0:
		v /= cpu_time;
	
	if (c.flags & Counter.Flags.kAvgThreads) != 0:
		v /= num_threads;

	if (c.flags & Counter.Flags.kIsIterationInvariant) != 0:
		v *= float(iterations)

	if (c.flags & Counter.Flags.kAvgIterations) != 0:
		v /= float(iterations)

	if (c.flags & Counter.Flags.kInvert) != 0:   # Invert is *always* last.
		v = 1.0 / v;
	return v;


static func FinishUserCounters(
			l:Dictionary[String, Counter], # UserCounters, 
			iterations:int, # IterationCount, 
			cpu_time:float, 
			num_threads:float) -> void:
	for c:String in l.keys():
		l[c].value = FinishCounter(l[c], iterations, cpu_time, num_threads)


# UserCounters is a Dictionary[String, Counter]
static func Increment(l:Dictionary, r:Dictionary) -> void:
	# add counters present in both or just in *l
	# for (auto& c : *l) {
	#   auto it = r.find(c.first);
	#   if (it != r.end()) {
	#     c.second.value = c.second + it->second;
	#   }
	# }
	for c_key:String in l.keys():
		var rct:Counter = r.get(c_key)
		if rct:
			var lct:Counter = l[c_key]
			lct.value = lct.value + rct.value

	# add counters present in r, but not in *l
	# for (auto const& tc : r) {
	#   auto it = l->find(tc.first);
	#   if (it == l->end()) {
	#     (*l)[tc.first] = tc.second;
	#   }
	# }
	for c_key:String in r.keys():
		if not l.has(c_key):
			l[c_key] = r.get(c_key)
