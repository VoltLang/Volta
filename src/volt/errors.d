// Copyright © 2013-2016, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.errors;

import watt.conv : toLower;
import watt.text.format : format;
import watt.text.sink : StringSink;
import watt.io.std : writefln;

import ir = volt.ir.ir;
import volt.ir.printer;

import volt.exceptions;
import volt.arg : Settings;
import volt.token.token : tokenToString, TokenType;
import volt.token.location;


// Not sure of the best home for this guy.
void warning(ref in Location loc, string message)
{
	writefln(format("%s: warning: %s", loc.toString(), message));
}

void hackTypeWarning(ir.Node n, ir.Type nt, ir.Type ot)
{
	auto str = format("%s: warning: types differ (new) %s vs (old) %s",
	       n.loc.toString(), typeString(nt), typeString(ot));
	writefln(str);
}

void warningAssignInCondition(ref in Location loc, bool warningsEnabled)
{
	if (warningsEnabled) {
		warning(loc, "assign in condition.");
	}
}

void warningStringCat(ref in Location loc, bool warningsEnabled)
{
	if (warningsEnabled) {
		warning(loc, "concatenation involving string.");
	}
}

void warningOldStyleVariable(ref in Location loc, Settings settings)
{
	if (!settings.internalD && settings.warningsEnabled) {
		warning(loc, "old style variable declaration.");
	}
}

void warningOldStyleFunction(ref in Location loc, Settings settings)
{
	if (!settings.internalD && settings.warningsEnabled) {
		warning(loc, "old style function declaration.");
	}
}

void warningOldStyleFunctionPtr(ref in Location loc, Settings settings)
{
	if (!settings.internalD && settings.warningsEnabled) {
		warning(loc, "old style function pointer.");
	}
}

void warningOldStyleDelegateType(ref in Location loc, Settings settings)
{
	if (!settings.internalD && settings.warningsEnabled) {
		warning(loc, "old style delegate type.");
	}
}

void warningOldStyleHexTypeSuffix(ref in Location loc, Settings settings)
{
	if (!settings.internalD && settings.warningsEnabled) {
		warning(loc, "old style hex literal type suffix (U/L).");
	}
}

void warningShadowsField(ref in Location newDecl, ref in Location oldDecl, string name, bool warningsEnabled)
{
	if (warningsEnabled) {
		warning(newDecl, format("declaration '%s' shadows field at %s.", name, oldDecl.toString()));
	}
}

void warningEmitBitcode()
{
	writefln("--emit-bitcode is deprecated use --emit-llvm and -c flags instead");
}

/*
 *
 * Driver errors.
 *
 */

CompilerException makeEmitLLVMNoLink(string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError("must specify -c when using --emit-llvm", file, line);
}

/*
 *
 * Specific Errors
 *
 */

CompilerException makeFunctionNamedInit(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return makeError(loc, "functions may not be named 'init', to avoid confusion with the built-in type field of the same name.", file, line);
}

CompilerException makeAggregateStaticVariableNamedInit(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return makeError(loc, "static field 'init' collides with built-in field of the same name.", file, line);
}

CompilerException makeExpressionForNew(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	auto msg = `got an expression where we expected a type for a 'new'.`;
	if (name != "") {
		msg ~= format("\nIf '%s' is an array you want to copy,\nuse 'new %s[..]' to duplicate it.", name, name);
	}
	return makeError(loc, msg, file, line);
}

CompilerException makeMisplacedContinue(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "continue statement outside of loop.", file, line);
}

CompilerException makeOverloadedFunctionsAccessMismatch(ir.Access importAccess, ir.Alias a, ir.Function b,
	string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("alias '%s' access level ('%s') does not match '%s' ('%s') @ %s.",
		a.name, ir.accessToString(importAccess), b.name, ir.accessToString(b.access), b.loc.toString());
	return new CompilerError(a.loc, msg, file, line);
}

CompilerException makeOverloadedFunctionsAccessMismatch(ir.Function a, ir.Function b)
{
	auto loc = b.loc;
	return new CompilerError(loc, format("function '%s' access level ('%s') differs from overloaded function @ %s's access ('%s').",
		a.name, ir.accessToString(b.access), a.loc.toString(), ir.accessToString(a.access)));
}

