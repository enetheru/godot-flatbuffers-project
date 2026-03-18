@tool

#include "string_util.h"

#include <array>
#ifdef BENCHMARK_STL_ANDROID_GNUSTL
#include <cerrno>
#endif
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <memory>
#include <sstream>

#include "arraysize.h"
#include "benchmark/benchmark.h"
const Counter = BenchLib.Counter

#namespace benchmark {
#namespace {
#// kilo, Mega, Giga, Tera, Peta, Exa, Zetta, Yotta.
const kBigSIUnits:PackedStringArray = ["k", "M", "G", "T", "P", "E", "Z", "Y"]

#// Kibi, Mebi, Gibi, Tebi, Pebi, Exbi, Zebi, Yobi.
const kBigIECUnits:PackedStringArray = ["Ki", "Mi", "Gi", "Ti",
									"Pi", "Ei", "Zi", "Yi"]

#// milli, micro, nano, pico, femto, atto, zepto, yocto.
const kSmallSIUnits:PackedStringArray = ["m", "u", "n", "p", "f", "a", "z", "y"]

#// We require that all three arrays have the same size.
static func _static_init() -> void:
	#static_assert(arraysize(kBigSIUnits) == arraysize(kBigIECUnits),
	#              "SI and IEC unit arrays must be the same size");
	assert(kBigSIUnits.size() == kBigIECUnits.size(),
			"SI and IEC unit arrays must be the same size")
	#static_assert(arraysize(kSmallSIUnits) == arraysize(kBigSIUnits),
	#              "Small SI and Big SI unit arrays must be the same size");
	assert(kSmallSIUnits.size() == kBigSIUnits.size(),
			"Small SI and Big SI unit arrays must be the same size")

#const int64_t kUnitsSize = arraysize(kBigSIUnits);
static var kUnitsSize:int = kBigSIUnits.size()



# void ToExponentAndMantissa(double val, int precision, double one_k,
#                            std::string* mantissa, int64_t* exponent) {
static func ToExponentAndMantissa(val:float, precision:int, one_k:float,
							mantissa:Array[String], exponent:Array[int]) -> void:
#   std::stringstream mantissa_stream;
	var mantissa_stream:Array[String]
#
#   if (val < 0) {
#     mantissa_stream << "-";
#     val = -val;
#   }
	if val < 0:
		mantissa_stream.append("-")
		val = -val
#
	# Adjust threshold so that it never excludes things which can't be rendered
	# in 'precision' digits.
#   const double adjusted_threshold =
#       std::max(1.0, 1.0 / std::pow(10.0, precision));
	var adjusted_threshold:float = maxf(1.0, 1.0 / pow(10.0, precision))
#   const double big_threshold = (adjusted_threshold * one_k) - 1;
	var big_threshold:float = (adjusted_threshold * one_k) - 1
#   const double small_threshold = adjusted_threshold;
	var small_threshold:float = adjusted_threshold
	# Values in ]simple_threshold,small_threshold[ will be printed as-is
#   const double simple_threshold = 0.01;
	const simple_threshold:float = 0.01
#
#   if (val > big_threshold) {
	if val > big_threshold:
		# Positive powers
#     double scaled = val;
		var scaled:float = val
#     for (size_t i = 0; i < arraysize(kBigSIUnits); ++i) {
#       scaled /= one_k;
#       if (scaled <= big_threshold) {
#         mantissa_stream << scaled;
#         *exponent = static_cast<int64_t>(i + 1);
#         *mantissa = mantissa_stream.str();
#         return;
#       }
#     }
		for i in kBigSIUnits.size():
			scaled /= one_k
			if scaled <= big_threshold:
				mantissa_stream.append("%0.3f" % scaled)
				exponent[0] = i + 1
				mantissa[0] = ''.join(mantissa_stream)
				return

#     mantissa_stream << val;
#     *exponent = 0;
		mantissa_stream.append(str(val))
		exponent[0] = 0;
#   } else if (val < small_threshold) {
	elif val < small_threshold:
		# Negative powers
