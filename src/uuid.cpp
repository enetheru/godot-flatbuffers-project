#include "uuid.hpp"

using namespace godot_flatbuffers;

using godot::ClassDB;
using godot::HashingContext;
using godot::RandomNumberGenerator;
using godot::Ref;

using godot::D_METHOD;

constexpr uuids::uuid nil_stduuid{};

// local string conversion functions for repeated code paths.
static String str( const uuids::uuid from ) { return String( uuids::to_string( from ).c_str() ); }

static String str( const UUIDv4::UUID &from ) { return String( from.str().c_str() ); }

static const char* str(const String& from) { return from.utf8().ptr(); }

static uuids::uuid to_stduuid(const String& from) {
    if(const auto opt = uuids::uuid::from_string(from.utf8().ptr()); opt.has_value() ){
        return opt.value();
    }
    return nil_stduuid;
}

static UUIDv4::UUID to_uuidv4(const String& from) {
    return  UUIDv4::UUID( from.utf8().ptr() );
}


void UUID::_bind_methods()
{
    // Standard default values.
    ClassDB::bind_static_method("UUID", D_METHOD("get_nil_uuid"), &UUID::get_nil_uuid);
    ClassDB::bind_static_method("UUID", D_METHOD("get_max_uuid"), &UUID::get_max_uuid);
    ClassDB::bind_static_method("UUID", D_METHOD("get_namespace_dns"), &UUID::get_namespace_dns);
    ClassDB::bind_static_method("UUID", D_METHOD("get_namespace_url"), &UUID::get_namespace_url);
    ClassDB::bind_static_method("UUID", D_METHOD("get_namespace_oid"), &UUID::get_namespace_oid);
    ClassDB::bind_static_method("UUID", D_METHOD("get_namespace_x500"), &UUID::get_namespace_x500);

    // Add Version Enums
    ClassDB::bind_integer_constant("UUID", "Version", "NONE", 0);
    ClassDB::bind_integer_constant("UUID", "Version", "TIME_BASED", 1);
    ClassDB::bind_integer_constant("UUID", "Version", "DCE_SECURITY", 2);
    ClassDB::bind_integer_constant("UUID", "Version", "NAME_BASED_MD5", 3);
    ClassDB::bind_integer_constant("UUID", "Version", "RANDOM_NUMBER_BASED", 4);
    ClassDB::bind_integer_constant("UUID", "Version", "NAME_BASED_SHA1", 5);

    // Hash (stduuid example)
    ClassDB::bind_static_method("UUID", D_METHOD("hash_uuid", "uuid_str"), &UUID::hash_uuid);

    // │  ___                       _   _
    // │ / __|___ _ _  ___ _ _ __ _| |_(_)___ _ _
    // │| (_ / -_) ' \/ -_) '_/ _` |  _| / _ \ ' \
    // │ \___\___|_||_\___|_| \__,_|\__|_\___/_||_|
    // ╰─────────────────────────────────────────────
    //v3
    ClassDB::bind_static_method("UUID", D_METHOD("create_v3", "name", "namespace"), &UUID::create_v3);
    //v4
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4"), &UUID::create_v4_rng);
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_stduuid"), &UUID::create_v4_stduuid);
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_stduuid_bytes"), &UUID::create_v4_stduuid_bytes);
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_uuidv4"), &UUID::create_v4_uuidv4);
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_uuidv4_bytes"), &UUID::create_v4_uuidv4_bytes);
    //v5
    ClassDB::bind_static_method("UUID", D_METHOD("create_v5_stduuid", "name", "namespace"), &UUID::create_v5_stduuid);
    ClassDB::bind_static_method("UUID", D_METHOD("create_v5_stduuid_bytes", "seed", "namespace"), &UUID::create_v5_stduuid_bytes);

    //
    // │  ___                        _
    // │ / __|___ _ ___ _____ _ _ __(_)___ _ _
    // │| (__/ _ \ ' \ V / -_) '_(_-< / _ \ ' \
    // │ \___\___/_||_\_/\___|_| /__/_\___/_||_|
    // ╰──────────────────────────────────────────
    ClassDB::bind_static_method("UUID", D_METHOD("from_bytes", "bytes"), &UUID::from_bytes);
    ClassDB::bind_static_method("UUID", D_METHOD("to_bytes", "uuid_str"), &UUID::to_bytes);

    //
    // │  ___ _           _
    // │ / __| |_  ___ __| |__ ___
    // │| (__| ' \/ -_) _| / /(_-<
    // │ \___|_||_\___\__|_\_\/__/
    // ╰────────────────────────────
    ClassDB::bind_static_method("UUID", D_METHOD("is_nil", "uuid_str"), &UUID::is_nil);
    ClassDB::bind_static_method("UUID", D_METHOD("get_version", "uuid_str"), &UUID::get_version);
    ClassDB::bind_static_method("UUID", D_METHOD("get_uuid_variant", "uuid_str"), &UUID::get_uuid_variant);

    // │  ___                          _
    // │ / __|___ _ __  _ __  __ _ _ _(_)___ ___ _ _
    // │| (__/ _ \ '  \| '_ \/ _` | '_| (_-</ _ \ ' \
    // │ \___\___/_|_|_| .__/\__,_|_| |_/__/\___/_||_|
    // ╰───────────────|_|─────────────────────────────
    ClassDB::bind_static_method("UUID", D_METHOD("equals", "uuid_str1", "uuid_str2"), &UUID::equals);
    ClassDB::bind_static_method("UUID", D_METHOD("is_valid", "uuid"), &UUID::is_valid);
    //
    // │  ___         _        _
    // │ / __|___ _ _| |_ __ _(_)_ _  ___ _ _
    // │| (__/ _ \ ' \  _/ _` | | ' \/ -_) '_|
    // │ \___\___/_||_\__\__,_|_|_||_\___|_|
    // ╰────────────────────────────────────────
    // Associative container for Variants
    ClassDB::bind_method(D_METHOD("set_variant", "uuid_str", "value"), &UUID::set_variant);
    ClassDB::bind_method(D_METHOD("get_variant", "uuid_str", "default"), &UUID::get_variant);
    ClassDB::bind_method(D_METHOD("has_variant", "uuid_str"), &UUID::has_variant);
    ClassDB::bind_method(D_METHOD("erase_variant", "uuid_str"), &UUID::erase_variant);
    ClassDB::bind_method(D_METHOD("clear_variants"), &UUID::clear_variants);
    ClassDB::bind_method(D_METHOD("get_variant_map_size"), &UUID::get_variant_map_size);
    ClassDB::bind_method(D_METHOD("get_variant_keys"), &UUID::get_variant_keys);
}

