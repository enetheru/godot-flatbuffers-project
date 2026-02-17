#include "uuid.hpp"

#include <concepts>
#include <type_traits>

using namespace godot_flatbuffers;

using godot::ClassDB;
using godot::HashingContext;
using godot::RandomNumberGenerator;
using godot::Ref;

using godot::D_METHOD;

constexpr uuids::uuid nil_stduuid{};
constexpr uuids::uuid max_stduuid = uuids::uuid::from_string(MAX_UUID).value();

//MARK: Static

bool UUID::initialised = false;
//RNG Sources
std::mt19937 UUID::mt_rng{};
Ref<RandomNumberGenerator> UUID::godot_rng{};

//UUID generators
uuids::uuid_name_generator UUID::stduuid_dung{nil_stduuid}; // Default Unique Name Generator (DUNG)
uuids::uuid_random_generator UUID::stduuid_urg{mt_rng}; // UUID Random Generator (URG)

std::unique_ptr<uuids::basic_uuid_random_generator<RandomNumberGenerator>> UUID::stduuid_burg{}; // Basic UUID Random Generator (BURG)

UUIDv4::UUIDGenerator<std::mt19937_64> UUID::uuidv4_generator{};

//MARK: Endianness

// ───────────────────────────────────────────────
//  Pick implementation depending on C++ standard
// ───────────────────────────────────────────────

#if __cplusplus >= 202002L
// C++20 or later → use concepts

template<typename T>
concept ByteLike =
    std::same_as<std::remove_cv_t<T>, uint8_t> ||
    std::same_as<std::remove_cv_t<T>, std::byte> ||
    std::same_as<std::remove_cv_t<T>, char>;      // ← added for const char*

template<ByteLike T>
static uint32_t bytes_to_uint32_be(const T* bytes) noexcept {
    // Always treat the byte as unsigned to avoid sign-extension
    // on platforms where plain char is signed.
    const uint8_t b0 = static_cast<uint8_t>(bytes[0]);
    const uint8_t b1 = static_cast<uint8_t>(bytes[1]);
    const uint8_t b2 = static_cast<uint8_t>(bytes[2]);
    const uint8_t b3 = static_cast<uint8_t>(bytes[3]);

    return (static_cast<uint32_t>(b0) << 24) |
           (static_cast<uint32_t>(b1) << 16) |
           (static_cast<uint32_t>(b2) <<  8) |
           static_cast<uint32_t>(b3);
}

#else
// C++17 / C++14 / C++11 fallback — SFINAE

template<typename T,
         typename = std::enable_if_t<
             std::is_same_v<std::remove_cv_t<T>, uint8_t> ||
             std::is_same_v<std::remove_cv_t<T>, std::byte> ||
             std::is_same_v<std::remove_cv_t<T>, char>      // ← added for const char*
         >>
static uint32_t bytes_to_uint32_be(const T* bytes) noexcept {
    const uint8_t b0 = static_cast<uint8_t>(bytes[0]);
    const uint8_t b1 = static_cast<uint8_t>(bytes[1]);
    const uint8_t b2 = static_cast<uint8_t>(bytes[2]);
    const uint8_t b3 = static_cast<uint8_t>(bytes[3]);

    return (static_cast<uint32_t>(b0) << 24) |
           (static_cast<uint32_t>(b1) << 16) |
           (static_cast<uint32_t>(b2) <<  8) |
           static_cast<uint32_t>(b3);
}
#endif


static void uint32_to_bytes_be(const uint32_t value, uint8_t* bytes) {
    bytes[0] = static_cast<uint8_t>(value >> 24);
    bytes[1] = static_cast<uint8_t>(value >> 16);
    bytes[2] = static_cast<uint8_t>(value >> 8);
    bytes[3] = static_cast<uint8_t>(value);
}

//MARK: to_stduuid


