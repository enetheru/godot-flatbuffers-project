#ifndef GODOT_FLATBUFFERS_EXTENSION_UUID_HPP
#define GODOT_FLATBUFFERS_EXTENSION_UUID_HPP

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
using godot::RandomNumberGenerator;
using godot::Vector4i;

inline constexpr auto NIL_UUID = "00000000-0000-0000-0000-000000000000";
inline constexpr auto MAX_UUID = "ffffffff-ffff-ffff-ffff-ffffffffffff";
inline constexpr auto DNS_UUID = "6ba7b810-9dad-11d1-80b4-00c04fd430c8";
inline constexpr auto URL_UUID = "6ba7b811-9dad-11d1-80b4-00c04fd430c8";
inline constexpr auto OID_UUID = "6ba7b812-9dad-11d1-80b4-00c04fd430c8";
inline constexpr auto x500_UUID = "6ba7b814-9dad-11d1-80b4-00c04fd430c8";

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
    GDCLASS(UUID, RefCounted);

    static bool initialised;
    //RNG Sources
    static std::mt19937 mt_rng;
    static godot::Ref<RandomNumberGenerator> godot_rng;
    //UUID generators
    static uuids::uuid_name_generator stduuid_dung; // Default Unique Name Generator (DUNG)
    static std::unique_ptr<uuids::basic_uuid_random_generator<RandomNumberGenerator>> stduuid_burg; // Basic UUID Random Generator (BURG)
    static UUIDv4::UUIDGenerator<std::mt19937_64> uuidv4_generator;
    static uuids::uuid_random_generator stduuid_urg; // UUID Random Generator (URG)

    std::unordered_map<uuids::uuid, Variant> _variant_map;

protected:
    static void _bind_methods();

public:

    // ───────────────────────────────────────────────
    //  Namespace constants (RFC 9562 recommended)
    // ───────────────────────────────────────────────
    static String get_nil_uuid()      { return NIL_UUID; }
    static String get_max_uuid()      { return MAX_UUID; }
    static String get_namespace_dns() { return DNS_UUID; }
    static String get_namespace_url() { return URL_UUID; }
    static String get_namespace_oid() { return OID_UUID; }
    static String get_namespace_x500(){ return x500_UUID; }

    // ───────────────────────────────────────────────
    //  Hashing
    // ───────────────────────────────────────────────
    static int64_t hash_uuid(const String &uuid_str);

    // ───────────────────────────────────────────────
    //  Creators
    // ───────────────────────────────────────────────

    // v3 (Godot MD5 only)
    static String create_v3_godot_string(
        const String& seed,
        const String& namespace_uuid = String(NIL_UUID)
    );
    static PackedByteArray create_v3_godot_bytes(
        const String& seed,
        String namespace_uuid = String(NIL_UUID)
    );

    // String / Bytes wrappers (unchanged naming)
    static String create_v4_stduuid_string();
    static PackedByteArray create_v4_stduuid_bytes();

    static String create_v4_uuidv4_string();
    static PackedByteArray create_v4_uuidv4_bytes();

    static String create_v5_stduuid_string(
        const String &seed,
        const String &namespace_uuid_str = String(NIL_UUID)
    );
    static PackedByteArray create_v5_stduuid_bytes(
        const String &seed,
        const String &namespace_uuid_str = String(NIL_UUID)
    );

    // ───────────────────────────────────────────────
    //  Conversion
    // ───────────────────────────────────────────────
    // from
    static String from_bytes(const PackedByteArray &bytes);
    static String from_vector4i(const Vector4i& uuid_vec);
    // to
    static Vector4i to_vector4i(const String &uuid_str);
    static PackedByteArray to_bytes(const String &uuid_str);

    // ───────────────────────────────────────────────
    //  Validation / Inspection
    // ───────────────────────────────────────────────
    static bool is_nil(const String &uuid_str);
    static int get_version(const String &uuid_str);
    static int get_uuid_variant(const String &uuid_str);
    static bool equals(const String &uuid_str1, const String &uuid_str2);
    static bool is_valid(const String &uuid_str);

    // ───────────────────────────────────────────────
    //  Variant map
    // ───────────────────────────────────────────────
    bool set_variant(const String &uuid_str, const Variant &value);
    Variant get_variant(const String &uuid_str, const Variant &default_value = Variant()) const;
    bool has_variant(const String &uuid_str) const;
    bool erase_variant(const String &uuid_str);
    void clear_variants();
    int get_variant_map_size() const;
    Array get_variant_keys() const;
};
    ;
} // namespace godot_flatbuffers

#endif