CompilerException makeOverriddenFunctionsAccessMismatch(ir.Function a, ir.Function b)
{
	auto loc = b.loc;
	return new CompilerError(loc, format("function '%s' access level ('%s') differs from overridden function @ %s's access level ('%s').",
		a.name, ir.accessToString(b.access), a.loc.toString(), ir.accessToString(a.access)));
}

CompilerException makeBadAccess(ref in Location loc, string name, ir.Access access,
	string file = __FILE__, const int line = __LINE__)
{
	string accessName;
	switch (access) {
	case ir.Access.Private: accessName = "private"; break;
	case ir.Access.Protected: accessName = "protected"; break;
	default: assert(false);
	}
	return new CompilerError(loc, format("tried to access %s symbol '%s'.",
		accessName, name));
}

CompilerException makeBadComposableType(ref in Location loc, ir.Type type,
	string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("cannot use type %s as a composable string component.", type.typeString());
	return new CompilerError(loc, msg, file, line);
}

CompilerException makeNonConstantCompileTimeComposable(ref in Location loc,
	string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "non constant expression in compile time composable string (precede with 'new' to make a runtime composable string).", file, line);
}

CompilerException makeArgumentCountMismatch(ref in Location loc, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	auto n = func.params.length;
	return makeExpected(loc, format("%s argument%s to function '%s'", n, n == 1 ? "" : "s", func.name));
}

CompilerException makeAssigningVoid(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "tried to assign a void value.", file, line);
}

CompilerException makeStructValueCall(ref in Location loc, string aggName, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("expected aggregate type '%s' directly, not an instance.", aggName), file, line);
}

CompilerException makeStructDefaultCtor(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "structs or unions may not define default constructors.", file, line);
}

CompilerException makeStructDestructor(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "structs or unions may not define a destructor.", file, line);
}

CompilerException makeExpectedOneArgument(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "expected only one argument.", file, line);
}

CompilerException makeClassAsAAKey(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "classes cannot be associative array key types.", file, line);
}

CompilerException makeMutableStructAAKey(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "structs with mutable indirection cannot be associative array key types.", file, line);
}

CompilerException makeExpectedCall(ir.RunExp runexp, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(runexp.loc, "expression following #run must be a function call.", file, line);
}

CompilerException makeNonNestedAccess(ref in Location loc, ir.Variable var, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("cannot access variable '%s' from non-nested function.", var.name), file, line);
}

CompilerException makeRedefines(ref in Location loc, ref in Location loc2, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("redefines symbol '%s', defined @ %s", name, loc2.toString()));
}

CompilerException makeMultipleMatches(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("multiple imports contain a symbol '%s'.", name), file, line);
}

CompilerException makeNoStringImportPaths(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "no string import file paths defined (use -J).", file, line);
}

CompilerException makeImportFileOpenFailure(ref in Location loc, string filename, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("couldn't open '%s' for reading.", filename), file, line);
}

CompilerException makeStringImportWrongConstant(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "expected non empty string literal as argument to string import.", file, line);
}

CompilerException makeNoSuperCall(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "expected explicit super call.", file, line);
}

CompilerException makeInvalidIndexValue(ir.Node n, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	auto str = format("can not index %s.", typeString(type));
	return new CompilerError(n.loc, str, file, line);
}

CompilerException makeUnknownArch(string a, string file = __FILE__, const int line = __LINE__)
{
	auto str = format("unknown arch \"%s\"", a);
	return new CompilerError(str, file, line);
}

CompilerException makeUnknownPlatform(string p, string file = __FILE__, const int line = __LINE__)
{
	auto str = format("unknown platform \"%s\"", p);
	return new CompilerError(str, file, line);
}

CompilerException makeExpectedTypeMatch(ref in Location loc, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("expected type %s for slice operation.", typeString(type)), file, line);
}

CompilerException makeIndexVarTooSmall(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("index variable '%s' is too small to hold a size_t.", name), file, line);
}

CompilerException makeNestedNested(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "nested functions may not have nested functions.", file, line);
}

