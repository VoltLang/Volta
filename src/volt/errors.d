/*#D*/
// Copyright © 2013-2016, Bernard Helyer.  All rights reserved.
// Copyright © 2013-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.errors;

import watt.conv : toLower;
import watt.text.format : format;
import watt.text.sink : StringSink;
import watt.io.std : writefln, error;

import ir = volta.ir;
import volta.ir.printer;

import volt.exceptions;
public import volta.errors;
import volta.settings;
import volta.ir.token : tokenToString, TokenType;
import volta.ir.location;

void hackTypeWarning(ir.Node n, ir.Type nt, ir.Type ot)
{
	auto str = format("%s: warning: types differ (new) %s vs (old) %s",
	       n.loc.toString(), typeString(nt), typeString(ot));
	error.writefln(str);
}

void warningAssignInCondition(ref in Location loc, bool warningsEnabled)
{
	if (warningsEnabled) {
		warning(/*#ref*/loc, "assign in condition.");
	}
}

void warningStringCat(ref in Location loc, bool warningsEnabled)
{
	if (warningsEnabled) {
		warning(/*#ref*/loc, "concatenation involving string.");
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

CompilerException makeInvalidTraitsModifier(ref in Location loc, string modifier, string file = __FILE__, const int line = __LINE__)
{
	string msg = format("'%s' is not a valid traits modifier. Expected 'elementOf', 'keyOf', 'valueOf', or 'baseOf'.", modifier);
	return makeError(/*#ref*/loc, msg, file, line);
}

CompilerException makeInvalidTraitsWord(ref in Location loc, string word, string file = __FILE__, const int line = __LINE__)
{
	string msg = format("'%s' is not a valid traits word. Expected 'isBitsType', 'isArray', 'isConst', 'isScope', or 'isImmutable'.", word);
	return makeError(/*#ref*/loc, msg, file, line);
}

CompilerException makeFunctionNamedInit(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return makeError(/*#ref*/loc, "functions may not be named 'init', to avoid confusion with the built-in type field of the same name.", file, line);
}

CompilerException makeAggregateStaticVariableNamedInit(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return makeError(/*#ref*/loc, "static field 'init' collides with built-in field of the same name.", file, line);
}

CompilerException makeExpressionForNew(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	auto msg = `got an expression where we expected a type for a 'new'.`;
	msg ~= loc.locationGuide();
	if (name != "") {
		msg ~= format("If '%s' is an array you want to copy,\nuse 'new %s[..]' to duplicate it.", name, name);
	}
	return makeError(/*#ref*/loc, msg, file, line);
}

CompilerException makeMisplacedContinue(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "continue statement outside of loop.", file, line);
}

CompilerException makeOverloadedFunctionsAccessMismatch(ir.Function a, ir.Function b)
{
	auto loc = b.loc;
	return new CompilerError(/*#ref*/loc, format("function '%s' access level ('%s') differs from overloaded function @ %s's access ('%s').",
		a.name, ir.accessToString(b.access), a.loc.toString(), ir.accessToString(a.access)));
}

CompilerException makeOverriddenFunctionsAccessMismatch(ir.Function a, ir.Function b)
{
	auto loc = b.loc;
	return new CompilerError(/*#ref*/loc, format("function '%s' access level ('%s') differs from overridden function @ %s's access level ('%s').",
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
	return new CompilerError(/*#ref*/loc, format("tried to access %s symbol '%s'.",
		accessName, name));
}

CompilerException makeBadComposableType(ref in Location loc, ir.Type type,
	string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("cannot use type %s as a composable string component.", type.typeString());
	return new CompilerError(/*#ref*/loc, msg, file, line);
}

CompilerException makeNonConstantCompileTimeComposable(ref in Location loc,
	string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "non constant expression in compile time composable string (precede with 'new' to make a runtime composable string).", file, line);
}

CompilerException makeArgumentCountMismatch(ref in Location loc, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	auto n = func.params.length;
	return makeExpected(/*#ref*/loc, format("%s argument%s to function '%s'", n, n == 1 ? "" : "s", func.name));
}

CompilerException makeAssigningVoid(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "tried to assign a void value.", file, line);
}

CompilerException makeStructValueCall(ref in Location loc, string aggName, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("expected aggregate type '%s' directly, not an instance.", aggName), file, line);
}

