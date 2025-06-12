#include "flatbuffer.hpp"
#include <godot_cpp/core/class_db.hpp>

#ifdef DEBUG
#include <utility>

godot::String FlatBuffer::get_memory_address() const {
  const auto i = reinterpret_cast< std::uintptr_t >(bytes->ptr());
  return godot::vformat( "%X", i );
}
#endif

#include <source_location>


#include "godot_cpp/variant/variant_internal.hpp"

namespace godot_flatbuffers {

// MARK: Specialisation
// ║ ___              _      _ _          _   _
// ║/ __|_ __  ___ __(_)__ _| (_)___ __ _| |_(_)___ _ _
// ║\__ \ '_ \/ -_) _| / _` | | (_-</ _` |  _| / _ \ ' \
// ║|___/ .__/\___\__|_\__,_|_|_/__/\__,_|\__|_\___/_||_|
// ╙────|_|──────────────────────────────────────────────

template<> [[nodiscard]]
auto FlatBuffer::decode_gtype( const int64_t start_ ) const -> godot::PackedByteArray {
  const int64_t size        = bytes->decode_u32( start_ );
  const int64_t array_start = start_ + 4;
  return bytes->slice( array_start, array_start + size );
}

#define DECODE_PACKED_GTYPE( gtype, scalar, to_array_func ) \
template<> [[nodiscard]] \
auto FlatBuffer::decode_gtype( const int64_t start_ ) const -> godot::gtype { \
  const int64_t length      = bytes->decode_u32( start_ ) * sizeof( scalar ); \
  const int64_t array_start = start_ + 4; \
  return bytes->slice( array_start, array_start + length ).to_array_func(); \
}

// Ony a few of these functions exist in 'godot_cpp\variant\packed_byte_array.hpp'
DECODE_PACKED_GTYPE( PackedFloat32Array, float, to_float32_array )
DECODE_PACKED_GTYPE( PackedFloat64Array, double, to_float64_array )
DECODE_PACKED_GTYPE( PackedInt32Array, uint32_t, to_int32_array )
DECODE_PACKED_GTYPE( PackedInt64Array, uint64_t, to_int64_array )


template<> [[nodiscard]]
auto FlatBuffer::decode_gtype( const int64_t start_ ) const -> godot::String{
  return bytes->slice( start_ + 4, start_ + 4 + bytes->decode_u32( start_ ) ).get_string_from_utf8();
}


template<> [[nodiscard]]
auto FlatBuffer::decode_gtype( const int64_t start_ ) const -> godot::PackedStringArray {
  const int64_t size = bytes->decode_u32( start_ );
  const int64_t data = start_ + sizeof( uint32_t ); // NOLINT(*-narrowing-conversions)

  godot::PackedStringArray string_array;
  for( int i = 0; i < size; ++i ) {
    const int64_t  element = data + i * sizeof( uint32_t ); // NOLINT(*-narrowing-conversions)
    const uint32_t offset  = bytes->decode_u32( element );
    string_array.append( decode_gtype<godot::String>( element + offset ) );
  }
  return string_array;
}

// MARK: Bind Methods
// ║ ___ _         _   __  __     _   _            _
// ║| _ |_)_ _  __| | |  \/  |___| |_| |_  ___  __| |___
// ║| _ \ | ' \/ _` | | |\/| / -_)  _| ' \/ _ \/ _` (_-<
// ║|___/_|_||_\__,_| |_|  |_\___|\__|_||_\___/\__,_/__/
// ╙───────────────────────────────────────────────────────────────────────────

// get the data from the bytes directly
#define BIND_GTYPE_ENCODE(type_name) ClassDB::bind_method( D_METHOD( "encode_" #type_name, "start_", "value" ), &FlatBuffer::encode_gtype< type_name > );

// get the data from the bytes directly
#define BIND_GTYPE_DECODE(type_name) ClassDB::bind_method( D_METHOD( "decode_" #type_name, "start_" ), &FlatBuffer::decode_gtype< type_name > );

// get the data as a field
#define BIND_GTYPE_GET(type_name) ClassDB::bind_method( D_METHOD( "get_" #type_name, "voffset" ), &FlatBuffer::get_gtype< type_name > );

// get the data from an array
#define BIND_GTYPE_AT(type_name) ClassDB::bind_method( D_METHOD( "at_" #type_name, "voffset", "index" ), &FlatBuffer::at_gtype< type_name > );

#define BIND_GTYPE(type_name) \
BIND_GTYPE_ENCODE(type_name) \
BIND_GTYPE_DECODE(type_name) \
BIND_GTYPE_GET(type_name) \
BIND_GTYPE_AT(type_name)

void FlatBuffer::_bind_methods() {
  using namespace godot;

  //Debug
#ifdef DEBUG
  ClassDB::bind_method( D_METHOD( "get_memory_address" ), &FlatBuffer::get_memory_address );
#endif

  ClassDB::bind_method( D_METHOD( "set_bytes", "bytes" ), &FlatBuffer::set_bytes );
  ClassDB::bind_method( D_METHOD( "get_bytes" ), &FlatBuffer::get_bytes );
  ADD_PROPERTY( PropertyInfo(Variant::PACKED_BYTE_ARRAY, "bytes"), "set_bytes", "get_bytes" );

  //Properties
  ClassDB::bind_method( D_METHOD( "set_start", "start" ), &FlatBuffer::set_start );
  ClassDB::bind_method( D_METHOD( "get_start" ), &FlatBuffer::get_start );
  ADD_PROPERTY( PropertyInfo(Variant::INT, "start"), "set_start", "get_start" );

  // Field Access Helpers
  ClassDB::bind_method( D_METHOD( "get_field_offset", "vtable_offset" ), &FlatBuffer::get_field_offset );
  ClassDB::bind_method( D_METHOD( "get_field_start", "field_offset" ), &FlatBuffer::get_field_start );

  //Array Access Helpers
  ClassDB::bind_method( D_METHOD( "get_array_size", "vtable_offset" ), &FlatBuffer::get_array_size );
  ClassDB::bind_method( D_METHOD( "get_array_element_start", "array_start", "idx" ), &FlatBuffer::get_array_element_start );

  //Overwrite Bytes
  ClassDB::bind_method( D_METHOD( "overwrite_bytes", "source", "from", "to", "size" ), &FlatBuffer::overwrite_bytes );

  //// decode atomic types
  // BOOL, INT, FLOAT, are handled natively by godot::PackedByteArray
  // godot_cpp\variant\packed_byte_array.hpp
  BIND_GTYPE(String)

  //// Decode math types
  BIND_GTYPE(Vector2)
  BIND_GTYPE(Vector2i)
  BIND_GTYPE(Rect2)
  BIND_GTYPE(Rect2i)
  BIND_GTYPE(Vector3)
  BIND_GTYPE(Vector3i)
  BIND_GTYPE(Transform2D)
  BIND_GTYPE(Vector4)
  BIND_GTYPE(Vector4i)
  BIND_GTYPE(Plane)
  BIND_GTYPE(Quaternion)
  BIND_GTYPE(AABB)
  BIND_GTYPE(Basis)
  BIND_GTYPE(Transform3D)
  BIND_GTYPE(Projection)

  //// Decode misc types
  BIND_GTYPE(Color)

  //// Things to think about
  // STRING_NAME,
  // NODE_PATH,
  // RID,
  // OBJECT,
  // CALLABLE,
  // SIGNAL,
  // DICTIONARY,
  // ARRAY,

  // Decode typed arrays
  BIND_GTYPE(PackedByteArray)
  BIND_GTYPE(PackedInt32Array)
  BIND_GTYPE(PackedInt64Array)
  BIND_GTYPE(PackedFloat32Array)
  BIND_GTYPE(PackedFloat64Array)
  BIND_GTYPE(PackedStringArray)

  // PACKED_VECTOR2_ARRAY,
  // PACKED_VECTOR3_ARRAY,
  // PACKED_COLOR_ARRAY,
  // PACKED_VECTOR4_ARRAY,
}

// MARK: Function Definitions
// ║ ___               ___       __
// ║| __|  _ _ _  __  |   \ ___ / _|___
// ║| _| || | ' \/ _| | |) / -_)  _(_-<
// ║|_| \_,_|_||_\__| |___/\___|_| /__/
// ╙───────────────────────────────────

// Returns the field offset relative to 'start'.
// If this is a scalar or a struct, it will be where the data is
// If this is a table, or an array, it will be a relative offset to the position of the field.
int64_t FlatBuffer::get_field_offset( const int64_t vtable_offset ) const {
  // get vtable
  const int64_t vtable_pos = start - bytes->decode_s32( start );
  //int64_t table_size = bytes->decode_s16( vtable_pos + 2 ); Unnecessary

  // The vtable_pos being outside the range is not an error,
  // it simply means that the element is not present in the table.
  if( const int64_t vtable_size = bytes->decode_s16( vtable_pos ); vtable_offset >= vtable_size ) {
    return 0;
  }

  // decoding zero means that the field is not present.
  return bytes->decode_s16( vtable_pos + vtable_offset );
}

// returns offset from the zero of the bytes(PackedByteArray)
// This isn't necessary with structs and scalars, as the data is inline
int64_t FlatBuffer::get_field_start( const int64_t vtable_offset ) const {
  const int field_offset = get_field_offset( vtable_offset ); // NOLINT(*-narrowing-conversions)
  if( ! field_offset )
    return 0;
  return start + field_offset + bytes->decode_u32( start + field_offset );
}

int64_t FlatBuffer::get_array_size( const int64_t vtable_offset ) const {
  const int64_t foffset = get_field_offset( vtable_offset );
  if( ! foffset )
    return 0;
  const int64_t field_start = get_field_start( foffset );
  return bytes->decode_u32( field_start );
}

int64_t FlatBuffer::get_array_element_start(const int64_t array_start, const int64_t idx) const {
#ifdef DEBUG_ENABLED
  const int64_t array_size = bytes->decode_u32(array_start);
  assert(array_start < bytes->size() - 4);
  assert(idx < array_size);
  assert(array_start + array_size * 4 < bytes->size());
#endif

  const int64_t data    = array_start + 4;
  const int64_t element = data + idx * 4;
  const int64_t value   = bytes->decode_u32(element);

  return element + value;
}

auto FlatBuffer::overwrite_bytes(godot::Variant source, const int from, const int dest, const int size) const -> godot::Error {
  ERR_FAIL_COND_V_EDMSG( source.get_type() != godot::Variant::PACKED_BYTE_ARRAY, godot::ERR_INVALID_PARAMETER,
    "overwrite_bytes source must be a PackedByteArray" );
  ERR_FAIL_INDEX_V_EDMSG(dest+size, bytes->size(), godot::ERR_INVALID_PARAMETER,
    "Not enough memory for overwrite_bytes");

  const auto source_bytes = godot::VariantInternal::get_byte_array(&source)->ptr();
  const auto dest_bytes = const_cast<godot::PackedByteArray*>(bytes)->ptrw();
  memcpy(dest_bytes + dest, source_bytes + from, size);
  return godot::OK;
}

} // end namespace godot_flatbuffers