CompilerException makeNonConstantStructLiteral(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "non-constant expression in global struct literal.", file, line);
}

CompilerException makeWrongNumberOfArgumentsToStructLiteral(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "wrong number of arguments to struct literal.", file, line);
}

CompilerException makeCannotDeduceStructLiteralType(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "cannot deduce struct literal's type.", file, line);
}

CompilerException makeArrayNonArrayNotCat(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "binary operations involving array and non array must be use concatenation (~).", file, line);
}

CompilerException makeCannotPickStaticFunction(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("cannot select static function '%s'.", name), file, line);
}

CompilerException makeCannotPickStaticFunctionVia(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("cannot select static function '%s' through instance.", name), file, line);
}

CompilerException makeCannotPickMemberFunction(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("cannot select member function '%s'.", name), file, line);
}

CompilerException makeStaticViaInstance(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("looking up '%s' static function via instance.", name), file, line);
}

CompilerException makeMixingStaticMember(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "mixing static and member functions.", file, line);
}

CompilerException makeNoZeroProperties(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "no zero argument properties found.", file, line);
}

CompilerException makeMultipleZeroProperties(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "multiple zero argument properties found.", file, line);
}

CompilerException makeUFCSAsProperty(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "an @property function may not be used for UFCS.", file, line);
}

CompilerException makeUFCSAndProperty(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("functions for lookup '%s' match UFCS *and* @property functions.", name), file, line);
}

CompilerException makeCallingUncallable(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "calling uncallable expression.", file, line);
}

CompilerException makeForeachIndexRef(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "may not mark a foreach index as ref.", file, line);
}

CompilerException makeDoNotSpecifyForeachType(ref in Location loc, string varname, string file = __FILE__, const int line  = __LINE__)
{
	return new CompilerError(loc, format("foreach variables like '%s' may not have explicit type declarations.", varname), file, line);
}

CompilerException makeNoFieldOrPropOrUFCS(ir.Postfix postfix, string file = __FILE__, const int line=__LINE__)
{
	assert(postfix.identifier !is null);
	return new CompilerError(postfix.loc, format("postfix lookups like '%s' must be field, property, or UFCS function.", postfix.identifier.value), file, line);
}

CompilerException makeAccessThroughWrongType(ref in Location loc, string field, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("accessing field '%s' through incorrect type.", field), file, line);
}

CompilerException makeVoidReturnMarkedProperty(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("@property functions with no arguments like '%s' cannot have a void return type.", name), file, line);
}

CompilerException makeNoFieldOrPropertyOrIsUFCSWithoutCall(ref in Location loc, string value, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("postfix lookups like '%s' that are not fields, properties, or UFCS functions must be a call.", value), file, line);
}

CompilerException makeNoFieldOrPropertyOrUFCS(ref in Location loc, string value, ir.Type t, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("'%s' is neither field, nor property, nor a UFCS function of %s.", value, typeString(t)), file, line);
}

CompilerException makeUsedBindFromPrivateImport(ref in Location loc, string bind, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("may not bind from private import, as '%s' does.", bind), file, line);
}

CompilerException makeOverriddenNeedsProperty(ir.Function f, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(f.loc, format("functions like '%s' that override @property functions must be marked @property themselves.", f.name), file, line);
}

CompilerException makeOverridingFinal(ir.Function f, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(f.loc, format("function '%s' overrides function marked as final.", f.name), file, line);
}

CompilerException makeBadBuiltin(ref in Location loc, ir.Type t, string field, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("type '%s' doesn't have built-in field '%s'.", typeString(t), field), file, line);
}

CompilerException makeBadMerge(ir.Alias a, ir.Store s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(a.loc, "cannot merge alias as it is not a function.", file, line);
}

CompilerException makeScopeOutsideFunction(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "scopes must be inside a function.", file, line);
}

CompilerException makeCannotDup(ref in Location loc, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("cannot duplicate type '%s'.", type.typeString()), file, line);
}

CompilerException makeCannotSlice(ref in Location loc, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("cannot slice type '%s'.", type.typeString()), file, line);
}