String UUID::get_nil_uuid() {
    return "00000000-0000-0000-0000-000000000000";
}

String UUID::get_max_uuid() {
    return "ffffffff-ffff-ffff-ffff-ffffffffffff";
}

String UUID::get_namespace_dns() {
    return String(uuids::to_string(uuids::uuid_namespace_dns).c_str());
}

String UUID::get_namespace_url() {
    return String(uuids::to_string(uuids::uuid_namespace_url).c_str());
}

String UUID::get_namespace_oid() {
    return String(uuids::to_string(uuids::uuid_namespace_oid).c_str());
}

String UUID::get_namespace_x500() {
    return String(uuids::to_string(uuids::uuid_namespace_x500).c_str());
}


int64_t UUID::hash_uuid(const String& uuid_str) {
    const auto uuid = to_stduuid(uuid_str);
    if (uuid == nil_stduuid) return 0;
    return static_cast<int64_t>(std::hash<uuids::uuid>{}(uuid));
}

//MARK: Generation

String UUID::create_v3(const String& seed, const String& namespace_uuid) {
    Ref<HashingContext> ctx;
    ctx.instantiate();
    ctx->start(HashingContext::HASH_MD5);

    const PackedByteArray ns_bytes = namespace_uuid.to_utf8_buffer();
    ctx->update(ns_bytes);

    const PackedByteArray seed_bytes = seed.to_utf8_buffer();
    ctx->update(seed_bytes);

    PackedByteArray hash = ctx->finish();

    hash[6] = (hash[6] & 0x0F) | 0x30; // Version 3 (MD5)
    hash[8] = (hash[8] & 0x3F) | 0x80; // Variant 1

    return bytes_to_hex(hash);
}


