/*#D*/
// Copyright © 2013-2017, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.errors;

import watt.io.std;
import watt.text.format;

import volta.interfaces;
import volta.ir.location;


/*
 *
 * Panics
 *
 */

void panic(ErrorSink es, ref in Location loc, string message, string file = __FILE__, int line = __LINE__)
{
	es.onPanic(/*#ref*/ loc, message, file, line);
}


/*
 *
 * Errors
 *
 */

void error(ErrorSink es, ref in Location loc, string message, string file = __FILE__, int line = __LINE__)
{
	es.onError(/*#ref*/ loc, message, file, line);
}


/*
 *
 * Warnings
 *
 */

void warning(ref in Location loc, string message)
{
	writefln(format("%s: warning: %s", loc.toString(), message));
}

void warning(ErrorSink es, ref in Location loc, string message, string file = __FILE__, int line = __LINE__)
{
	es.onWarning(/*#ref*/ loc, message, file, line);
}