CompilerException makeCallClass(ref in Location loc, ir.Class _class, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("attempted to call class '%s'. Did you forget a new?", _class.name), file, line);
}

CompilerException makeMixedSignedness(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "expressions cannot mix signed and unsigned values.", file, line);
}

CompilerException makeStaticArrayLengthMismatch(ref in Location loc, size_t expectedLength, size_t gotLength, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("expected static array literal of length %s, got a length of %s.", expectedLength, gotLength), file, line);
}

CompilerException makeDoesNotImplement(ref in Location loc, ir.Class _class, ir._Interface iface, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("'%s' does not implement the '%s' method of interface '%s'.", _class.name, func.name, iface.name), file, line);
}

CompilerException makeCaseFallsThrough(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "non-empty switch cases may not fall through.", file, line);
}

CompilerException makeNoNextCase(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "case falls through, but there are no subsequent cases.", file, line);
}

CompilerException makeGotoOutsideOfSwitch(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "goto must be inside a switch statement.", file, line);
}

CompilerException makeStrayDocComment(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "documentation comment has nothing to document.", file, line);
}

CompilerException makeCallingWithoutInstance(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto wi = new CompilerError(loc, "instanced functions must be called with an instance.", file, line);
	return wi;
}

CompilerException makeForceLabel(ref in Location loc, ir.Function fun, string file = __FILE__, const int line = __LINE__)
{
	auto fl = new CompilerError(loc, format("calls to @label functions like '%s' must label their arguments.", fun.name), file, line);
	return fl;
}

CompilerException makeNoEscapeScope(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto es = new CompilerError(loc, "types marked scope may not remove their scope through assignment.", file, line);
	return es;
}

CompilerException makeNoReturnScope(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto nrs = new CompilerError(loc, "types marked scope may not be returned.", file, line);
	return nrs;
}

CompilerException makeReturnValueExpected(ref in Location loc, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("return value of type '%s' expected.", type.typeString());
	return new CompilerError(loc, emsg, file, line);
}

CompilerException makeNoLoadBitcodeFile(string filename, string msg, string file = __FILE__, const int line = __LINE__)
{
	string err;
	if (msg !is null) {
		err = format("failed to read bitcode file '%s'.\n%s", filename, msg);
	} else {
		err = format("failed to read bitcode file '%s'.", filename);
	}
	return new CompilerError(err, file, line);
}

CompilerException makeNoWriteBitcodeFile(string filename, string msg, string file = __FILE__, const int line = __LINE__)
{
	string err;
	if (msg !is null) {
		err = format("failed to write object bitcode '%s'.\n%s", filename, msg);
	} else {
		err = format("failed to write object bitcode '%s'.", filename);
	}
	return new CompilerError(err, file, line);
}

CompilerException makeNoWriteObjectFile(string filename, string msg, string file = __FILE__, const int line = __LINE__)
{
	string err;
	if (msg !is null) {
		err = format("failed to write object file '%s'.\n%s", filename, msg);
	} else {
		err = format("failed to write object file '%s'.", filename);
	}
	return new CompilerError(err, file, line);
}

CompilerException makeNoLinkModule(string filename, string msg, string file = __FILE__, const int line = __LINE__)
{
	string err;
	if (msg !is null) {
		err = format("failed to link in module '%s'.\n%s", filename, msg);
	} else {
		err = format("failed to link in module '%s'.", filename);
	}
	return new CompilerError(err, file, line);
}

CompilerException makeUnmatchedLabel(ref in Location loc, string label, string file = __FILE__, const int line = __LINE__)
{
	auto emsg = format("no parameter matches argument label '%s'.", label);
	auto unl = new CompilerError(loc, emsg, file, line);
	return unl;
}

CompilerException makeDollarOutsideOfIndex(ir.Constant constant, string file = __FILE__, const int line = __LINE__)
{
	auto doi = new CompilerError(constant.loc, "'$' may only appear in an index expression.", file, line);
	return doi;
}

CompilerException makeBreakOutOfLoop(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, "break may only appear in a loop or switch.", file, line);
	return e;
}