CompilerException makeStructDefaultCtor(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "structs or unions may not define default constructors.", file, line);
}

CompilerException makeStructDestructor(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "structs or unions may not define a destructor.", file, line);
}

CompilerException makeExpectedOneArgument(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "expected only one argument.", file, line);
}

CompilerException makeClassAsAAKey(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "classes cannot be associative array key types.", file, line);
}

CompilerException makeMutableStructAAKey(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "structs with mutable indirection cannot be associative array key types.", file, line);
}

CompilerException makeExpectedCall(ir.RunExp runexp, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/runexp.loc, "expression following #run must be a function call.", file, line);
}

CompilerException makeNonNestedAccess(ref in Location loc, ir.Variable var, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("cannot access variable '%s' from non-nested function.", var.name), file, line);
}

CompilerException makeMultipleMatches(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("multiple imports contain a symbol '%s'.", name), file, line);
}

CompilerException makeNoStringImportPaths(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "no string import file paths defined (use -J).", file, line);
}

CompilerException makeImportFileOpenFailure(ref in Location loc, string filename, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("couldn't open '%s' for reading.", filename), file, line);
}

CompilerException makeStringImportWrongConstant(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "expected non empty string literal as argument to string import.", file, line);
}

CompilerException makeNoSuperCall(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "expected explicit super call.", file, line);
}

CompilerException makeInvalidIndexValue(ir.Node n, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	auto str = format("can not index %s.", typeString(type));
	return new CompilerError(/*#ref*/n.loc, str, file, line);
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
	return new CompilerError(/*#ref*/loc, format("expected type %s for slice operation.", typeString(type)), file, line);
}

CompilerException makeIndexVarTooSmall(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("index variable '%s' is too small to hold a size_t.", name), file, line);
}

CompilerException makeNestedNested(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "nested functions may not have nested functions.", file, line);
}

CompilerException makeNonConstantStructLiteral(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "non-constant expression in global struct literal.", file, line);
}

CompilerException makeWrongNumberOfArgumentsToStructLiteral(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "wrong number of arguments to struct literal.", file, line);
}

CompilerException makeCannotDeduceStructLiteralType(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "cannot deduce struct literal's type.", file, line);
}

CompilerException makeArrayNonArrayNotCat(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "binary operations involving array and non array must be use concatenation (~).", file, line);
}

CompilerException makeCannotPickStaticFunction(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("cannot select static function '%s'.", name), file, line);
}

CompilerException makeCannotPickStaticFunctionVia(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("cannot select static function '%s' through instance.", name), file, line);
}

CompilerException makeCannotPickMemberFunction(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("cannot select member function '%s'.", name), file, line);
}

CompilerException makeStaticViaInstance(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("looking up '%s' static function via instance.", name), file, line);
}

CompilerException makeMixingStaticMember(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "mixing static and member functions.", file, line);
}

CompilerException makeNoZeroProperties(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "no zero argument properties found.", file, line);
}

CompilerException makeMultipleZeroProperties(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "multiple zero argument properties found.", file, line);
}

CompilerException makeUFCSAsProperty(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "an @property function may not be used for UFCS.", file, line);
}

CompilerException makeUFCSAndProperty(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("functions for lookup '%s' match UFCS *and* @property functions.", name), file, line);
}

CompilerException makeCallingUncallable(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "calling uncallable expression.", file, line);
}

CompilerException makeForeachIndexRef(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "may not mark a foreach index as ref.", file, line);
}

CompilerException makeDoNotSpecifyForeachType(ref in Location loc, string varname, string file = __FILE__, const int line  = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("foreach variables like '%s' may not have explicit type declarations.", varname), file, line);
}

CompilerException makeNoFieldOrPropOrUFCS(ir.Postfix postfix, string file = __FILE__, const int line=__LINE__)
{
	assert(postfix.identifier !is null);
	return new CompilerError(/*#ref*/postfix.loc, format("postfix lookups like '%s' must be field, property, or UFCS function.", postfix.identifier.value), file, line);
}