static uuids::uuid to_stduuid(const String& from) {
    const auto opt = uuids::uuid::from_string(from.utf8().ptr());
    return !opt.has_value() ? nil_stduuid : opt.value();
}


static uuids::uuid to_stduuid(const PackedByteArray& from) {
    const auto opt = uuids::uuid::from_string(from.ptr());
    return !opt.has_value() ? nil_stduuid : opt.value();
}


static uuids::uuid to_stduuid(const Vector4i& from) {
    std::array<uint8_t, 16> bytes;
    uint32_to_bytes_be(static_cast<uint32_t>(from.x), bytes.data() + 0);
    uint32_to_bytes_be(static_cast<uint32_t>(from.y), bytes.data() + 4);
    uint32_to_bytes_be(static_cast<uint32_t>(from.z), bytes.data() + 8);
    uint32_to_bytes_be(static_cast<uint32_t>(from.w), bytes.data() + 12);
    return uuids::uuid{bytes.begin(), bytes.end()};
}


//MARK: to_uuidv4
// The difficulty and advantage with the UUIDv4 lib is that there is no error checking here.
// So we'd better be sure we are handing it valid data.
static UUIDv4::UUID to_uuidv4(const String& from) {
    return UUIDv4::UUID(from.utf8().ptr());
}

static UUIDv4::UUID to_uuidv4(const PackedByteArray& from) {
    return UUIDv4::UUID(from.ptr());
}

static UUIDv4::UUID to_uuidv4(const Vector4i& from) {
    uint8_t bytes[16];
    std::memcpy(bytes, &from, 16);
    return UUIDv4::UUID(bytes);
}

//MARK: to_String

static String to_string(const uuids::uuid uuid) { return String(uuids::to_string(uuid).c_str()); }

static String to_string(const UUIDv4::UUID &from) { return String(from.str().c_str()); }

static String to_string(const PackedByteArray& bytes) {
    if (bytes.size() != 16) {
        return "";
    }
    const auto uuid = UUIDv4::UUID(bytes.ptr());
    return ::to_string(uuid);
}

//MARK: to_PackedByteArray
// static PackedByteArray to_bytes(const uuids::uuid& uuid) {
//     PackedByteArray bytes;
//     bytes.resize(16);
//     const auto data = uuid.as_bytes();
//     std::copy(std::cbegin(data), std::cend(data), bytes.ptrw());
//     return bytes;
// }

static PackedByteArray to_bytes(const uuids::uuid& uuid) {
    PackedByteArray bytes;
    bytes.resize(16);

    const auto src = uuid.as_bytes();           // span<const std::byte, 16>
    uint8_t* dst = bytes.ptrw();          // unsigned char*

    std::memcpy(dst, src.data(), 16);

    return bytes;
}

static PackedByteArray to_bytes(const UUIDv4::UUID& uuid){
    PackedByteArray bytes;
    bytes.resize(16);
    const auto data = uuid.bytes();
    std::ranges::copy(data, bytes.ptrw());
    return bytes;
}

//MARK: to_Vector4i
static Vector4i to_vector4i(const uuids::uuid& uuid) {
    const auto span = uuid.as_bytes();
    return Vector4i(
        static_cast<int32_t>(bytes_to_uint32_be(span.data() + 0)),
        static_cast<int32_t>(bytes_to_uint32_be(span.data() + 4)),
        static_cast<int32_t>(bytes_to_uint32_be(span.data() + 8)),
        static_cast<int32_t>(bytes_to_uint32_be(span.data() + 12))
    );
}

static Vector4i to_vector4i(const UUIDv4::UUID& uuid) {
    Vector4i v;
    const std::string& bytes = uuid.bytes();
    std::memcpy(&v, bytes.data(), sizeof(Vector4i));
    return v;
}

//MARK: Bind