CompilerException makeAggregateDoesNotDefineOverload(ref in Location loc, ir.Aggregate agg, string func, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, format("type '%s' does not define operator function '%s'.", agg.name, func), file, line);
	return e;
}

CompilerException makeBadWithType(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, "with statement cannot use given expression.", file, line);
	return e;
}

CompilerException makeForeachReverseOverAA(ir.ForeachStatement fes, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(fes.loc, "foreach_reverse cannot be used with an associative array.", file, line);
	return e;
}

CompilerException makeAnonymousAggregateRedefines(ir.Aggregate agg, string name, string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("anonymous aggregate redefines '%s'.", name);
	auto e = new CompilerError(agg.loc, msg, file, line);
	return e;
}

CompilerException makeAnonymousAggregateAtTopLevel(ir.Aggregate agg, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(agg.loc, "anonymous struct or union not inside aggregate.", file, line);
	return e;
}

CompilerException makeInvalidMainSignature(ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(func.loc, "invalid main signature.", file, line);
	return e;
}

CompilerException makeNoValidFunction(ref in Location loc, string fname, ir.Type[] args, string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("no function named '%s' matches arguments %s.", fname, typesString(args));
	auto e = new CompilerError(loc, msg, file, line);
	return e;
}

CompilerException makeCVaArgsOnlyOperateOnSimpleTypes(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, "C varargs only support retrieving simple types, due to an LLVM limitation.", file, line);
	return e;
}

CompilerException makeVaFooMustBeLValue(ref in Location loc, string foo, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, format("argument to %s is not an lvalue.", foo), file, line);
	return e;
}

CompilerException makeNonLastVariadic(ir.Variable var, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(var.loc, "variadic parameter must be last.", file, line);
	return e;
}

CompilerException makeStaticAssert(ir.AssertStatement as, string msg, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("static assert: %s", msg);
	auto e = new CompilerError(as.loc, emsg, file, line);
	return e;
}

CompilerException makeConstField(ir.Variable v, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("const or immutable non local/global field '%s' is forbidden.", v.name);
	auto e = new CompilerError(v.loc, emsg, file, line);
	return e;
}

CompilerException makeAssignToNonStaticField(ir.Variable v, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("attempted to assign to non local/global field %s.", v.name);
	auto e = new CompilerError(v.loc, emsg, file, line);
	return e;
}

CompilerException makeSwitchBadType(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("bad switch type '%s'.", type.typeString());
	auto e = new CompilerError(node.loc, emsg, file, line);
	return e;
}

CompilerException makeSwitchDuplicateCase(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(node.loc, "duplicate case in switch statement.", file, line);
	return e;
}

CompilerException makeFinalSwitchBadCoverage(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(node.loc, "final switch statement must cover all enum members.", file, line);
	return e;
}

CompilerException makeArchNotSupported(string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError("architecture not supported on current platform.", file, line);
}

CompilerException makeNotTaggedOut(ir.Exp exp, size_t i, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(exp.loc, format("arguments to out parameters (like no. %s) must be tagged as out.", i+1), file, line);
}

CompilerException makeNotTaggedRef(ir.Exp exp, size_t i, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(exp.loc, format("arguments to ref parameters (like no. %s) must be tagged as ref.", i+1), file, line);
}

CompilerException makeFunctionNameOutsideOfFunction(ir.TokenExp fexp, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(fexp.loc, format("%s occurring outside of function.", fexp.type == ir.TokenExp.Type.PrettyFunction ? "__PRETTY_FUNCTION__" : "__FUNCTION__"), file, line);
}

CompilerException makeMultipleValidModules(ir.Node node, string[] paths, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("multiple modules are valid: %s.", paths), file, line);
}

CompilerException makeAlreadyLoaded(ir.Module m, string filename, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(m.loc, format("module %s already loaded '%s'.", m.name.toString(), filename), file, line);
}

CompilerException makeCannotOverloadNested(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("cannot overload nested function '%s'.", func.name), file, line);
}

CompilerException makeUsedBeforeDeclared(ir.Node node, ir.Variable var, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("variable '%s' used before declaration.", var.name), file, line);
}


CompilerException makeStructConstructorsUnsupported(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, "struct constructors are currently unsupported.", file, line);
}

