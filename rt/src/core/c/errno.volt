// Copyright 2018, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
module core.c.errno;

version (!Metal):

extern (C) fn vrt_set_errno(val: i32) i32;
extern (C) fn vrt_get_errno() i32;

@property fn errno() i32
{
	return vrt_get_errno();
}

@property fn errno(val: i32) i32
{
	return vrt_set_errno(val);
}
