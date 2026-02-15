#include "uuid.hpp"

using namespace godot_flatbuffers;

using godot::ClassDB;
using godot::HashingContext;
using godot::RandomNumberGenerator;
using godot::Ref;

using godot::D_METHOD;


template <typename... Args>
static void print( const Args &...p_args) {
    godot::UtilityFunctions::print( p_args... );
}


constexpr uuids::uuid nil_stduuid{};
constexpr uuids::uuid max_stduuid = uuids::uuid::from_string(MAX_UUID).value();

//MARK: Static

// │ ___ _        _   _
// │/ __| |_ __ _| |_(_)__
// │\__ \  _/ _` |  _| / _|
// │|___/\__\__,_|\__|_\__|
// ╰────────────────────────
bool UUID::initialised = false;
//RNG Sources
std::mt19937 UUID::mt_rng{};
Ref<RandomNumberGenerator> UUID::godot_rng{};

//UUID generators
uuids::uuid_name_generator UUID::stduuid_dung{nil_stduuid}; // Default Unique Name Generator (DUNG)
uuids::uuid_random_generator UUID::stduuid_urg{mt_rng}; // UUID Random Generator (URG)

std::unique_ptr<uuids::basic_uuid_random_generator<RandomNumberGenerator>> UUID::stduuid_burg{}; // Basic UUID Random Generator (BURG)

UUIDv4::UUIDGenerator<std::mt19937_64> UUID::uuidv4_generator{};

// local string conversion functions for repeated code paths.
static const char* str(const String& from) { return from.utf8().ptr(); }

static String bytes_to_hex(const PackedByteArray& bytes) {
    if (bytes.size() != 16) return "";
    static const char hex_chars[] = "0123456789abcdef";
    godot::CharString cs;
    cs.resize(37);
    char *ptr = cs.ptrw();
    int idx = 0;
    for (int i = 0; i < 16; ++i) {
        uint8_t b = bytes[i];
        ptr[idx++] = hex_chars[(b >> 4) & 0x0F];
        ptr[idx++] = hex_chars[b & 0x0F];
        if (i == 3 || i == 5 || i == 7 || i == 9) {
            ptr[idx++] = '-';
        }
    }
    ptr[idx] = 0;
    return String(cs);
}

//MARK: ToUUIDFrom
// │ _____    _   _ _   _ ___ ___   __
// │|_   _|__| | | | | | |_ _|   \ / _|_ _ ___ _ __
// │  | |/ _ \ |_| | |_| || || |) |  _| '_/ _ \ '  \   _   _   _
// │  |_|\___/\___/ \___/|___|___/|_| |_| \___/_|_|_| (_) (_) (_)
// ╰───────────────────────────────────────────────────────────────
static uuids::uuid to_stduuid(const String& from) {
    if(const auto opt = uuids::uuid::from_string(from.utf8().ptr()); opt.has_value() ){
        return opt.value();
    }
    return nil_stduuid;
}

// static uuids::uuid to_stduuid(const PackedByteArray& from) {
//     // std::array<uint8_t, 16> bytes{};
//     // uuids::uuid();
//     if(const auto opt = uuids::uuid::from_string(from.utf8().ptr()); opt.has_value() ){
//         return opt.value();
//     }
//     return nil_stduuid;
// }

static UUIDv4::UUID to_uuidv4(const String& from) {
    return  UUIDv4::UUID( from.utf8().ptr() );
}

static UUIDv4::UUID to_uuidv4(const PackedByteArray& from) {
    return  UUIDv4::UUID( from.ptr() );
}

//MARK: FromUUIDto
// │ ___             _   _ _   _ ___ ___  _
// │| __| _ ___ _ __| | | | | | |_ _|   \| |_ ___
// │| _| '_/ _ \ '  \ |_| | |_| || || |) |  _/ _ \  _   _   _
// │|_||_| \___/_|_|_\___/ \___/|___|___/ \__\___/ (_) (_) (_)
// ╰────────────────────────────────────────────────────────────

static String to_string( const uuids::uuid uuid ) { return String( uuids::to_string( uuid ).c_str() ); }

static String to_string( const UUIDv4::UUID &from ) { return String( from.str().c_str() ); }

static PackedByteArray to_bytes(const uuids::uuid& uuid) {
    PackedByteArray bytes;
    bytes.resize(16);
    const auto data = uuid.as_bytes();
    for (int i = 0; i < 16; ++i)
        bytes[i] = static_cast<uint8_t>(data[i]);
    return bytes;
}