String UUID::create_v4_rng() {
    const PackedByteArray bytes = create_v4_bytes();
    return bytes_to_hex(bytes);
}


PackedByteArray UUID::create_v4_bytes() {
    Ref<RandomNumberGenerator> rng;
    rng.instantiate();
    rng->randomize();
    PackedByteArray bytes;
    bytes.resize(16);
    for (int i = 0; i < 16; i++)
    {
        bytes[i] = rng->randi_range(0, 255);
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // Variant 1
    return bytes;
}


String UUID::create_v4_stduuid() {
    std::random_device rd;
    auto seed_data = std::array<int, std::mt19937::state_size>{};
    std::generate(std::begin(seed_data), std::end(seed_data), std::ref(rd));
    std::seed_seq seq(std::begin(seed_data), std::end(seed_data));
    std::mt19937 generator(seq);
    uuids::uuid_random_generator gen{generator};
    return str(gen());
}


String UUID::create_v4_uuidv4() {
    UUIDv4::UUIDGenerator<std::mt19937_64> generator;
    const UUIDv4::UUID uuid = generator.getUUID();
    return str(uuid);
}


PackedByteArray UUID::create_v4_uuidv4_bytes() {
    UUIDv4::UUIDGenerator<std::mt19937_64> gen;
    const UUIDv4::UUID id = gen.getUUID();
    PackedByteArray bytes;
    bytes.resize(16);
    const auto data = id.bytes(); // Assume uuid_v4 has bytes() or equivalent; adjust if needed.
    for (int i = 0; i < 16; ++i)
        bytes[i] = data[i];
    return bytes;
}


PackedByteArray UUID::create_v4_stduuid_bytes() {
    std::random_device rd;
    auto seed_data = std::array<int, std::mt19937::state_size>{};
    std::generate(std::begin(seed_data), std::end(seed_data), std::ref(rd));
    std::seed_seq seq(std::begin(seed_data), std::end(seed_data));
    std::mt19937 generator(seq);
    uuids::uuid_random_generator gen{generator};

    const auto id = gen();
    PackedByteArray bytes;
    bytes.resize(16);
    auto data = id.as_bytes();
    for (int i = 0; i < 16; ++i)
        bytes[i] = static_cast<uint8_t>(data[i]);
    return bytes;
}


String UUID::create_v5_stduuid(const String &seed, const String &namespace_uuid) {
    const auto nsuuid = to_stduuid(namespace_uuid);
    if ( nsuuid == nil_stduuid ) {
        // or return "" / log error – decide on error strategy
        return "";
    }
    auto ns_gen = uuids::uuid_name_generator{nsuuid};
    const auto uuid = ns_gen(str(seed));
    return str(uuid);
}


PackedByteArray UUID::create_v5_stduuid_bytes(const String& seed, const String &namespace_uuid) {
    const auto nsuuid = to_stduuid(namespace_uuid);
    if ( nsuuid == nil_stduuid ) {
        PackedByteArray empty;
        return empty;
    }

    auto ns_gen = uuids::uuid_name_generator{nsuuid};
    const auto uuid = ns_gen(seed.utf8().ptr());
    PackedByteArray bytes;
    bytes.resize(16);
    auto data = uuid.as_bytes();
    for (int i = 0; i < 16; ++i)
        bytes[i] = static_cast<uint8_t>(data[i]);
    return bytes;
}

//MARK: Conversion
// │  ___                        _
// │ / __|___ _ ___ _____ _ _ __(_)___ _ _
// │| (__/ _ \ ' \ V / -_) '_(_-< / _ \ ' \
// │ \___\___/_||_\_/\___|_| /__/_\___/_||_|
// ╰─────────────────────────────────────────

String UUID::from_bytes(const PackedByteArray& bytes) {
    if (bytes.size() != 16) return "";
    std::array<uuids::uuid::value_type, 16> arr;
    for (size_t i = 0; i < 16; ++i) arr[i] = static_cast<uuids::uuid::value_type>(bytes[i]);
    const uuids::uuid id(arr);
    return str(id);
}


PackedByteArray UUID::to_bytes(const String& uuid_str) {
    const auto uuid = to_uuidv4(uuid_str);
    PackedByteArray bytes;
    bytes.resize(16);
    const auto data = uuid.bytes();
    for (int i = 0; i < 16; ++i)
        bytes[i] = static_cast<uint8_t>(data[i]);
    return bytes;
}


bool UUID::is_nil(const String& uuid_str) {
    const auto uuid = to_stduuid(uuid_str);
    return uuid == nil_stduuid;
}


int UUID::get_version(const String& uuid_str) {
    const auto uuid = to_stduuid(uuid_str);
    if ( uuid == nil_stduuid ) {
        return -1;
    }
    return static_cast<int>(uuid.version());
}


int UUID::get_uuid_variant(const String& uuid_str) {
    const auto uuid = to_stduuid(uuid_str);
    if ( uuid == nil_stduuid ) {
        return -1;
    }
    return static_cast<int>(uuid.variant());
}


bool UUID::equals(const String& uuid_str1, const String& uuid_str2) {
    const auto opt1 = uuids::uuid::from_string(str(uuid_str1));
    const auto opt2 = uuids::uuid::from_string(str(uuid_str2));
    return opt1 && opt2 && opt1.value() == opt2.value();
}


bool UUID::is_valid(const String &uuid_str) {
    const auto uuid = to_stduuid(uuid_str);
    return uuid != nil_stduuid;
}


// Variant map – return success
bool UUID::set_variant(const String &uuid, const Variant &value) {
    const auto opt = uuids::uuid::from_string(str(uuid));
    if (!opt) return false;
    _variant_map[opt.value()] = value;
    return true;
}


// Optional: add a get_or_add style if useful later
Variant UUID::get_variant(const String &uuid, const Variant &default_value) const {
    const auto opt = uuids::uuid::from_string(str(uuid));
    if (!opt) return default_value;
    const auto it = _variant_map.find(opt.value());
    return (it != _variant_map.end()) ? it->second : default_value;
}


bool UUID::has_variant(const String &uuid) const {
    const auto opt = uuids::uuid::from_string(str(uuid));
    if (!opt) return false;
    return _variant_map.contains(opt.value());
}


bool UUID::erase_variant(const String &uuid) {
    const auto opt = uuids::uuid::from_string(str(uuid));
    if (!opt) return false;
    return _variant_map.erase(opt.value()) > 0;
}


void UUID::clear_variants() { _variant_map.clear(); }
int UUID::get_variant_map_size() const { return static_cast<int>(_variant_map.size()); }


Array UUID::get_variant_keys() {
    Array keys;
    for (const auto& fst : _variant_map | std::views::keys) {
        keys.append(str(fst));
    }
    return keys;
}


String UUID::bytes_to_hex(const PackedByteArray& bytes)
{
    String hex = "";
    for (int i = 0; i < 16; i++)
    {
        hex += String::num_int64(bytes[i], 16, false).pad_zeros(2).to_lower();
        if (i == 3 || i == 5 || i == 7 || i == 9)
        {
            hex += "-";
        }
    }
    return hex;
}