CompilerException makeCallingStaticThroughInstance(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("calling local or global function '%s' through instance variable.", func.name), file, line);
}

CompilerException makeMarkedOverrideDoesNotOverride(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("function '%s' is marked override, but no matching function to override could be found.", func.name), file, line);
}

CompilerException makeAbstractHasToBeMember(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("abstract functions like '%s' must be a member of an abstract class.", func.name), file, line);
}

CompilerException makeAbstractBodyNotEmpty(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("abstract functions like '%s' may not have an implementation.", func.name), file, line);
}

CompilerException makeNewAbstract(ir.Node node, ir.Class _class, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("abstract classes like '%s' may not be instantiated.", _class.name), file, line);
}

CompilerException makeBadAbstract(ir.Node node, ir.Attribute attr, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, "only classes and functions may be marked as abstract.", file, line);
}

CompilerException makeBadFinal(ir.Node node, ir.Attribute attr, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, "only classes, functions, and switch statmenets may be marked as final.", file, line);
}

CompilerException makeSubclassFinal(ir.Class child, ir.Class parent, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(child.loc, format("class '%s' attempts to subclass final class '%s'.", child.name, parent.name), file, line);
}

CompilerException makeCannotImport(ir.Node node, ir.Import _import, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("can't find module '%s'.", _import.name), file, line);
}

CompilerException makeCannotImportAnonymous(ir.Node node, ir.Import _import, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("can't import anonymous module '%s'.", _import.name), file, line);
}

CompilerException makeNotAvailableInCTFE(ir.Node node, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("currently unevaluatable at compile time: '%s'.", s), file, line);
}

CompilerException makeNotAvailableInCTFE(ir.Node node, ir.Node feature, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("%s is currently unevaluatable at compile time.", ir.nodeToString(feature)), file, line);
}

CompilerException makeShadowsDeclaration(ir.Node a, ir.Node b, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(a.loc, format("shadows declaration at %s.", b.loc.toString()), file, line);
}

CompilerException makeMultipleDefaults(in ref Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "switches may not have multiple default cases.", file, line);
}

CompilerException makeFinalSwitchWithDefault(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "final switches may not define a default case.", file, line);
}

CompilerException makeNoDefaultCase(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "switches must have a default case.", file, line);
}

CompilerException makeTryWithoutCatch(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "try statement must have a catch block and/or a finally block.", file, line);
}

CompilerException makeMultipleOutBlocks(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "a function may only have one in block defined.", file, line);
}

CompilerException makeNeedOverride(ir.Function overrider, ir.Function overridee, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("function '%s' overrides function at %s but is not marked with 'override'.", overrider.name, overridee.loc.toString());
	return new CompilerError(overrider.loc, emsg, file, line);
}

CompilerException makeThrowOnlyThrowable(ir.Exp exp, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("only types that inherit from object.Throwable may be thrown, not '%s'.", type.typeString());
	return new CompilerError(exp.loc, emsg, file, line);
}

CompilerException makeThrowNoInherits(ir.Exp exp, ir.Class clazz, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("only types that inherit from object.Throwable may be thrown, not class '%s'.", clazz.typeString());
	return new CompilerError(exp.loc, emsg, file, line);
}

CompilerException makeInvalidAAKey(ir.AAType aa, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(aa.loc, format("%s is an invalid AA key. AA keys must not be mutably indirect.", aa.key.typeString()), file, line);
}

CompilerException makeBadAAAssign(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
    return new CompilerError(loc, "may not assign associate arrays to prevent semantic inconsistencies.", file, line);
}

CompilerException makeBadAANullAssign(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
    return new CompilerError(loc, "cannot set AA to null, use [] instead.", file, line);
}


/*
 *
 * General Util
 *
 */

CompilerException makeError(ir.Node n, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(n.loc, s, file, line);
}

CompilerException makeError(ref in Location loc, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, s, file, line);
}

CompilerException makeUnsupported(ref in Location loc, string feature, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("unsupported feature '%s'.", feature), file, line);
}

