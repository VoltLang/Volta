// Copyright 2018, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
/*!
 * A shim for getting and setting errno.
 *
 * There seem to be as many ways of implementing errno
 * as there are stars in the sky, so this solution is
 * easiest.
 */
#include <errno.h>

int vrt_get_errno()
{
	return errno;
}

int vrt_set_errno(int val)
{
	return errno = val;
}
