// Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.errors;

import std.conv : to;
import std.string : format;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.token.location;

// Not sure of the best home for this guy.
void warning(Location loc, string message)
{
	writefln(format("%s: warning: %s", loc.toString(), message));
}

/*
 *
 *
 * Specific Errors
 *
 *
 */

CompilerException makeMarkedOverrideDoesNotOverride(ir.Node node, ir.Function fn)
{
	return new CompilerError(node.location, format("function '%s' is marked as override but does not override any functions.", fn.name));
}

CompilerException makeAbstractHasToBeMember(ir.Node node, ir.Function fn)
{
	return new CompilerError(node.location, format("function '%s' is marked as abstract but is not a member of an abstract class.", fn.name));
}

CompilerException makeAbstractBodyNotEmpty(ir.Node node, ir.Function fn)
{
	return new CompilerError(node.location, format("function '%s' is marked as abstract but it has an implementation.", fn.name));
}

CompilerException makeNewAbstract(ir.Node node, ir.Class _class)
{
	return new CompilerError(node.location, format("cannot create instance of abstract class '%s'.", _class.name));
}

CompilerException makeBadAbstract(ir.Node node, ir.Attribute attr)
{
	return new CompilerError(node.location, "only classes and functions may be marked as abstract.");
}

CompilerException makeCannotImport(ir.Node node, ir.Import _import)
{
	return new CompilerError(node.location, format("can't find module '%s'.", _import.name));
}

CompilerException makeNotAvailableInCTFE(ir.Node node, ir.Node feature)
{
	return new CompilerError(node.location, format("%s is currently unevaluatable at compile time.", to!string(feature.nodeType)));
}

CompilerException makeShadowsDeclaration(ir.Node a, ir.Node b)
{
	return new CompilerError(a.location, format("shadows declaration at %s.", b.location));
}

CompilerException makeMultipleDefaults(Location location)
{
	return new CompilerError(location, "multiple default cases defined.");
}

CompilerException makeFinalSwitchWithDefault(Location location)
{
	return new CompilerError(location, "final switch with default case.");
}

CompilerException makeNoDefaultCase(Location location)
{
	return new CompilerError(location, "no default case.");
}

CompilerException makeTryWithoutCatch(Location location)
{
	return new CompilerError(location, "try statement must have a catch block and/or a finally block.");
}

CompilerException makeMultipleOutBlocks(Location location)
{
	return new CompilerError(location, "multiple in blocks specified for single function.");
}

CompilerException makeNeedOverride(ir.Function overrider, ir.Function overridee)
{
	string emsg = format("function '%s' overrides function at %s but is not marked with 'override'.", overrider.name, overridee.location);
	return new CompilerError(overrider.location, emsg);
}

/*
 *
 *
 * General Util
 *
 *
 */

CompilerException makeUnsupported(Location location, string feature)
{
	return new CompilerError(location, format("unsupported feature, '%s'", feature));
}

CompilerException makeError(Location location, string s)
{
	// A hack for typer, for now.
	return new CompilerError(location, s);
}

CompilerException makeExpected(ir.Node node, string s)
{
	return makeExpected(node.location, s);
}

CompilerException makeExpected(Location location, string s, bool b = false)
{
	return new CompilerError(location, format("expected %s.", s), b);
}

CompilerException makeExpected(Location location, string expected, string got)
{
	return new CompilerError(location, format("expected '%s', got '%s'.", expected, got));
}

CompilerException makeUnexpected(ir.Location location, string s)
{
	return new CompilerError(location, format("unexpected %s.", s));
}

CompilerException makeBadOperation(ir.Node node)
{
	return new CompilerError(node.location, "bad operation.");
}

CompilerException makeExpectedContext(ir.Node node, ir.Node node2)
{
	return new CompilerError(node.location, "expected context pointer.");
}


/*
 *
 *
 * Type Conversions
 *
 *
 */

CompilerException makeBadImplicitCast(ir.Node node, ir.Type from, ir.Type to)
{
	string emsg = format("cannot implicitly convert %s to %s.", from.errorString, to.errorString);
	return new CompilerError(node.location, emsg);
}