CompilerException makeAccessThroughWrongType(ref in Location loc, string field, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("accessing field '%s' through incorrect type.", field), file, line);
}

CompilerException makeVoidReturnMarkedProperty(ref in Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("@property functions with no arguments like '%s' cannot have a void return type.", name), file, line);
}

CompilerException makeNoFieldOrPropertyOrIsUFCSWithoutCall(ref in Location loc, string value, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("postfix lookups like '%s' that are not fields, properties, or UFCS functions must be a call.", value), file, line);
}

CompilerException makeNoFieldOrPropertyOrUFCS(ref in Location loc, string value, ir.Type t, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("'%s' is neither field, nor property, nor a UFCS function of %s.", value, typeString(t)), file, line);
}

CompilerException makeOverriddenNeedsProperty(ir.Function f, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/f.loc, format("functions like '%s' that override @property functions must be marked @property themselves.", f.name), file, line);
}

CompilerException makeOverridingFinal(ir.Function f, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/f.loc, format("function '%s' overrides function marked as final.", f.name), file, line);
}

CompilerException makeBadBuiltin(ref in Location loc, ir.Type t, string field, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("type '%s' doesn't have built-in field '%s'.", typeString(t), field), file, line);
}

CompilerException makeBadMerge(ir.Alias a, ir.Store s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/a.loc, "cannot merge alias as it is not a function.", file, line);
}

CompilerException makeCannotDup(ref in Location loc, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("cannot duplicate type '%s'.", type.typeString()), file, line);
}

CompilerException makeCannotSlice(ref in Location loc, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("cannot slice type '%s'.", type.typeString()), file, line);
}

CompilerException makeCallClass(ref in Location loc, ir.Class _class, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("attempted to call class '%s'. Did you forget a new?", _class.name), file, line);
}

CompilerException makeMixedSignedness(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "expressions cannot mix signed and unsigned values.", file, line);
}

CompilerException makeStaticArrayLengthMismatch(ref in Location loc, size_t expectedLength, size_t gotLength, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("expected static array literal of length %s, got a length of %s.", expectedLength, gotLength), file, line);
}

CompilerException makeDoesNotImplement(ref in Location loc, ir.Class _class, ir._Interface iface, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("'%s' does not implement the '%s' method of interface '%s'.", _class.name, func.name, iface.name), file, line);
}

CompilerException makeCaseFallsThrough(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "non-empty switch cases may not fall through.", file, line);
}

CompilerException makeNoNextCase(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "case falls through, but there are no subsequent cases.", file, line);
}

CompilerException makeGotoOutsideOfSwitch(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "goto must be inside a switch statement.", file, line);
}

CompilerException makeStrayDocComment(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "documentation comment has nothing to document.", file, line);
}

CompilerException makeCallingWithoutInstance(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto wi = new CompilerError(/*#ref*/loc, "instanced functions must be called with an instance.", file, line);
	return wi;
}

CompilerException makeForceLabel(ref in Location loc, ir.Function fun, string file = __FILE__, const int line = __LINE__)
{
	auto fl = new CompilerError(/*#ref*/loc, format("calls to @label functions like '%s' must label their arguments.", fun.name), file, line);
	return fl;
}

CompilerException makeNoEscapeScope(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto msg = "scope values may not escape through assignment.";
	msg ~= loc.locationGuide();
	auto es = new CompilerError(/*#ref*/loc, msg, file, line);
	return es;
}

CompilerException makeNoReturnScope(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto msg = "scope values may not escape through return statements.";
	msg ~= loc.locationGuide();
	auto nrs = new CompilerError(/*#ref*/loc, msg, file, line);
	return nrs;
}