static PackedByteArray to_bytes(const UUIDv4::UUID& uuid){
    PackedByteArray bytes;
    bytes.resize(16);
    const auto data = uuid.bytes();
    for (int i = 0; i < 16; ++i)
        bytes[i] = data[i];
    return bytes;
}

// │ _   _ _   _ ___ ___
// │| | | | | | |_ _|   \
// │| |_| | |_| || || |) |
// │ \___/ \___/|___|___/
// ╰───────────────────────

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

    // v3
    ClassDB::bind_static_method("UUID", D_METHOD("create_v3_godot_string", "name", "namespace_uuid"), &UUID::create_v3_godot_string, DEFVAL(String(NIL_UUID)));
    ClassDB::bind_static_method("UUID", D_METHOD("create_v3_godot_bytes", "name", "namespace_uuid"), &UUID::create_v3_godot_bytes, DEFVAL(String(NIL_UUID)));

    // v4
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_stduuid_string"), &UUID::create_v4_stduuid_string);
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_uuidv4_string"), &UUID::create_v4_uuidv4_string);

    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_stduuid_bytes"), &UUID::create_v4_stduuid_bytes);
    ClassDB::bind_static_method("UUID", D_METHOD("create_v4_uuidv4_bytes"), &UUID::create_v4_uuidv4_bytes);

    // v5
    ClassDB::bind_static_method("UUID", D_METHOD("create_v5_stduuid_string", "name", "namespace_uuid"), &UUID::create_v5_stduuid_string, DEFVAL(String(NIL_UUID)));
    ClassDB::bind_static_method("UUID", D_METHOD("create_v5_stduuid_bytes", "name", "namespace_uuid"), &UUID::create_v5_stduuid_bytes, DEFVAL(String(NIL_UUID)));


    // │  ___                        _
    // │ / __|___ _ ___ _____ _ _ __(_)___ _ _
    // │| (__/ _ \ ' \ V / -_) '_(_-< / _ \ ' \
    // │ \___\___/_||_\_/\___|_| /__/_\___/_||_|
    // ╰──────────────────────────────────────────
    ClassDB::bind_static_method("UUID", D_METHOD("from_bytes", "bytes"), &UUID::from_bytes);
    ClassDB::bind_static_method("UUID", D_METHOD("to_bytes", "uuid_str"), &UUID::to_bytes);


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


    // │  ___         _        _
    // │ / __|___ _ _| |_ __ _(_)_ _  ___ _ _
    // │| (__/ _ \ ' \  _/ _` | | ' \/ -_) '_|
    // │ \___\___/_||_\__\__,_|_|_||_\___|_|
    // ╰────────────────────────────────────────
    ClassDB::bind_method(D_METHOD("set_variant", "uuid_str", "value"), &UUID::set_variant);
    ClassDB::bind_method(D_METHOD("get_variant", "uuid_str", "default"), &UUID::get_variant, DEFVAL(Variant()));
    ClassDB::bind_method(D_METHOD("has_variant", "uuid_str"), &UUID::has_variant);
    ClassDB::bind_method(D_METHOD("erase_variant", "uuid_str"), &UUID::erase_variant);
    ClassDB::bind_method(D_METHOD("clear_variants"), &UUID::clear_variants);
    ClassDB::bind_method(D_METHOD("get_variant_map_size"), &UUID::get_variant_map_size);
    ClassDB::bind_method(D_METHOD("get_variant_keys"), &UUID::get_variant_keys);
}


UUID::UUID() { print("Constructor"); }


// ReSharper disable once CppMemberFunctionMayBeStatic
void UUID::_notification(const int p_what ) {
    if( p_what == NOTIFICATION_POSTINITIALIZE ) {
        if( initialised ) return;
        initialised = true;
        godot_rng.instantiate();

        using sburg_grng = uuids::basic_uuid_random_generator<RandomNumberGenerator>;
        stduuid_burg = std::make_unique<sburg_grng>(sburg_grng{*godot_rng.ptr()});
    }
}


int64_t UUID::hash_uuid(const String& uuid_str) {
    const auto uuid = to_stduuid(uuid_str);
    if (uuid == nil_stduuid) return 0;
    return static_cast<int64_t>(std::hash<uuids::uuid>{}(uuid));
}

//MARK: Generation v3

String UUID::create_v3_godot_string(const String& seed, const String& namespace_uuid_str) {
    PackedByteArray bytes = create_v3_godot_bytes(seed, namespace_uuid_str);
    if (bytes.is_empty()) {
        return "";
    }
    return bytes_to_hex(bytes);
}