CompilerException makeCannotModify(ir.Node node, ir.Type type)
{
	return new CompilerError(node.location, format("cannot modify '%s'.", type.errorString));
}

CompilerException makeNotLValue(ir.Node node)
{
	return new CompilerError(node.location, "expected lvalue.");
}

CompilerException makeTypeIsNot(ir.Node node, ir.Type from, ir.Type to)
{
	return new CompilerError(node.location, format("type %s is not %s as expected.", from.errorString, to.errorString));
}

CompilerException makeInvalidType(ir.Node node, ir.Type type)
{
	return new CompilerError(node.location, format("bad type %s", type.errorString));
}

CompilerException makeInvalidUseOfStore(ir.Node node, ir.Store store)
{
	return new CompilerError(node.location, format("invalid use of store '%s'.", store.name));
}

/*
 *
 *
 * Look ups
 *
 *
 */

CompilerException makeNotMember(ir.Node node, ir.Type aggregate, string member)
{
	return new CompilerError(node.location, format("%s has no member '%s'", aggregate.errorString, member));
}

CompilerException makeNotMember(Location location, string aggregate, string member)
{
	return new CompilerError(location, format("%s has no member '%s'", aggregate, member));
}

CompilerException makeFailedLookup(ir.Node node, string lookup)
{
	return makeFailedLookup(node.location, lookup);
}

CompilerException makeFailedLookup(Location location, string lookup)
{
	return new CompilerError(location, format("unidentified identifier '%s'", lookup));
}

CompilerException makeNonTopLevelImport(Location location)
{
	return new CompilerError(location, "Imports only allowed in top scope");
}

/*
 *
 *
 * Functions
 *
 *
 */

CompilerException makeWrongNumberOfArguments(ir.Node node, size_t got, size_t expected)
{
	return new CompilerError(node.location, format("wrong number of arguments; got %s, expected %s.", got, expected));
}

CompilerException makeBadCall(ir.Node node, ir.Type type)
{
	return new CompilerError(node.location, format("cannot call %s.", type.errorString));
}

CompilerException makeCannotDisambiguate(ir.Node node, ir.Function[] functions)
{
	return makeCannotDisambiguate(node.location, functions);
}

CompilerException makeCannotDisambiguate(Location location, ir.Function[] functions)
{
	return new CompilerError(location, format("cannot disambiguate between %s functions.", functions.length));
}

CompilerException makeCannotInfer(ir.Location location)
{
	return new CompilerError(location, "not enough information to infer type.", true);
}

CompilerException makeCannotLoadDynamic(ir.Node node, ir.Function fn)
{
	return new CompilerError(node.location, "can not @loadDynamic function with body");
}


/*
 *
 *
 * Panics
 *
 *
 */

CompilerException panicOhGod(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return panic(node.location, "Oh god.", file, line);
}

CompilerException panic(ir.Node node, string msg, string file = __FILE__, const int line = __LINE__)
{
	return panic(node.location, msg, file, line);
}

CompilerException panic(Location location, string msg, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerPanic(location, msg);
	e.file = file;
	e.line = line;
	return e;
}

CompilerException panic(string msg, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerPanic(msg);
	e.file = file;
	e.line = line;
	return e;
}

CompilerException panicUnhandled(ir.Node node, string unhandled, string file = __FILE__, const int line = __LINE__)
{
	return panicUnhandled(node.location, unhandled, file, line);
}

CompilerException panicUnhandled(Location location, string unhandled, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerPanic(location, format("unhandled case '%s'", unhandled));
	e.file = file;
	e.line = line;
	return e;
}

CompilerException panicNotMember(ir.Node node, string aggregate, string field, string file = __FILE__, const int line = __LINE__)
{
	auto str = format("0x%s no field name '%s' in struct '%s'",
	                  to!string(*cast(size_t*)&node),
	                  field, aggregate);
	auto e = new CompilerPanic(node.location, str);
	e.file = file;
	e.line = line;
	return e;
}

private:

string errorString(ir.Type type) @property
{
	return format("'%s'", type);
}
