#include "uuid.hpp"

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

//MARK: ToUUIDFrom

static uuids::uuid to_stduuid(const String& from) {
    if (auto opt = uuids::uuid::from_string(from.utf8().ptr()); opt.has_value()) {
        return opt.value();
    }
    return nil_stduuid;
}

static UUIDv4::UUID to_uuidv4(const String& from) {
    return UUIDv4::UUID(from.utf8().ptr());
}

static UUIDv4::UUID to_uuidv4(const PackedByteArray& from) {
    return UUIDv4::UUID(from.ptr());
}

//MARK: FromUUIDto

static String to_string(const uuids::uuid uuid) { return String(uuids::to_string(uuid).c_str()); }

static String to_string(const UUIDv4::UUID &from) { return String(from.str().c_str()); }

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


static String bytes_to_uuid_string(const PackedByteArray& bytes) {
    if (bytes.size() != 16) {
        return "";
    }

    static constexpr char hex_chars[] = "0123456789abcdef";

    godot::CharString cs;
    cs.resize(37);  // 36 chars + null terminator
    char* ptr = cs.ptrw();

    int idx = 0;
    for (int i = 0; i < 16; ++i) {
        uint8_t b = bytes[i];
        ptr[idx++] = hex_chars[(b >> 4) & 0x0F];
        ptr[idx++] = hex_chars[b & 0x0F];
        if (i == 3 || i == 5 || i == 7 || i == 9) {
            ptr[idx++] = '-';
        }
    }
    ptr[idx] = '\0';

    return String(cs);
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

String UUID::create_v3_godot_string(const String& seed, const String& namespace_uuid_str) {
    const auto bytes = create_v3_godot_bytes(seed, namespace_uuid_str);
    return bytes_to_uuid_string(create_v3_godot_bytes(seed, namespace_uuid_str));
}

PackedByteArray UUID::create_v3_godot_bytes(const String& seed, const String& namespace_uuid_str) {
    String namespace_uuid = namespace_uuid_str;
    if (!is_valid(namespace_uuid)) {
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
    auto opt = uuids::uuid::from_string(uuid_str.utf8().ptr());
    if (!opt.has_value()) return false;
    _variant_map[opt.value()] = value;
    return true;
}

Variant UUID::get_variant(const String &uuid_str, const Variant &default_value) const {
    auto opt = uuids::uuid::from_string(uuid_str.utf8().ptr());
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
