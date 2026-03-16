@tool

@abstract
class_name BenchCase

var sum:int = 0

func Add( value:int ) -> void:
	sum += value


@abstract
##virtual uint8_t* Encode(void* buf, int64_t& len) = 0;
# NOTE: We can omit the length as it is within the packedbyearray
func Encode( buf:PackedByteArray ) -> PackedByteArray


@abstract
##virtual void* Decode(void* buf, int64_t len) = 0;
func Decode( buf:PackedByteArray ) -> Variant


@abstract
##virtual int64_t Use(void* decoded) = 0;
func Use( decoded:Variant ) -> int
#TODO And this consume a Variant


@abstract
##virtual void Dealloc(void* decoded) = 0;
func Dealloc( decoded:Variant ) -> void