CompilerException makeReturnValueExpected(ref in Location loc, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("return value of type '%s' expected.", type.typeString());
	return new CompilerError(/*#ref*/loc, emsg, file, line);
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

CompilerException makeDuplicateLabel(ref in Location loc, string label, string file = __FILE__, const int line = __LINE__)
{
	auto emsg = format("label '%s' specified multiple times.", label);
	return new CompilerError(/*#ref*/loc, emsg, file, line);
}

CompilerException makeUnmatchedLabel(ref in Location loc, string label, string file = __FILE__, const int line = __LINE__)
{
	auto emsg = format("no parameter matches argument label '%s'.", label);
	auto unl = new CompilerError(/*#ref*/loc, emsg, file, line);
	return unl;
}

CompilerException makeDollarOutsideOfIndex(ir.Constant constant, string file = __FILE__, const int line = __LINE__)
{
	auto doi = new CompilerError(/*#ref*/constant.loc, "'$' may only appear in an index expression.", file, line);
	return doi;
}

CompilerException makeBreakOutOfLoop(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(/*#ref*/loc, "break may only appear in a loop or switch.", file, line);
	return e;
}

CompilerException makeAggregateDoesNotDefineOverload(ref in Location loc, ir.Aggregate agg, string func, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(/*#ref*/loc, format("type '%s' does not define operator function '%s'.", agg.name, func), file, line);
	return e;
}

CompilerException makeBadWithType(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(/*#ref*/loc, "with statement cannot use given expression.", file, line);
	return e;
}

CompilerException makeForeachReverseOverAA(ir.ForeachStatement fes, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(/*#ref*/fes.loc, "foreach_reverse cannot be used with an associative array.", file, line);
	return e;
}

CompilerException makeAnonymousAggregateRedefines(ir.Aggregate agg, string name, string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("anonymous aggregate redefines '%s'.", name);
	auto e = new CompilerError(/*#ref*/agg.loc, msg, file, line);
	return e;
}

CompilerException makeInvalidMainSignature(ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(/*#ref*/func.loc, "invalid main signature.", file, line);
	return e;
}

CompilerException makeNoValidFunction(ref in Location loc, string fname, ir.Type[] args, string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("no function named '%s' matches arguments %s.", fname, typesString(args));
	auto e = new CompilerError(/*#ref*/loc, msg, file, line);
	return e;
}

CompilerException makeCVaArgsOnlyOperateOnSimpleTypes(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(/*#ref*/loc, "C varargs only support retrieving simple types, due to an LLVM limitation.", file, line);
	return e;
}

CompilerException makeVaFooMustBeLValue(ref in Location loc, string foo, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(/*#ref*/loc, format("argument to %s is not an lvalue.", foo), file, line);
	return e;
}

CompilerException makeNonLastVariadic(ir.Variable var, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(/*#ref*/var.loc, "variadic parameter must be last.", file, line);
	return e;
}

CompilerException makeStaticAssert(ir.AssertStatement as, string msg, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("static assert: %s", msg);
	auto e = new CompilerError(/*#ref*/as.loc, emsg, file, line);
	return e;
}

CompilerException makeConstField(ir.Variable v, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("const or immutable non local/global field '%s' is forbidden.", v.name);
	auto e = new CompilerError(/*#ref*/v.loc, emsg, file, line);
	return e;
}

CompilerException makeAssignToNonStaticField(ir.Variable v, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("attempted to assign to non local/global field %s.", v.name);
	auto e = new CompilerError(/*#ref*/v.loc, emsg, file, line);
	return e;
}

CompilerException makeSwitchBadType(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("bad switch type '%s'.", type.typeString());
	auto e = new CompilerError(/*#ref*/node.loc, emsg, file, line);
	return e;
}

CompilerException makeSwitchDuplicateCase(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	auto msg = "duplicate case in switch statement.";
	msg ~= node.loc.locationGuide();
	auto e = new CompilerError(/*#ref*/node.loc, msg, file, line);
	return e;
}

CompilerException makeFinalSwitchBadCoverage(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(/*#ref*/node.loc, "final switch statement must cover all enum members.", file, line);
	return e;
}

CompilerException makeArchNotSupported(string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError("architecture not supported on current platform.", file, line);
}

CompilerException makeSpuriousTag(ir.Exp exp, bool taggedRef, string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("parameter is neither ref nor out, but is tagged with %s.",
		taggedRef ? "ref" : "out");
	msg ~= exp.loc.locationGuide();
	auto chunk = exp.loc.errorChunk();
	return new CompilerError(/*#ref*/exp.loc, msg, file, line);
}

CompilerException makeWrongTag(ir.Exp exp, bool taggedRef, string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("argument to %s parameter is tagged, but with the wrong tag.",
		taggedRef ? "out" : "ref");
	msg ~= exp.loc.locationGuide();
	auto chunk = exp.loc.errorChunk();
	msg ~= format("(That means use '%s %s' instead of '%s %s'.)",
		taggedRef ? "out" : "ref", chunk, taggedRef ? "ref" : "out", chunk);
	return new CompilerError(/*#ref*/exp.loc, msg, file, line);
}

CompilerException makeNotTaggedOut(ir.Exp exp, string file = __FILE__, const int line = __LINE__)
{
	auto msg = "mark arguments to out parameters with 'out'.";
	msg ~= exp.loc.locationGuide();
	auto chunk = exp.loc.errorChunk();
	msg ~= format("(That means use 'out %s' instead of just '%s'.)", chunk, chunk);
	return new CompilerError(/*#ref*/exp.loc, msg, file, line);
}

CompilerException makeNotTaggedRef(ir.Exp exp, string file = __FILE__, const int line = __LINE__)
{
	auto msg = "mark arguments to ref parameters with 'ref'.";
	msg ~= exp.loc.locationGuide();
	auto chunk = exp.loc.errorChunk();
	msg ~= format("(That means use 'ref %s' instead of just '%s'.)", chunk, chunk);
	return new CompilerError(/*#ref*/exp.loc, msg, file, line);
}

CompilerException makeFunctionNameOutsideOfFunction(ir.TokenExp fexp, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/fexp.loc, format("%s occurring outside of function.", fexp.type == ir.TokenExp.Type.PrettyFunction ? "__PRETTY_FUNCTION__" : "__FUNCTION__"), file, line);
}

