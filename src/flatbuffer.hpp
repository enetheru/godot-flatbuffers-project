#ifndef GODOT_FLATBUFFERS_EXTENSION_FLATBUFFER_HPP
#define GODOT_FLATBUFFERS_EXTENSION_FLATBUFFER_HPP

#include <godot_cpp/classes/ref_counted.hpp>

#include "flatbuffers/flatbuffers.h"
#include "godot_cpp/variant/variant_internal.hpp"


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
#ifdef DEBUG
  [[nodiscard]] godot::String get_memory_address() const;
#endif

  // Get and Set of properties
  [[nodiscard]]
  auto get_bytes() const -> godot::Variant{ return variant; }
  auto set_bytes(const godot::Variant &variant )  -> void {
    bytes = godot::VariantInternal::get_byte_array( &variant );
    this->variant = variant ;
  }

  [[nodiscard]]
  auto get_start() const -> int64_t { return start; }
  auto set_start( const int64_t start_ ) -> void { start = start_; }

  // Field offset and position
  [[nodiscard]] int64_t get_field_offset( int64_t vtable_offset ) const;

  [[nodiscard]] int64_t get_field_start( int64_t vtable_offset ) const;

  // Array/Vector offset and position
  [[nodiscard]] int64_t get_array_size( int64_t vtable_offset ) const;

  [[nodiscard]] int64_t get_array_element_start( int64_t array_start, int64_t idx ) const;

  auto overwrite_bytes( godot::Variant source, int from, int dest, int size ) const -> godot::Error;

  // Template to simplify encoding godot types into bytes at start_
  // Very simple, performs a raw memcpy to the byte array after checking it has enough room.
  // Specialisations exist in the cpp file
  template< typename GType >
  auto encode_gtype( const int64_t start_, const GType &value ) -> void {
    ERR_FAIL_INDEX_EDMSG(start_ + sizeof(GType), bytes->size(), "Not enough room in the buffer to encode object");
    const auto mem = const_cast<godot::PackedByteArray*>(bytes)->ptrw() + start_;
    memcpy( mem , &value, sizeof(GType)  );
  }

  // Template to simplify decoding godot data types from bytes
  // Very simple, checks we have enough data in the array and returns the bytes interpreted as the type
  // Specialisations exist in the cpp file
  template< typename GType > [[nodiscard]]
  auto decode_gtype( const int64_t start_ ) const -> GType {
    assert(start_ + sizeof( GType ) <= bytes->size() );
    const auto p = const_cast< uint8_t * >(bytes->ptr() + start_);
    return *reinterpret_cast< GType * >(p);
  }

  // Template to simplify getting the type from
  template< typename GType > [[nodiscard]]
  auto get_gtype( const int64_t voffset ) const -> GType {
    const uoffset_t field_offset = get_field_offset( voffset );
    if( not field_offset) return {};
    const uoffset_t field_start = start + field_offset;
    return decode_gtype<GType>( field_start );
  }

  // template for struct array access
  // Arrays are vectors of uint32 indexes pointing to the resultant object.
  template< typename GType > [[nodiscard]]
  auto at_gtype( const int64_t voffset, const uint32_t index ) const -> GType {
    // Starting with getting the array
    const uoffset_t array_offset = get_field_start( voffset );
    if( not array_offset) return {};

    // now using the index, get the data, for a POD array, the object is inline.
    const uint64_t array_data    = array_offset + 4;
    const uint64_t element_start = array_data + index * sizeof( GType );

    return decode_gtype<GType>( element_start );
  }
};
} //namespace godot_flatbuffers

#endif //GODOT_FLATBUFFERS_EXTENSION_FLATBUFFER_HPP