void UUID::_bind_methods() {
    // Constants
    ClassDB::bind_static_method("UUID", D_METHOD("get_nil_uuid"), &UUID::get_nil_uuid);
    ClassDB::bind_static_method("UUID", D_METHOD("get_max_uuid"), &UUID::get_max_uuid);
    ClassDB::bind_static_method("UUID", D_METHOD("get_namespace_dns"), &UUID::get_namespace_dns);
    ClassDB::bind_static_method("UUID", D_METHOD("get_namespace_url"), &UUID::get_namespace_url);
    ClassDB::bind_static_method("UUID", D_METHOD("get_namespace_oid"), &UUID::get_namespace_oid);
    ClassDB::bind_static_method("UUID", D_METHOD("get_namespace_x500"), &UUID::get_namespace_x500);

    // Enums
    ClassDB::bind_integer_constant("UUID", "Version", "NONE", 0);
    ClassDB::bind_integer_constant("UUID", "Version", "TIME_BASED", 1);
    ClassDB::bind_integer_constant("UUID", "Version", "DCE_SECURITY", 2);
    ClassDB::bind_integer_constant("UUID", "Version", "NAME_BASED_MD5", 3);
    ClassDB::bind_integer_constant("UUID", "Version", "RANDOM_NUMBER_BASED", 4);
    ClassDB::bind_integer_constant("UUID", "Version", "NAME_BASED_SHA1", 5);

    // Hash
    ClassDB::bind_static_method("UUID", D_METHOD("hash_uuid", "uuid_str"), &UUID::hash_uuid);

    // Creators v3
    ClassDB::bind_static_method("UUID", D_METHOD("create_v3_godot_string", "name", "namespace_uuid"), &UUID::create_v3_godot_string, DEFVAL(String(NIL_UUID)));
    ClassDB::bind_static_method("UUID", D_METHOD("create_v3_godot_bytes", "name", "namespace_uuid"), &UUID::create_v3_godot_bytes, DEFVAL(String(NIL_UUID)));

    // v4
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_stduuid_string"), &UUID::create_v4_stduuid_string);
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_stduuid_bytes"), &UUID::create_v4_stduuid_bytes);
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_uuidv4_string"), &UUID::create_v4_uuidv4_string);
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_uuidv4_bytes"), &UUID::create_v4_uuidv4_bytes);

    // v5
    ClassDB::bind_static_method("UUID", D_METHOD("create_v5_stduuid_string", "seed", "namespace_uuid"), &UUID::create_v5_stduuid_string, DEFVAL(String(NIL_UUID)));
    ClassDB::bind_static_method("UUID", D_METHOD("create_v5_stduuid_bytes", "seed", "namespace_uuid"), &UUID::create_v5_stduuid_bytes, DEFVAL(String(NIL_UUID)));

    // Conversions
    ClassDB::bind_static_method("UUID", D_METHOD("from_bytes", "bytes"), &UUID::from_bytes);
    ClassDB::bind_static_method("UUID", D_METHOD("to_bytes", "uuid_str"), &UUID::to_bytes);
    ClassDB::bind_static_method("UUID", D_METHOD("to_vector4i", "uuid_str"), &UUID::to_vector4i);
    ClassDB::bind_static_method("UUID", D_METHOD("from_vector4i", "vec"), &UUID::from_vector4i);

    // Validation
    ClassDB::bind_static_method("UUID", D_METHOD("is_nil", "uuid_str"), &UUID::is_nil);
    ClassDB::bind_static_method("UUID", D_METHOD("get_version", "uuid_str"), &UUID::get_version);
    ClassDB::bind_static_method("UUID", D_METHOD("get_uuid_variant", "uuid_str"), &UUID::get_uuid_variant);
    ClassDB::bind_static_method("UUID", D_METHOD("equals", "uuid_str1", "uuid_str2"), &UUID::equals);
    ClassDB::bind_static_method("UUID", D_METHOD("is_valid", "uuid_str"), &UUID::is_valid);

    // Variant map
    ClassDB::bind_method(D_METHOD("set_variant", "uuid_str", "value"), &UUID::set_variant);
    ClassDB::bind_method(D_METHOD("get_variant", "uuid_str", "default_value"), &UUID::get_variant, DEFVAL(Variant()));
    ClassDB::bind_method(D_METHOD("has_variant", "uuid_str"), &UUID::has_variant);
    ClassDB::bind_method(D_METHOD("erase_variant", "uuid_str"), &UUID::erase_variant);
    ClassDB::bind_method(D_METHOD("clear_variants"), &UUID::clear_variants);
    ClassDB::bind_method(D_METHOD("get_variant_map_size"), &UUID::get_variant_map_size);
    ClassDB::bind_method(D_METHOD("get_variant_keys"), &UUID::get_variant_keys);
}