CompilerException makeMultipleValidModules(ir.Node node, string[] paths, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("multiple modules are valid: %s.", paths), file, line);
}

CompilerException makeAlreadyLoaded(ir.Module m, string filename, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/m.loc, format("module %s already loaded '%s'.", m.name.toString(), filename), file, line);
}

CompilerException makeCannotOverloadNested(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("cannot overload nested function '%s'.", func.name), file, line);
}

CompilerException makeUsedBeforeDeclared(ir.Node node, ir.Variable var, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("variable '%s' used before declaration.", var.name), file, line);
}


CompilerException makeStructConstructorsUnsupported(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, "struct constructors are currently unsupported.", file, line);
}

CompilerException makeCallingStaticThroughInstance(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("calling local or global function '%s' through instance variable.", func.name), file, line);
}

CompilerException makeMarkedOverrideDoesNotOverride(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("function '%s' is marked override, but no matching function to override could be found.", func.name), file, line);
}

CompilerException makeNewAbstract(ir.Node node, ir.Class _class, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("abstract classes like '%s' may not be instantiated.", _class.name), file, line);
}

CompilerException makeSubclassFinal(ir.Class child, ir.Class parent, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/child.loc, format("class '%s' attempts to subclass final class '%s'.", child.name, parent.name), file, line);
}

CompilerException makeNotAvailableInCTFE(ir.Node node, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("currently unevaluatable at compile time: '%s'.", s), file, line);
}

CompilerException makeNotAvailableInCTFE(ir.Node node, ir.Node feature, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("%s is currently unevaluatable at compile time.", ir.nodeToString(feature)), file, line);
}

CompilerException makeMultipleDefaults(in ref Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "switches may not have multiple default cases.", file, line);
}

CompilerException makeFinalSwitchWithDefault(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "final switches may not define a default case.", file, line);
}

CompilerException makeNoDefaultCase(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "switches must have a default case.", file, line);
}

CompilerException makeTryWithoutCatch(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "try statement must have a catch block and/or a finally block.", file, line);
}

CompilerException makeMultipleOutBlocks(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "a function may only have one in block defined.", file, line);
}

CompilerException makeNeedOverride(ir.Function overrider, ir.Function overridee, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("function '%s' overrides function at %s but is not marked with 'override'.", overrider.name, overridee.loc.toString());
	return new CompilerError(/*#ref*/overrider.loc, emsg, file, line);
}

