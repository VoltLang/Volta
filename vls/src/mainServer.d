// Copyright 2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module mainServer;

import watt.io.std : error;


int mainServer(string[] args)
{
	error.writefln("This Volta was built in D, it does not support server mode.");
	error.flush();
	return 1;
}