//MARK: Generation v3

String UUID::create_v3_godot_string(const String& seed, const String& namespace_uuid) {
    const auto bytes = create_v3_godot_bytes(seed, namespace_uuid);
    return ::to_string(create_v3_godot_bytes(seed, namespace_uuid));
}

PackedByteArray UUID::create_v3_godot_bytes(const String& seed, String namespace_uuid) {
    if( namespace_uuid.is_empty() || !is_valid(namespace_uuid) ) {
        namespace_uuid = get_nil_uuid();
    }
    Ref<HashingContext> ctx;
    ctx.instantiate();
    ctx->start(HashingContext::HASH_MD5);
    const PackedByteArray ns_bytes = to_bytes(namespace_uuid);
    ctx->update(ns_bytes);
    const PackedByteArray seed_bytes = seed.to_utf8_buffer();
    ctx->update(seed_bytes);
    PackedByteArray hash = ctx->finish();
    if (hash.size() != 16) {
        return {};
    }
    hash[6] = (hash[6] & 0x0F) | 0x30; // Version 3 (MD5)
    hash[8] = (hash[8] & 0x3F) | 0x80; // Variant 1
    return hash;
}

//MARK: Generation v4

String UUID::create_v4_stduuid_string() { return ::to_string(stduuid_urg()); }

PackedByteArray UUID::create_v4_stduuid_bytes() { return ::to_bytes(stduuid_urg()); }

String UUID::create_v4_uuidv4_string() { return ::to_string(uuidv4_generator.getUUID()); }

PackedByteArray UUID::create_v4_uuidv4_bytes() { return ::to_bytes(uuidv4_generator.getUUID()); }

//MARK: Generation v5

String UUID::create_v5_stduuid_string(const String &seed, const String &namespace_uuid_str) {
    if (namespace_uuid_str == String(NIL_UUID)) {
        const auto uuid = stduuid_dung(seed.utf8().ptr());
        return ::to_string(uuid);
    }
    if (!is_valid(namespace_uuid_str)) {
        return "";
    }
    const auto ns_uuid = uuids::uuid::from_string(namespace_uuid_str.utf8().ptr()).value();
    auto ns_ung = uuids::uuid_name_generator{ns_uuid};
    const auto uuid = ns_ung(seed.utf8().ptr());
    return ::to_string(uuid);
}

PackedByteArray UUID::create_v5_stduuid_bytes(const String &seed, const String &namespace_uuid_str) {
    if (namespace_uuid_str == String(NIL_UUID)) {
        const auto uuid = stduuid_dung(seed.utf8().ptr());
        return ::to_bytes(uuid);
    }
    if (!is_valid(namespace_uuid_str)) {
        return {};
    }
    const auto ns_uuid = uuids::uuid::from_string(namespace_uuid_str.utf8().ptr()).value();
    auto ns_ung = uuids::uuid_name_generator{ns_uuid};
    const auto uuid = ns_ung(seed.utf8().ptr());
    return ::to_bytes(uuid);
}

//MARK: Conversion


