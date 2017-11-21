/*#D*/
// Copyright © 2013-2017, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.errors;

import watt.io.std;
import watt.text.format;

import ir = volta.ir;

import volta.interfaces;
import volta.settings;
import volta.ir.location;


/*
 *
 * Panics
 *
 */

void panic(ErrorSink es, string message, string file = __FILE__, int line = __LINE__)
{
	es.onPanic(message, file, line);
}

void panic(ErrorSink es, ref in Location loc, string message, string file = __FILE__, int line = __LINE__)
{
	es.onPanic(/*#ref*/ loc, message, file, line);
}

void panic(ErrorSink es, ir.Node n, string message, string file = __FILE__, int line = __LINE__)
{
	es.panic(/*#ref*/ n.loc, message, file, line);
}

void passert(ErrorSink es, ir.Node n, bool condition, string file = __FILE__, int line = __LINE__)
{
	if (!condition) {
		panic(es, "passert failure", file, line);
	}
}


/*
 *
 * Errors
 *
 */

void errorMsg(ErrorSink es, ref in Location loc, string message, string file = __FILE__, int line = __LINE__)
{
	es.onError(/*#ref*/ loc, message, file, line);
}

void errorExpected(ErrorSink es, ref in Location loc, string expected, string file = __FILE__, int line = __LINE__)
{
	es.onError(/*#ref*/ loc, format("expected %s.", expected), file, line);
}

void errorExpected(ErrorSink es, ir.Node n, string expected, string file = __FILE__, int line = __LINE__)
{
	es.errorExpected(/*#ref*/ n.loc, expected, file, line);
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

void warning(ErrorSink es, ir.Node n, string message, string file = __FILE__, int line = __LINE__)
{
	es.warning(/*#ref*/ n.loc, message, file, line);
}

void warningOldStyleVariable(ref in Location loc, bool magicFlagD, Settings settings)
{
	if (!magicFlagD && settings.warningsEnabled) {
		warning(/*#ref*/loc, "old style variable declaration.");
	}
}

void warningOldStyleFunction(ref in Location loc, bool magicFlagD, Settings settings)
{
	if (!magicFlagD && settings.warningsEnabled) {
		warning(/*#ref*/loc, "old style function declaration.");
	}
}

void warningOldStyleFunctionPtr(ref in Location loc, bool magicFlagD, Settings settings)
{
	if (!magicFlagD && settings.warningsEnabled) {
		warning(/*#ref*/loc, "old style function pointer.");
	}
}

void warningOldStyleDelegateType(ref in Location loc, bool magicFlagD, Settings settings)
{
	if (!magicFlagD && settings.warningsEnabled) {
		warning(/*#ref*/loc, "old style delegate type.");
	}
}

void warningOldStyleHexTypeSuffix(ref in Location loc, bool magicFlagD, Settings settings)
{
	if (!magicFlagD && settings.warningsEnabled) {
		warning(/*#ref*/loc, "old style hex literal type suffix (U/L).");
	}
}
