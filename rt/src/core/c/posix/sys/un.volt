// Copyright © 2017, Jakob Bornecrantz.
// See copyright notice in src/watt/license.d (BOOST ver. 1.0).
module core.c.posix.sys.un;

version (!Metal):

version (Posix):
extern (C):

import core.c.posix.sys.socket;

version (Linux) {
	struct sockaddr_un
	{
		sun_family: sa_family_t;
		sun_path: i8[108];
	}
}
version (OSX) {
	struct sockaddr_un
	{
		sun_family: sa_family_t;
		sun_path: i8[104];
	}
}