#     if (val < simple_threshold) {
#       double scaled = val;
#       for (size_t i = 0; i < arraysize(kSmallSIUnits); ++i) {
#         scaled *= one_k;
#         if (scaled >= small_threshold) {
#           mantissa_stream << scaled;
#           *exponent = -static_cast<int64_t>(i + 1);
#           *mantissa = mantissa_stream.str();
#           return;
#         }
#       }
#     }
		if val < simple_threshold:
			var scaled:float = val
			for i in kSmallSIUnits.size():
				scaled *= one_k
				if scaled >= small_threshold:
					mantissa_stream.append("%0.3f" % scaled)
					exponent[0] = -(i + 1)
					mantissa[0] = ''.join(mantissa_stream)
					return
#     mantissa_stream << val;
#     *exponent = 0;
		mantissa_stream.append("%0.3f" % val)
		exponent[0] = 0;
	else:
#     mantissa_stream << val;
#     *exponent = 0;
		mantissa_stream.append("%0.3f" % val)
		exponent[0] = 0;
#   *mantissa = mantissa_stream.str();
	mantissa[0] = ''.join(mantissa_stream)



# std::string ExponentToPrefix(int64_t exponent, bool iec) {
#   if (exponent == 0) {
#     return {};
#   }
#
#   const int64_t index = (exponent > 0 ? exponent - 1 : -exponent - 1);
#   if (index >= kUnitsSize) {
#     return {};
#   }
#
#   const char* const* array =
#       (exponent > 0 ? (iec ? kBigIECUnits : kBigSIUnits) : kSmallSIUnits);
#
#   return std::string(array[index]);
# }

static func ExponentToPrefix(exponent:int, iec:bool) -> String:
	if exponent == 0: return "";

	var index:int = exponent - 1 if exponent > 0 else -exponent - 1
	if index >= kUnitsSize: return ""

	if exponent > 0:
		if iec: return kBigIECUnits[index]
		else: return kBigSIUnits[index]
	return kSmallSIUnits[index]

# std::string ToBinaryStringFullySpecified(double value, int precision,
#                                          Counter::OneK one_k) {
#   std::string mantissa;
#   int64_t exponent = 0;
#   ToExponentAndMantissa(value, precision,
#                         one_k == Counter::kIs1024 ? 1024.0 : 1000.0, &mantissa,
#                         &exponent);
#   return mantissa + ExponentToPrefix(exponent, one_k == Counter::kIs1024);
# }
static func ToBinaryStringFullySpecified(value:float, precision:int,
			one_k:BenchLib.Counter.OneK) -> String:
	var mantissa:Array[String] = [""]
	var exponent:Array[int] = [0]
	ToExponentAndMantissa(value, precision,
			1024.0 if one_k == Counter.OneK.kIs1024 else 1000.0,
			mantissa, exponent)
	return mantissa[0] + " " + ExponentToPrefix(exponent[0], one_k == Counter.OneK.kIs1024)

# PRINTF_FORMAT_STRING_FUNC(1, 0)
# std::string StrFormatImp(const char* msg, va_list args) {
#   // we might need a second shot at this, so pre-emptivly make a copy
#   va_list args_cp;
#   va_copy(args_cp, args);
#
#   // Use std::array for first attempt to avoid one memory allocation guess what
#   // the size might be
#   std::array<char, 256> local_buff = {};
#
#   // 2015-10-08: vsnprintf is used instead of snd::vsnprintf due to a limitation
#   // in the android-ndk
#   auto ret = vsnprintf(local_buff.data(), local_buff.size(), msg, args_cp);
#
#   va_end(args_cp);
#
#   // handle empty expansion
#   if (ret == 0) {
#     return {};
#   }
#   if (static_cast<std::size_t>(ret) < local_buff.size()) {
#     return std::string(local_buff.data());
#   }
#
#   // we did not provide a long enough buffer on our first attempt.
#   // add 1 to size to account for null-byte in size cast to prevent overflow
#   std::size_t size = static_cast<std::size_t>(ret) + 1;
#   auto buff_ptr = std::unique_ptr<char[]>(new char[size]);
#   // 2015-10-08: vsnprintf is used instead of snd::vsnprintf due to a limitation
#   // in the android-ndk
#   vsnprintf(buff_ptr.get(), size, msg, args);
#   return std::string(buff_ptr.get());
# }