CompilerException makeExpected(ir.Node node, string s, string file = __FILE__, const int line = __LINE__)
{
	return makeExpected(node.loc, s, false, file, line);
}

CompilerException makeExpected(ref in Location loc, string s, bool b = false, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("expected %s.", s), b, file, line);
}

CompilerException makeExpected(ref in Location loc, string expected, string got, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("expected '%s', got '%s'.", expected, got), file, line);
}

CompilerException makeUnexpected(ref in Location loc, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("unexpected %s.", s), file, line);
}

CompilerException makeBadOperation(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, "bad operation.", file, line);
}

CompilerException makeExpectedContext(ir.Node node, ir.Node node2, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, "expected context pointer.", file, line);
}

CompilerException makeNotReached(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, "statement not reached.", file, line);
}


/*
 *
 * Type Conversions
 *
 */

CompilerException makeBadAggregateToPrimitive(ir.Node node, ir.Type from, ir.Type to, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("cannot cast aggregate %s to %s.", typeString(from), typeString(to));
	return new CompilerError(node.loc, emsg, file, line);
}

CompilerException makeBadImplicitCast(ir.Node node, ir.Type from, ir.Type to, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("cannot implicitly convert %s to %s.", typeString(from), typeString(to));
	return new CompilerError(node.loc, emsg, file, line);
}

CompilerException makeCannotModify(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("cannot modify '%s'.", type.typeString()), file, line);
}

CompilerException makeNotLValueButRefOut(ir.Node node, bool isRef, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("expected lvalue to %s parameter.", isRef ? "ref" : "out"), file, line);
}

CompilerException makeTypeIsNot(ir.Node node, ir.Type from, ir.Type to, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("type '%s' is not '%s' as expected.", from.typeString(), to.typeString()), file, line);
}

CompilerException makeInvalidType(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("bad type '%s'.", type.typeString()), file, line);
}

CompilerException makeInvalidUseOfStore(ir.Node node, ir.Store store, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("invalid use of store '%s'.", store.name), file, line);
}


/*
 *
 * Lookups
 *
 */

CompilerException makeWithCreatesAmbiguity(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, "ambiguous lookup due to with block(s).", file, line);
	return e;
}

CompilerException makeInvalidThis(ir.Node node, ir.Type was, ir.Type expected, string member, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("'this' is of type '%s' expected '%s' to access member '%s'.", was.typeString(), expected.typeString(), member);
	return new CompilerError(node.loc, emsg, file, line);
}

CompilerException makeNotMember(ir.Node node, ir.Type aggregate, string member, string file = __FILE__, const int line = __LINE__)
{
	auto pfix = cast(ir.Postfix) node;
	string emsg = format("'%s' has no member '%s'.", aggregate.typeString(), member);
	if (pfix !is null && pfix.child.nodeType == ir.NodeType.ExpReference) {
		auto eref = cast(ir.ExpReference) pfix.child;
		auto var = cast(ir.Variable)eref.decl;
		StringSink name;
		foreach (i, id; eref.idents) {
			name.sink(id);
			if (i < eref.idents.length - 1) {
				name.sink(".");
			}
		}
		emsg = format("instance '%s' (of type '%s') has no member '%s'.", name.toString(), aggregate.typeString(), member);
	}
	return new CompilerError(node.loc, emsg, file, line);
}

CompilerException makeNotMember(ref in Location loc, string aggregate, string member, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("'%s' has no member '%s'.", aggregate, member), file, line);
}

CompilerException makeFailedLookup(ir.Node node, string lookup, string file = __FILE__, const int line = __LINE__)
{
	return makeFailedLookup(node.loc, lookup, file, line);
}

CompilerException makeFailedEnumLookup(ref in Location loc, string enumName, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("enum '%s' does not define '%s'.", enumName, name), file, line);
}

CompilerException makeFailedLookup(ref in Location loc, string lookup, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("unidentified identifier '%s'.", lookup), file, line);
}

CompilerException makeNonTopLevelImport(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "imports must occur in the top scope.", file, line);
}


/*
 *
 * Functions
 *
 */

CompilerException makeWrongNumberOfArguments(ir.Node node, ir.Function func, size_t got, size_t expected, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("wrong number of arguments to function '%s'; got %s, expected %s.", func.name, got, expected), file, line);
}

