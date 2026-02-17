@tool
extends TestBase

# ------------------------------------------------------------------------------
# Compares stduuid v4 vs uuidv4 v4 generators
# Checks format, version, variant, uniqueness over many samples,
# and that they are different implementations
#
# Key points / trade-offs
#
# - Checks version (4) and variant (1)
# — both should follow RFC 9562 rules
# - Tests for collisions **between** the two generators (should be ~0)
# - Tests uniqueness **within** each generator (should be 100% over 1000 samples)
# - Includes basic string format check via version/variant
# - Logs rare same-byte cases (statistically possible but very unlikely)
# - SAMPLE_COUNT=1000 is a compromise between test time and collision detection
#   strength
#
# adjust SAMPLE_COUNT higher (e.g. 5000–10000) for stronger statistical confidence.
#
# TODO
# compare statistical distribution (e.g. byte histogram, position of 1-bits, etc.)
# add timing comparison.
# ------------------------------------------------------------------------------

const SAMPLE_COUNT = 1000

func _run_test() -> int:
	# Basic format & properties
	var std_str = UUID.create_v4_stduuid_string()
	var v4_str  = UUID.create_v4_uuidv4_string()

	runcode &= TEST_EQ(std_str.length(), 36, "stduuid string length == 36")
	runcode &= TEST_EQ(v4_str.length(),  36, "uuidv4  string length == 36")

	runcode &= TEST_TRUE(std_str.begins_with("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".substr(0,8).replace("x","")),
						 "stduuid looks like v4 (version byte)")
	runcode &= TEST_TRUE(v4_str.begins_with("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".substr(0,8).replace("x","")),
						 "uuidv4 looks like v4 (version byte)")

	runcode &= TEST_EQ(UUID.get_version(std_str), 4, "stduuid version == 4")
	runcode &= TEST_EQ(UUID.get_version(v4_str),  4, "uuidv4 version == 4")

	runcode &= TEST_EQ(UUID.get_uuid_variant(std_str), 1, "stduuid variant == 1 (RFC 9562)")
	runcode &= TEST_EQ(UUID.get_uuid_variant(v4_str),  1, "uuidv4 variant == 1 (RFC 9562)")

	# Check that they are actually different implementations
	var seen = {}
	var collision_count = 0
	var different_count = 0

	for i in range(SAMPLE_COUNT):
		var a = UUID.create_v4_stduuid_string()
		var b = UUID.create_v4_uuidv4_string()

		if a == b:
			collision_count += 1
		else:
			different_count += 1

		seen[a] = true
		seen[b] = true

	runcode &= TEST_EQ(collision_count, 0,
					   "No collisions between stduuid and uuidv4 in %d samples" % SAMPLE_COUNT)
	runcode &= TEST_TRUE(different_count >= SAMPLE_COUNT * 0.95,
						 "Most generated uuids are different (expected ~100%)")

	# Check uniqueness within each generator
	var std_set = {}
	var v4_set  = {}

	for i in range(SAMPLE_COUNT):
		std_set[UUID.create_v4_stduuid_string()] = true
		v4_set[UUID.create_v4_uuidv4_string()]   = true

	runcode &= TEST_EQ(std_set.size(), SAMPLE_COUNT,
					   "stduuid generator produced %d unique values" % SAMPLE_COUNT)
	runcode &= TEST_EQ(v4_set.size(), SAMPLE_COUNT,
					   "uuidv4 generator produced %d unique values" % SAMPLE_COUNT)

	# byte-level comparison of a few samples
	for i in range(5):
		var std_bytes = UUID.create_v4_stduuid_bytes()
		var v4_bytes  = UUID.create_v4_uuidv4_bytes()

		runcode &= TEST_EQ(std_bytes.size(), 16, "stduuid bytes size")
		runcode &= TEST_EQ(v4_bytes.size(),  16, "uuidv4 bytes size")

		# Very unlikely they match, but possible — we just log
		if std_bytes == v4_bytes:
			logp("[color=yellow]Rare: same 16 bytes from both generators (sample %d)[/color]" % i)

	logp("Compared %d pairs — collision rate between generators: %s" %
		 [SAMPLE_COUNT, str(collision_count)])

	return runcode