CompilerException makeThrowOnlyThrowable(ir.Exp exp, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("only types that inherit from object.Throwable may be thrown, not '%s'.", type.typeString());
	return new CompilerError(/*#ref*/exp.loc, emsg, file, line);
}

CompilerException makeThrowNoInherits(ir.Exp exp, ir.Class clazz, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("only types that inherit from object.Throwable may be thrown, not class '%s'.", clazz.typeString());
	return new CompilerError(/*#ref*/exp.loc, emsg, file, line);
}

CompilerException makeInvalidAAKey(ir.AAType aa, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/aa.loc, format("%s is an invalid AA key. AA keys must not be mutably indirect.", aa.key.typeString()), file, line);
}

CompilerException makeBadAAAssign(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
    return new CompilerError(/*#ref*/loc, "may not assign associate arrays to prevent semantic inconsistencies.", file, line);
}

CompilerException makeBadAANullAssign(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
    return new CompilerError(/*#ref*/loc, "cannot set AA to null, use [] instead.", file, line);
}


/*
 *
 * General Util
 *
 */

CompilerException makeError(ir.Node n, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/n.loc, s, file, line);
}

CompilerException makeError(ref in Location loc, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, s, file, line);
}

CompilerException makeUnsupported(ref in Location loc, string feature, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("unsupported feature '%s'.", feature), file, line);
}

CompilerException makeExpected(ir.Node node, string s, string file = __FILE__, const int line = __LINE__)
{
	return makeExpected(/*#ref*/node.loc, s, false, file, line);
}

CompilerException makeExpected(ref in Location loc, string s, bool b = false, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("expected %s.", s), b, file, line);
}

CompilerException makeExpected(ref in Location loc, string expected, string got, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("expected '%s', got '%s'.", expected, got), file, line);
}

CompilerException makeUnexpected(ref in Location loc, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("unexpected %s.", s), file, line);
}

CompilerException makeBadOperation(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, "bad operation.", file, line);
}

CompilerException makeExpectedContext(ir.Node node, ir.Node node2, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, "expected context pointer.", file, line);
}

CompilerException makeNotReached(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, "statement not reached.", file, line);
}


/*
 *
 * Type Conversions
 *
 */

CompilerException makeBadAggregateToPrimitive(ir.Node node, ir.Type from, ir.Type to, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("cannot cast aggregate %s to %s.", typeString(from), typeString(to));
	return new CompilerError(/*#ref*/node.loc, emsg, file, line);
}

CompilerException makeBadImplicitCast(ir.Node node, ir.Type from, ir.Type to, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("cannot implicitly convert %s to %s.", typeString(from), typeString(to));
	return new CompilerError(/*#ref*/node.loc, emsg, file, line);
}

CompilerException makeCannotModify(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("cannot modify '%s'.", type.typeString()), file, line);
}

CompilerException makeNotLValueButRefOut(ir.Node node, bool isRef, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("expected lvalue to %s parameter.", isRef ? "ref" : "out"), file, line);
}

CompilerException makeTypeIsNot(ir.Node node, ir.Type from, ir.Type to, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("type '%s' is not '%s' as expected.", from.typeString(), to.typeString()), file, line);
}

CompilerException makeInvalidType(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("bad type '%s'.", type.typeString()), file, line);
}

CompilerException makeInvalidUseOfStore(ir.Node node, ir.Store store, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("invalid use of store '%s'.", store.name), file, line);
}


/*
 *
 * Lookups
 *
 */

CompilerException makeWithCreatesAmbiguity(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(/*#ref*/loc, "ambiguous lookup due to with block(s).", file, line);
	return e;
}

CompilerException makeInvalidThis(ir.Node node, ir.Type was, ir.Type expected, string member, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("'this' is of type '%s' expected '%s' to access member '%s'.", was.typeString(), expected.typeString(), member);
	return new CompilerError(/*#ref*/node.loc, emsg, file, line);
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
	return new CompilerError(/*#ref*/node.loc, emsg, file, line);
}

CompilerException makeNotMember(ref in Location loc, string aggregate, string member, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("'%s' has no member '%s'.", aggregate, member), file, line);
}

