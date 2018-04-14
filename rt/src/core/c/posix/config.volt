// Copyright 2017, Bernard Helyer
// Copyright 2005-2009, Sean Kelly.
// SPDX-License-Identifier: BSL-1.0
// File taken from druntime, and modified for Volt.
/*!
 * @ingroup cbind
 * @ingroup posixbind
 */
module core.c.posix.config;

version (Posix):

public import core.c.config;


extern(C):
@trusted:
nothrow:

enum _XOPEN_SOURCE     = 600;
enum _POSIX_C_SOURCE   = 200112L;

version (Linux) {

	// man 7 feature_test_macros
	// http://www.gnu.org/software/libc/manual/html_node/Feature-Test-Macros.html
	enum _GNU_SOURCE         = false;
	enum _BSD_SOURCE         = false;
	enum _SVID_SOURCE        = false;

	enum _FILE_OFFSET_BITS   = 64;
	// <sys/cdefs.h>
	enum __REDIRECT          = false;

	// deduced <features.h>
	enum __USE_FILE_OFFSET64 = _FILE_OFFSET_BITS == 64;
	enum __USE_LARGEFILE     = __USE_FILE_OFFSET64 && !__REDIRECT;
	enum __USE_LARGEFILE64   = __USE_FILE_OFFSET64 && !__REDIRECT;

	enum __USE_XOPEN2K       = _XOPEN_SOURCE >= 600;
	enum __USE_XOPEN2KXSI    = _XOPEN_SOURCE >= 600;
	enum __USE_XOPEN2K8      = _XOPEN_SOURCE >= 700;
	enum __USE_XOPEN2K8XSI   = _XOPEN_SOURCE >= 700;

	enum __USE_GNU           = _GNU_SOURCE;
	enum __USE_MISC          = _BSD_SOURCE || _SVID_SOURCE;

	version (V_P64) {

		enum __WORDSIZE = 64;

	} else {

		enum __WORDSIZE = 32;

	}

}