CompilerException makeBadCall(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("cannot call %s.", type.typeString()), file, line);
}

CompilerException makeBadPropertyCall(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, format("cannot call %s (a type returned from a property function).", type.typeString()), file, line);
}

CompilerException makeBadBinOp(ir.BinOp binop, ir.Type ltype, ir.Type rtype,
	string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("invalid '%s' expression using %s and %s.",
		binopToString(binop.op), ltype.typeString(), rtype.typeString());
	return new CompilerError(binop.loc, msg, file, line);
}

CompilerException makeCannotDisambiguate(ir.Node node, ir.Function[] functions, ir.Type[] args, string file = __FILE__, const int line = __LINE__)
{
	return makeCannotDisambiguate(node.loc, functions, args, file, line);
}

CompilerException makeCannotDisambiguate(ref in Location loc, ir.Function[] functions, ir.Type[] args, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("no '%s' function (of %s possible) matches arguments '%s'.", functions[0].name, functions.length, typesString(args)), file, line);
}

CompilerException makeCannotInfer(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "not enough information to infer type.", true, file, line);
}

CompilerException makeCannotLoadDynamic(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.loc, "@loadDynamic function cannot have body.", file, line);
}

CompilerException makeMultipleFunctionsMatch(ref in Location loc, ir.Function[] functions, string file = __FILE__, const int line = __LINE__)
{
	string err = format("%s overloaded functions match call. Matching locations:\n", functions.length);
	foreach (i, func; functions) {
		err ~= format("\t%s%s", func.loc.toString(), i == functions.length - 1 ? "" : "\n");
	}
	return new CompilerError(loc, err, file, line);
}


/*
 *
 * Panics
 *
 */

CompilerException panicOhGod(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return panic(node.loc, "oh god.", file, line);
}

CompilerException panic(ir.Node node, string msg, string file = __FILE__, const int line = __LINE__)
{
	return panic(node.loc, msg, file, line);
}

CompilerException panic(ref in Location loc, string msg, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerPanic(loc, msg, file, line);
}

CompilerException panic(string msg, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerPanic(msg, file, line);
}

CompilerException panicRuntimeObjectNotFound(string name, string file = __FILE__, const int line = __LINE__)
{
	return panic(format("can't find runtime object '%s'.", name), file, line);
}

CompilerException panicUnhandled(ir.Node node, string unhandled, string file = __FILE__, const int line = __LINE__)
{
	return panicUnhandled(node.loc, unhandled, file, line);
}

CompilerException panicUnhandled(ref in Location loc, string unhandled, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerPanic(loc, format("unhandled case '%s'.", unhandled), file, line);
}

CompilerException panicNotMember(ir.Node node, string aggregate, string field, string file = __FILE__, const int line = __LINE__)
{
	auto str = format("no field name '%s' in aggregate '%s' '%s'.",
	                  field, aggregate, ir.nodeToString(node));
	return new CompilerPanic(node.loc, str, file, line);
}

CompilerException panicExpected(ref in Location loc, string msg, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerPanic(loc, format("expected %s.", msg), file, line);
}

void panicAssert(ir.Node node, bool condition, string file = __FILE__, const int line = __LINE__)
{
	if (!condition) {
		throw panic(node.loc, "assertion failure.", file, line);
	}
}

void panicAssert(ref in Location loc, bool condition, string file = __FILE__, const int line = __LINE__)
{
	if (!condition) {
		throw panic(loc, "assertion failure.", file, line);
	}
}


private:

string typeString(ir.Type t)
{
	string full, glossed;
	full = t.printType();
	glossed = t.printType(true);

	if (full == glossed) {
		return format("'%s'", full);
	} else {
		return format("'%s' (aka '%s')", glossed, full);
	}
}

string typesString(ir.Type[] types)
{
	StringSink buf;
	buf.sink("(");
	foreach (i, type; types) {
		buf.sink(type.printType(true));
		if (i < types.length - 1) {
			buf.sink(", ");
		}
	}
	buf.sink(")");
	return buf.toString();
}
