extends Node


func _ready() -> void:
	BM_Flatbuffers_Encode(10)
	get_tree().quit()


#static inline void Encode(benchmark::State& state,
						  #std::unique_ptr<Bench>& bench, uint8_t* buffer) {
static func Encode( state:int, bench:BenchBase, buffer:PackedByteArray ) -> void:
	#int64_t length;
	for i:int in state:
		var _buf:PackedByteArray = bench.Encode(buffer);


#static inline void Decode(benchmark::State& state,
#						  std::unique_ptr<Bench>& bench, uint8_t* buffer) {
static func Decode( state:int, bench:BenchBase, buffer:PackedByteArray) -> void:
#STUB	int64_t length;
#STUB 	uint8_t* encoded = bench->Encode(buffer, length);
#STUB 	for (auto _ : state) {
#STUB 		void* decoded = bench->Decode(encoded, length);
	var encoded:PackedByteArray = bench.Encode(buffer);
	for i:int in state:
		var _decoded:PackedByteArray = bench.Decode(encoded)


#static inline void Use(benchmark::State& state, std::unique_ptr<Bench>& bench,
					   #uint8_t* buffer, int64_t check_sum) {
static func Use( state:int, bench:BenchBase, buffer:PackedByteArray, check_sum:int ) -> void:
	#int64_t length;
	#var length:int
#STUB	uint8_t* encoded = bench->Encode(buffer, length);
#STUB	void* decoded = bench->Decode(encoded, length);
#STUB
#STUB	int64_t sum = 0;
#STUB
#STUB	for (auto _ : state) {
#STUB		sum = bench->Use(decoded);
#STUB	}
#STUB
#STUB	EXPECT_EQ(sum, check_sum);
	var encoded:PackedByteArray = bench.Encode(buffer);
	var decoded:PackedByteArray = bench.Decode(encoded)
	var sum:int = 0
	for i:int in state:
		sum = bench.Use(decoded)

	if sum != check_sum:
		push_error("Checksum did not match")


#static void BM_Flatbuffers_Encode(benchmark::State& state) {
  #const int64_t kBufferLength = 1024;
  #uint8_t buffer[kBufferLength];
#
  #StaticAllocator allocator(&buffer[0]);
  #std::unique_ptr<Bench> bench = NewFlatBuffersBench(kBufferLength, &allocator);
  #Encode(state, bench, buffer);
#}
#BENCHMARK(BM_Flatbuffers_Encode);

static func BM_Flatbuffers_Encode(state:int) -> void:
	const kBufferLength:int = 1024
	var buffer:PackedByteArray
	if buffer.resize( kBufferLength) != OK:
		push_error("Failed to resize buffer")
		return

	var bench:BenchBase = FlatBuffersBench.new(kBufferLength);
	Encode(state, bench, buffer);

#STUB BENCHMARK(BM_Flatbuffers_Encode);



#static void BM_Flatbuffers_Decode(benchmark::State& state) {
  #const int64_t kBufferLength = 1024;
  #uint8_t buffer[kBufferLength];
#
  #StaticAllocator allocator(&buffer[0]);
  #std::unique_ptr<Bench> bench = NewFlatBuffersBench(kBufferLength, &allocator);
  #Decode(state, bench, buffer);
#}
#BENCHMARK(BM_Flatbuffers_Decode);



#static void BM_Flatbuffers_Use(benchmark::State& state) {
  #const int64_t kBufferLength = 1024;
  #uint8_t buffer[kBufferLength];
#
  #StaticAllocator allocator(&buffer[0]);
  #std::unique_ptr<Bench> bench = NewFlatBuffersBench(kBufferLength, &allocator);
  #Use(state, bench, buffer, 218812692406581874);
#}
#BENCHMARK(BM_Flatbuffers_Use);



#static void BM_Raw_Encode(benchmark::State& state) {
  #const int64_t kBufferLength = 1024;
  #uint8_t buffer[kBufferLength];
#
  #std::unique_ptr<Bench> bench = NewRawBench();
  #Encode(state, bench, buffer);
#}
#BENCHMARK(BM_Raw_Encode);



#static void BM_Raw_Decode(benchmark::State& state) {
  #const int64_t kBufferLength = 1024;
  #uint8_t buffer[kBufferLength];
#
  #std::unique_ptr<Bench> bench = NewRawBench();
  #Decode(state, bench, buffer);
#}
#BENCHMARK(BM_Raw_Decode);



#static void BM_Raw_Use(benchmark::State& state) {
  #const int64_t kBufferLength = 1024;
  #uint8_t buffer[kBufferLength];
#
  #std::unique_ptr<Bench> bench = NewRawBench();
  #Use(state, bench, buffer, 218812692406581874);
#}
#BENCHMARK(BM_Raw_Use);
