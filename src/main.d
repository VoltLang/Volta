/*#D*/
// Copyright 2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module main;

import watt.text.string : endsWith;

import ms = mainServer;
import mc = mainCompiler;


int main(string[] args)
{
	if (args.shouldRunServer()) {
		return ms.mainServer(args);
	} else {
		return mc.mainCompiler(args);
	}
}

/*!
 * Analyzes the given arguments and returns
 * true if volta should enter server mode.
 */
bool shouldRunServer(string[] args)
{
	if (args.length <= 0) {
		return false;
	}

	if (args[0].endsWith("vls") ||
	    args[0].endsWith("vls.exe")) {
		return true;
	}

	if (args.length <= 1) {
		return false;
	}

	if (args[1] == "--server") {
		return true;
	}

	return false;
}
