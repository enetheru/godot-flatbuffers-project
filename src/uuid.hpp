#ifndef GODOT_FLATBUFFERS_EXTENSION_FLATBUFFER_TEST_HPP
#define GODOT_FLATBUFFERS_EXTENSION_FLATBUFFER_TEST_HPP

#include "godot_cpp/core/class_db.hpp"
#include <godot_cpp/classes/random_number_generator.hpp>
#include "godot_cpp/classes/hashing_context.hpp"

#include <ranges>
#include <unordered_map>

#include <uuid.h>
#include <uuid_v4.h>

namespace godot_flatbuffers {

using godot::Array;
using godot::PackedByteArray;
using godot::RefCounted;
using godot::String;
using godot::StringName;
using godot::Variant;
using godot::Vector4i;

inline constexpr auto NIL_UUID = "00000000-0000-0000-0000-000000000000";
inline constexpr auto MAX_UUID = "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF";

/**
 * UUID
 *
 * Utility class for generating, parsing, and handling RFC 4122 UUIDs.
 * Provides random (v4), name-based (v3 MD5, v5 SHA-1), and nil UUIDs.
 * Supports conversion between string, byte array, and Vector4i representations.
 * Includes a simple Variant dictionary keyed by UUID.
 *
 * @experimental This API surface may change in future versions.
 */

class UUID final : public RefCounted {
    GDCLASS( UUID, RefCounted ); // NOLINT(*-use-auto)

    std::unordered_map< uuids::uuid, Variant > _variant_map;
    std::unordered_map< StringName, uuids::uuid > _namespace_map;

    // I think I need to provide some default namespaces for the most standard things as described in the RFC9562
    // I want to define constants for use, the NIL and the MAX UUID values for each
    // godot type, String, Vector4i, and PackedByteArray so that the are easily used.
    const uuids::uuid uuid_nul = uuids::uuid::from_string(NIL_UUID).value();

  protected:
    // MARK: BindMethods
    static void _bind_methods();

  public:
    static int64_t hash_uuid( const String &uuid_str );

    static String get_nil_uuid();
    static String get_max_uuid();
    static String get_namespace_dns();
    static String get_namespace_url();
    static String get_namespace_oid();
    static String get_namespace_x500();

    // I have multiple implementations of some functions because I do not
    // yet know the performance characteristics. each implementation will have
    // a '_suffix' denoting its source. The default implementation will be
    // set in _bind_methods

    //TODO Verify the implementation given by grok

    // v3
    /**
    * Note: v3 is included for interoperability but uses MD5, which has known cryptographic weaknesses. Use v5 for new applications.
    * Uses godot's builting Hashing MD5 routines
    */
    static String create_v3(const String& seed, const String& namespace_uuid = String(NIL_UUID));

    // v4
    static String create_v4_rng(); // Uses Godot's builtin RandomNumberGenerator
    static String create_v4_stduuid();
    static String create_v4_uuidv4();

    //FIXME I believe that due to the way gdextension works, I need to return
    // variant here, so that the data is actually available to godot
    static PackedByteArray create_v4_bytes();
    static PackedByteArray create_v4_uuidv4_bytes();
    static PackedByteArray create_v4_stduuid_bytes();

    //v5
    static String create_v5_stduuid(const String &seed, const String &namespace_uuid = String(NIL_UUID));
    static PackedByteArray create_v5_stduuid_bytes(const String& seed, const String &namespace_uuid = String(NIL_UUID));

    // MARK: Conversion
    // │  ___                        _
    // │ / __|___ _ ___ _____ _ _ __(_)___ _ _
    // │| (__/ _ \ ' \ V / -_) '_(_-< / _ \ ' \
    // │ \___\___/_||_\_/\___|_| /__/_\___/_||_|
    // ╰─────────────────────────────────────────
    static String from_bytes( const PackedByteArray &bytes );
    static PackedByteArray to_bytes( const String &uuid_str );

    // MARK: Checks
    // │  ___ _           _
    // │ / __| |_  ___ __| |__ ___
    // │| (__| ' \/ -_) _| / /(_-<
    // │ \___|_||_\___\__|_\_\/__/
    // ╰────────────────────────────

    // is_nil
    static bool is_nil( const String &uuid_str );

    // version
    static int get_version( const String &uuid_str );

    // variant
    static int get_uuid_variant( const String &uuid_str );

    // MARK: Comparison
    // │  ___                          _
    // │ / __|___ _ __  _ __  __ _ _ _(_)___ ___ _ _
    // │| (__/ _ \ '  \| '_ \/ _` | '_| (_-</ _ \ ' \
    // │ \___\___/_|_|_| .__/\__,_|_| |_/__/\___/_||_|
    // ╰───────────────|_|─────────────────────────────

    // equals
    static bool equals( const String &uuid_str1, const String &uuid_str2 );

    // Returns true if the string is a valid UUID (v1–v5 or nil)
    static bool is_valid(const String &uuid_str);

    // MARK: Container
    // │  ___         _        _
    // │ / __|___ _ _| |_ __ _(_)_ _  ___ _ _
    // │| (__/ _ \ ' \  _/ _` | | ' \/ -_) '_|
    // │ \___\___/_||_\__\__,_|_|_||_\___|_|
    // ╰────────────────────────────────────────

    // Custom map
    bool set_variant( const String &uuid_str, const Variant &value );

    Variant get_variant(const String &uuid, const Variant &default_value = Variant()) const;

    bool has_variant( const String &uuid_str ) const;

    bool erase_variant( const String &uuid_str );

    void clear_variants();

    int get_variant_map_size() const;

    Array get_variant_keys();

  private:
    static String bytes_to_hex( const PackedByteArray &bytes );
};


} // namespace godot_flatbuffers

#endif // GODOT_FLATBUFFERS_EXTENSION_FLATBUFFER_TEST_HPP
