/*#D*/
// Copyright © 2013-2016, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.errors;

import watt.io.std;
import watt.text.format;
import volta.ir.location;

void warning(ref in Location loc, string message)
{
	writefln(format("%s: warning: %s", loc.toString(), message));
}