CompilerException makeFailedLookup(ir.Node node, string lookup, string file = __FILE__, const int line = __LINE__)
{
	return makeFailedLookup(/*#ref*/node.loc, lookup, file, line);
}

CompilerException makeFailedEnumLookup(ref in Location loc, string enumName, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("enum '%s' does not define '%s'.", enumName, name), file, line);
}

CompilerException makeFailedLookup(ref in Location loc, string lookup, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("unidentified identifier '%s'.", lookup), file, line);
}

/*
 *
 * Functions
 *
 */

CompilerException makeWrongNumberOfArguments(ir.Node node, ir.Function func, size_t got, size_t expected, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("wrong number of arguments to function '%s'; got %s, expected %s.", func.name, got, expected), file, line);
}

CompilerException makeBadCall(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("cannot call %s.", type.typeString()), file, line);
}

CompilerException makeBadPropertyCall(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, format("cannot call %s (a type returned from a property function).", type.typeString()), file, line);
}

CompilerException makeBadBinOp(ir.BinOp binop, ir.Type ltype, ir.Type rtype,
	string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("invalid '%s' expression using %s and %s.",
		binopToString(binop.op), ltype.typeString(), rtype.typeString());
	return new CompilerError(/*#ref*/binop.loc, msg, file, line);
}

CompilerException makeCannotDisambiguate(ir.Node node, ir.Function[] functions, ir.Type[] args, string file = __FILE__, const int line = __LINE__)
{
	return makeCannotDisambiguate(/*#ref*/node.loc, functions, args, file, line);
}

CompilerException makeCannotDisambiguate(ref in Location loc, ir.Function[] functions, ir.Type[] args, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, format("no '%s' function (of %s possible) matches arguments '%s'.", functions[0].name, functions.length, typesString(args)), file, line);
}

CompilerException makeCannotInfer(ref in Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/loc, "not enough information to infer type.", true, file, line);
}

CompilerException makeCannotLoadDynamic(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(/*#ref*/node.loc, "@loadDynamic function cannot have body.", file, line);
}

CompilerException makeMultipleFunctionsMatch(ref in Location loc, ir.Function[] functions, string file = __FILE__, const int line = __LINE__)
{
	string err = format("%s overloaded functions match call. Matching locations:\n", functions.length);
	foreach (i, func; functions) {
		err ~= format("\t%s%s", func.loc.toString(), i == functions.length - 1 ? "" : "\n");
	}
	return new CompilerError(/*#ref*/loc, err, file, line);
}


/*
 *
 * Panics
 *
 */

CompilerException panicOhGod(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return panic(/*#ref*/node.loc, "oh god.", file, line);
}

CompilerException panic(ir.Node node, string msg, string file = __FILE__, const int line = __LINE__)
{
	return panic(/*#ref*/node.loc, msg, file, line);
}

CompilerException panic(ref in Location loc, string msg, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerPanic(/*#ref*/loc, msg, file, line);
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
	return panicUnhandled(/*#ref*/node.loc, unhandled, file, line);
}

CompilerException panicUnhandled(ref in Location loc, string unhandled, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerPanic(/*#ref*/loc, format("unhandled case '%s'.", unhandled), file, line);
}

CompilerException panicNotMember(ir.Node node, string aggregate, string field, string file = __FILE__, const int line = __LINE__)
{
	auto str = format("no field name '%s' in aggregate '%s' '%s'.",
	                  field, aggregate, ir.nodeToString(node));
	return new CompilerPanic(/*#ref*/node.loc, str, file, line);
}

CompilerException panicExpected(ref in Location loc, string msg, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerPanic(/*#ref*/loc, format("expected %s.", msg), file, line);
}

void panicAssert(ir.Node node, bool condition, string file = __FILE__, const int line = __LINE__)
{
	if (!condition) {
		throw panic(/*#ref*/node.loc, "assertion failure.", file, line);
	}
}

void panicAssert(ref in Location loc, bool condition, string file = __FILE__, const int line = __LINE__)
{
	if (!condition) {
		throw panic(/*#ref*/loc, "assertion failure.", file, line);
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