#}  // end namespace

# std::string HumanReadableNumber(double n, Counter::OneK one_k) {
#   return ToBinaryStringFullySpecified(n, 1, one_k);
# }
static func HumanReadableNumber(n:float, one_k:BenchLib.Counter.OneK ) -> String:
	return ToBinaryStringFullySpecified(n, 1, one_k);


# std::string StrFormat(const char* format, ...) {
#   va_list args;
#   va_start(args, format);
#   std::string tmp = StrFormatImp(format, args);
#   va_end(args);
#   return tmp;
# }

# std::vector<std::string> StrSplit(const std::string& str, char delim) {
#   if (str.empty()) {
#     return {};
#   }
#   std::vector<std::string> ret;
#   size_t first = 0;
#   size_t next = str.find(delim);
#   for (; next != std::string::npos;
#        first = next + 1, next = str.find(delim, first)) {
#     ret.push_back(str.substr(first, next - first));
#   }
#   ret.push_back(str.substr(first));
#   return ret;
# }

#ifdef BENCHMARK_STL_ANDROID_GNUSTL
# /*
#  * GNU STL in Android NDK lacks support for some C++11 functions, including
#  * stoul, stoi, stod. We reimplement them here using C functions strtoul,
#  * strtol, strtod. Note that reimplemented functions are in benchmark::
#  * namespace, not std:: namespace.
#  */
# unsigned long stoul(const std::string& str, size_t* pos, int base) {
#   /* Record previous errno */
#   const int oldErrno = errno;
#   errno = 0;
#
#   const char* strStart = str.c_str();
#   char* strEnd = const_cast<char*>(strStart);
#   const unsigned long result = strtoul(strStart, &strEnd, base);
#
#   const int strtoulErrno = errno;
#   /* Restore previous errno */
#   errno = oldErrno;
#
#   /* Check for errors and return */
#   if (strtoulErrno == ERANGE) {
#     throw std::out_of_range("stoul failed: " + str +
#                             " is outside of range of unsigned long");
#   } else if (strEnd == strStart || strtoulErrno != 0) {
#     throw std::invalid_argument("stoul failed: " + str + " is not an integer");
#   }
#   if (pos != nullptr) {
#     *pos = static_cast<size_t>(strEnd - strStart);
#   }
#   return result;
# }

# int stoi(const std::string& str, size_t* pos, int base) {
#   /* Record previous errno */
#   const int oldErrno = errno;
#   errno = 0;
#
#   const char* strStart = str.c_str();
#   char* strEnd = const_cast<char*>(strStart);
#   const long result = strtol(strStart, &strEnd, base);
#
#   const int strtolErrno = errno;
#   /* Restore previous errno */
#   errno = oldErrno;
#
#   /* Check for errors and return */
#   if (strtolErrno == ERANGE || long(int(result)) != result) {
#     throw std::out_of_range("stoul failed: " + str +
#                             " is outside of range of int");
#   } else if (strEnd == strStart || strtolErrno != 0) {
#     throw std::invalid_argument("stoul failed: " + str + " is not an integer");
#   }
#   if (pos != nullptr) {
#     *pos = static_cast<size_t>(strEnd - strStart);
#   }
#   return int(result);
# }

# double stod(const std::string& str, size_t* pos) {
#   /* Record previous errno */
#   const int oldErrno = errno;
#   errno = 0;
#
#   const char* strStart = str.c_str();
#   char* strEnd = const_cast<char*>(strStart);
#   const double result = strtod(strStart, &strEnd);
#
#   /* Restore previous errno */
#   const int strtodErrno = errno;
#   errno = oldErrno;
#
#   /* Check for errors and return */
#   if (strtodErrno == ERANGE) {
#     throw std::out_of_range("stoul failed: " + str +
#                             " is outside of range of int");
#   } else if (strEnd == strStart || strtodErrno != 0) {
#     throw std::invalid_argument("stoul failed: " + str + " is not an integer");
#   }
#   if (pos != nullptr) {
#     *pos = static_cast<size_t>(strEnd - strStart);
#   }
#   return result;
# }
#endif

#}  // end namespace benchmark