PackedByteArray UUID::create_v3_godot_bytes(const String& seed, const String& namespace_uuid_str) {
    String namespace_uuid = namespace_uuid_str;
    if (!is_valid(namespace_uuid)) {
        namespace_uuid = get_nil_uuid();
    }
    Ref<HashingContext> ctx;
    ctx.instantiate();
    ctx->start(HashingContext::HASH_MD5);
    PackedByteArray ns_bytes = to_bytes(namespace_uuid);
    if (!ns_bytes.is_empty()) {
        ctx->update(ns_bytes);
    }
    PackedByteArray seed_bytes = seed.to_utf8_buffer();
    if (!seed_bytes.is_empty()) {
        ctx->update(seed_bytes);
    }
    PackedByteArray hash = ctx->finish();
    if (hash.size() != 16) {
        return {};
    }
    hash[6] = (hash[6] & 0x0F) | 0x30; // Version 3 (MD5)
    hash[8] = (hash[8] & 0x3F) | 0x80; // Variant 1
    return hash;
}


String UUID::create_v4_stduuid_string() { return ::to_string(stduuid_urg()); }


String UUID::create_v4_uuidv4_string() { return ::to_string(uuidv4_generator.getUUID()); }


PackedByteArray UUID::create_v4_stduuid_bytes() { return ::to_bytes(stduuid_urg()); }


PackedByteArray UUID::create_v4_uuidv4_bytes() { return ::to_bytes(uuidv4_generator.getUUID()); }


//MARK: Generation v5
String UUID::create_v5_stduuid_string( const String &seed, const String &namespace_uuid_str) {
    // no namespace specified use the default nil uuid.
    if( namespace_uuid_str ==  String(NIL_UUID) ) {
        const auto uuid = stduuid_dung(str(seed));
        return ::to_string(uuid);
    }
    // verify string is a valid uuid
    if(const auto ns_str = str(namespace_uuid_str); uuids::uuid::is_valid_uuid( ns_str ))
    {
        const auto ns_uuid = to_stduuid( namespace_uuid_str);
        auto ns_ung = uuids::uuid_name_generator{ns_uuid};
        const auto uuid = ns_ung(str(seed));
        return::to_string(uuid);
    }
    return "";
}

PackedByteArray UUID::create_v5_stduuid_bytes( const String &seed, const String &namespace_uuid_str) {
    // no namespace specified use the default nil uuid.
    if( namespace_uuid_str ==  String(NIL_UUID) ) {
        const auto uuid = stduuid_dung(str(seed));
        return ::to_bytes(uuid);
    }
    // verify string is a valid uuid
    if(const auto ns_str = str(namespace_uuid_str); uuids::uuid::is_valid_uuid( ns_str ))
    {
        const auto ns_uuid = to_stduuid( namespace_uuid_str);
        auto ns_ung = uuids::uuid_name_generator{ns_uuid};
        const auto uuid = ns_ung(str(seed));
        return::to_bytes(uuid);
    }
    return {};
}


//MARK: Conversion
// │  ___                        _
// │ / __|___ _ ___ _____ _ _ __(_)___ _ _
// │| (__/ _ \ ' \ V / -_) '_(_-< / _ \ ' \
// │ \___\___/_||_\_/\___|_| /__/_\___/_||_|
// ╰─────────────────────────────────────────


String UUID::from_bytes(const PackedByteArray& bytes) {
    ::to_uuidv4(bytes);
    if (bytes.size() != 16) return "";
    std::array<uuids::uuid::value_type, 16> arr;
    for (size_t i = 0; i < 16; ++i) arr[i] = static_cast<uuids::uuid::value_type>(bytes[i]);
    const uuids::uuid id(arr);
    return ::to_string(id);
}


// PackedByteArray UUID::to_bytes(const String& uuid_str) {
//     const auto uuid = to_uuidv4(uuid_str);
//     PackedByteArray bytes;
//     bytes.resize(16);
//     const auto data = uuid.bytes();
//     for (int i = 0; i < 16; ++i)
//         bytes[i] = static_cast<uint8_t>(data[i]);
//     return bytes;
// }

PackedByteArray UUID::to_bytes(const String& uuid_str) {
    const auto uuid = to_stduuid(uuid_str);
    if( uuid == nil_stduuid )return {};

    PackedByteArray bytes;
    bytes.resize(16);
    auto data = uuid.as_bytes();  // returns std::array<uint8_t,16> in network order
    for (int i = 0; i < 16; ++i) {
        bytes[i] = static_cast<uint8_t>(data[i]);
    }
    return bytes;
}


//MARK: Checks

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

//MARK: Association
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
        keys.append(::to_string(fst));
    }
    return keys;
}