String UUID::from_bytes(const PackedByteArray& bytes) {
    if (bytes.size() != 16) {
        return "";
    }
    std::array<uint8_t, 16> arr;
    std::memcpy(arr.data(), bytes.ptr(), 16);

    return ::to_string(uuids::uuid(arr));
}

PackedByteArray UUID::to_bytes(const String& uuid_str) {
    const auto opt = uuids::uuid::from_string(uuid_str.utf8().ptr());
    if (!opt.has_value()) return {};
    const auto uuid = opt.value();
    return ::to_bytes(uuid);
}

Vector4i UUID::to_vector4i(const String &uuid_str) {
    if (!is_valid(uuid_str)) {
        return Vector4i(0, 0, 0, 0);
    }
    const auto uuid = to_stduuid(uuid_str);
    return ::to_vector4i(uuid);
}

String UUID::from_vector4i(const Vector4i& uuid_vec) {
    const uuids::uuid uuid = ::to_stduuid(uuid_vec);
    return ::to_string(uuid);
}


//MARK: Checks

bool UUID::is_valid(const String &uuid_str) {
    const auto opt = uuids::uuid::from_string(uuid_str.utf8().ptr());
    return opt.has_value() && opt.value() != nil_stduuid;
}

bool UUID::is_nil(const String& uuid_str) {
    const auto opt = uuids::uuid::from_string(uuid_str.utf8().ptr());
    if (!opt.has_value()) return false;
    return opt.value() == nil_stduuid;
}

int UUID::get_version(const String& uuid_str) {
    if (!is_valid(uuid_str)) return -1;
    const auto opt = uuids::uuid::from_string(uuid_str.utf8().ptr());
    return static_cast<int>(opt.value().version());
}

int UUID::get_uuid_variant(const String& uuid_str) {
    if (!is_valid(uuid_str)) return -1;
    const auto opt = uuids::uuid::from_string(uuid_str.utf8().ptr());
    return static_cast<int>(opt.value().variant());
}

bool UUID::equals(const String& uuid_str1, const String& uuid_str2) {
    const auto opt1 = uuids::uuid::from_string(uuid_str1.utf8().ptr());
    const auto opt2 = uuids::uuid::from_string(uuid_str2.utf8().ptr());
    return opt1.has_value() && opt2.has_value() && opt1.value() == opt2.value();
}

int64_t UUID::hash_uuid(const String &uuid_str) {
    return static_cast<int64_t>(std::hash<uuids::uuid>{}(to_stduuid(uuid_str)));
}

//MARK: Association

bool UUID::set_variant(const String &uuid_str, const Variant &value) {
    const auto opt = uuids::uuid::from_string(uuid_str.utf8().ptr());
    if (!opt.has_value()) return false;
    _variant_map[opt.value()] = value;
    return true;
}

Variant UUID::get_variant(const String &uuid_str, const Variant &default_value) const {
    const auto opt = uuids::uuid::from_string(uuid_str.utf8().ptr());
    if (!opt.has_value()) return default_value;
    const auto it = _variant_map.find(opt.value());
    return (it != _variant_map.end()) ? it->second : default_value;
}

bool UUID::has_variant(const String &uuid_str) const {
    const auto opt = uuids::uuid::from_string(uuid_str.utf8().ptr());
    if (!opt.has_value()) return false;
    return _variant_map.contains(opt.value());
}

bool UUID::erase_variant(const String &uuid_str) {
    const auto opt = uuids::uuid::from_string(uuid_str.utf8().ptr());
    if (!opt.has_value()) return false;
    return _variant_map.erase(opt.value()) > 0;
}

void UUID::clear_variants() { _variant_map.clear(); }

int UUID::get_variant_map_size() const { return static_cast<int>(_variant_map.size()); }

Array UUID::get_variant_keys() const
{
    Array keys;
    for (const auto& key : _variant_map | std::views::keys) {
        keys.append(::to_string(key));
    }
    return keys;
}
