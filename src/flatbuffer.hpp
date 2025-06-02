#ifndef GODOT_FLATBUFFERS_EXTENSION_FLATBUFFER_HPP
#define GODOT_FLATBUFFERS_EXTENSION_FLATBUFFER_HPP

#include <godot_cpp/classes/ref_counted.hpp>

#include "flatbuffers/flatbuffers.h"


namespace godot_flatbuffers {
class FlatBuffer final : public godot::RefCounted {
  GDCLASS( FlatBuffer, RefCounted ) // NOLINT(*-use-auto)

  typedef int32_t  soffset_t;
  typedef uint16_t voffset_t;
  typedef uint32_t uoffset_t;

  godot::Variant variant;

  const godot::PackedByteArray *bytes;

  int64_t        start{};

protected:

  static void _bind_methods();

public:
  //Debug
  [[nodiscard]] godot::String get_memory_address() const;

  // Get and Set of properties
  void set_bytes(const godot::Variant &variant );

  auto get_bytes() const -> godot::Variant;

  void set_start( int64_t start_ );

  [[nodiscard]] auto get_start() const -> int64_t;

  // Field offset and position
  [[nodiscard]] int64_t get_field_offset( int64_t vtable_offset ) const;

  [[nodiscard]] int64_t get_field_start( int64_t vtable_offset ) const;

  // Array/Vector offset and position
  [[nodiscard]] int64_t get_array_size( int64_t vtable_offset ) const;

  [[nodiscard]] int64_t get_array_element_start( int64_t array_start, int64_t idx ) const;

  // Template to simplify decoding pod data types from the bytes
  template< typename PODType >
  [[nodiscard]] PODType decode_struct( const int64_t start_ ) const {
    assert(start_ + sizeof( PODType ) <= bytes->size() );
    const auto p = const_cast< uint8_t * >(bytes->ptr() + start_);
    return *reinterpret_cast< PODType * >(p);
  }

  // Template to simplify getting the type from
  template< typename PODType >
  [[nodiscard]] PODType get_struct( const int64_t voffset ) const {
    const uoffset_t field_offset = get_field_offset( voffset );
    if( not field_offset) return {};
    const uoffset_t field_start = start + field_offset;
    return decode_struct<PODType>( field_start );
  }

  // template for struct array access
  // Arrays are vectors of uint32 indexes pointing to the resultant object.
  template< typename PODType >
  [[nodiscard]] PODType at_struct( const int64_t voffset, const uint32_t index ) const {
    // Starting with getting the array
    const uoffset_t array_offset = get_field_start( voffset );
    if( not array_offset) return {};

    //now using the index, get the data, for a POD array, the object is inline.
    uint64_t array_data = array_offset + 4;
    uint64_t element_start = array_data + index * sizeof( PODType );

    return decode_struct<PODType>( element_start );
  }

  [[nodiscard]] godot::String decode_String( int64_t start_ ) const;

  [[nodiscard]] godot::PackedByteArray decode_PackedByteArray( int64_t start_ ) const;

  [[nodiscard]] godot::PackedFloat32Array decode_packed_float32_array( int64_t start_ ) const;

  [[nodiscard]] godot::PackedFloat64Array decode_packed_float64_array( int64_t start_ ) const;

  [[nodiscard]] godot::PackedInt32Array decode_PackedInt32Array( int64_t start_ ) const;

  [[nodiscard]] godot::PackedInt64Array decode_PackedInt64Array( int64_t start_ ) const;

  [[nodiscard]] godot::PackedStringArray decode_PackedStringArray( int64_t start_ ) const;

};
} //namespace godot_flatbuffers

#endif //GODOT_FLATBUFFERS_EXTENSION_FLATBUFFER_HPP
