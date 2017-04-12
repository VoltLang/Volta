// Copyright © 2005-2009, Sean Kelly.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// File taken from druntime, and modified for Volt.
module core.c.stdint;

version (CRuntime_All):


private import core.c.config; // for c_long, c_ulong
private import core.c.stddef; // for ptrdiff_t, size_t, wchar_t
private import core.c.signal; // for sig_atomic_t
private import core.c.wchar_; // for wint_t


extern(C):
@trusted: // Types and constants only.
nothrow:

alias int8_t  = i8;
alias int16_t = i16;
alias int32_t = i32;
version (V_P64) {
	alias int64_t = c_long;
} else {
	alias int64_t = i64;
}

alias uint8_t  = u8;
alias uint16_t = u16;
alias uint32_t = u32;
version (V_P64) {
	alias uint64_t = c_ulong;
} else {
	alias uint64_t = u64;
}

alias int_least8_t  = i8;
alias int_least16_t = i16;
alias int_least32_t = i32;
version (V_P64) {
	alias int_least64_t = c_long;
} else {
	alias int_least64_t = i64;
}

alias uint_least8_t  = u8;
alias uint_least16_t = u16;
alias uint_least32_t = u32;
version (V_P64) {
	alias uint_least64_t = c_ulong;
} else {
	alias uint_least64_t = u64;
}

alias int_fast8_t  = i8;
version (V_P64) {
	alias int_fast16_t = c_long;
	alias int_fast32_t = c_long;
	alias int_fast64_t = c_long;
} else {
	alias int_fast16_t = i32;
	alias int_fast32_t = i32;
	alias int_fast64_t = i64;
}

alias uint_fast8_t  = u8;
version (V_P64) {
	alias uint_fast16_t = c_ulong;
	alias uint_fast32_t = c_ulong;
	alias uint_fast64_t = c_ulong;
} else {
	alias uint_fast16_t = u32;
	alias uint_fast32_t = u32;
	alias uint_fast64_t = u64;
}

version (V_P64) {
	version (MSVC || MinGW) {
		alias intptr_t  = i64;
		alias uintptr_t = u64;
	} else {
		alias intptr_t  = c_long;
		alias uintptr_t = c_ulong;
	}
} else {
	alias intptr_t  = i32;
	alias uintptr_t = u32;
}

version (V_P64) {
	version (MSVC || MinGW) {
		alias intmax_t  = i64;
		alias uintmax_t = u64;
	} else {
		alias intmax_t  = c_long;
		alias uintmax_t = c_ulong;
	}
} else {
	alias intmax_t  = i64;
	alias uintmax_t = u64;
}

/+
enum int8_t   INT8_MIN  = int8_t.min;
enum int8_t   INT8_MAX  = int8_t.max;
enum int16_t  INT16_MIN = int16_t.min;
enum int16_t  INT16_MAX = int16_t.max;
enum int32_t  INT32_MIN = int32_t.min;
enum int32_t  INT32_MAX = int32_t.max;
enum int64_t  INT64_MIN = int64_t.min;
enum int64_t  INT64_MAX = int64_t.max;

enum uint8_t  UINT8_MAX  = uint8_t.max;
enum uint16_t UINT16_MAX = uint16_t.max;
enum uint32_t UINT32_MAX = uint32_t.max;
enum uint64_t UINT64_MAX = uint64_t.max;

enum int_least8_t    INT_LEAST8_MIN   = int_least8_t.min;
enum int_least8_t    INT_LEAST8_MAX   = int_least8_t.max;
enum int_least16_t   INT_LEAST16_MIN  = int_least16_t.min;
enum int_least16_t   INT_LEAST16_MAX  = int_least16_t.max;
enum int_least32_t   INT_LEAST32_MIN  = int_least32_t.min;
enum int_least32_t   INT_LEAST32_MAX  = int_least32_t.max;
enum int_least64_t   INT_LEAST64_MIN  = int_least64_t.min;
enum int_least64_t   INT_LEAST64_MAX  = int_least64_t.max;

enum uint_least8_t   UINT_LEAST8_MAX  = uint_least8_t.max;
enum uint_least16_t  UINT_LEAST16_MAX = uint_least16_t.max;
enum uint_least32_t  UINT_LEAST32_MAX = uint_least32_t.max;
enum uint_least64_t  UINT_LEAST64_MAX = uint_least64_t.max;

enum int_fast8_t   INT_FAST8_MIN   = int_fast8_t.min;
enum int_fast8_t   INT_FAST8_MAX   = int_fast8_t.max;
enum int_fast16_t  INT_FAST16_MIN  = int_fast16_t.min;
enum int_fast16_t  INT_FAST16_MAX  = int_fast16_t.max;
enum int_fast32_t  INT_FAST32_MIN  = int_fast32_t.min;
enum int_fast32_t  INT_FAST32_MAX  = int_fast32_t.max;
enum int_fast64_t  INT_FAST64_MIN  = int_fast64_t.min;
enum int_fast64_t  INT_FAST64_MAX  = int_fast64_t.max;

enum uint_fast8_t  UINT_FAST8_MAX  = uint_fast8_t.max;
enum uint_fast16_t UINT_FAST16_MAX = uint_fast16_t.max;
enum uint_fast32_t UINT_FAST32_MAX = uint_fast32_t.max;
enum uint_fast64_t UINT_FAST64_MAX = uint_fast64_t.max;

enum intptr_t  INTPTR_MIN  = intptr_t.min;
enum intptr_t  INTPTR_MAX  = intptr_t.max;

enum uintptr_t UINTPTR_MIN = uintptr_t.min;
enum uintptr_t UINTPTR_MAX = uintptr_t.max;

enum intmax_t  INTMAX_MIN  = intmax_t.min;
enum intmax_t  INTMAX_MAX  = intmax_t.max;

enum uintmax_t UINTMAX_MAX = uintmax_t.max;

enum ptrdiff_t PTRDIFF_MIN = ptrdiff_t.min;
enum ptrdiff_t PTRDIFF_MAX = ptrdiff_t.max;

enum sig_atomic_t SIG_ATOMIC_MIN = sig_atomic_t.min;
enum sig_atomic_t SIG_ATOMIC_MAX = sig_atomic_t.max;

enum size_t  SIZE_MAX  = size_t.max;

enum wchar_t WCHAR_MIN = wchar_t.min;
enum wchar_t WCHAR_MAX = wchar_t.max;

enum wint_t  WINT_MIN  = wint_t.min;
enum wint_t  WINT_MAX  = wint_t.max;

alias typify!(int8_t)  INT8_C;
alias typify!(int16_t) INT16_C;
alias typify!(int32_t) INT32_C;
alias typify!(int64_t) INT64_C;

alias typify!(uint8_t)  UINT8_C;
alias typify!(uint16_t) UINT16_C;
alias typify!(uint32_t) UINT32_C;
alias typify!(uint64_t) UINT64_C;

alias typify!(intmax_t)  INTMAX_C;
alias typify!(uintmax_t) UINTMAX_C;
+/
