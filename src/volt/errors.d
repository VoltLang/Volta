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
void warning(Location loc, string message)
{
	writefln(format("%s: warning: %s", loc.toString(), message));
}

void hackTypeWarning(ir.Node n, ir.Type nt, ir.Type ot)
{
	auto str = format("%s: warning: types differ (new) %s vs (old) %s",
	       n.location.toString(), typeString(nt), typeString(ot));
	writefln(str);
}

void warningStringCat(Location loc, bool warningsEnabled)
{
	if (warningsEnabled) {
		warning(loc, "concatenation involving string.");
	}
}

void warningOldStyleVariable(Location loc, Settings settings)
{
	if (!settings.internalD && settings.warningsEnabled) {
		warning(loc, "old style variable declaration.");
	}
}

void warningOldStyleFunction(Location loc, Settings settings)
{
	if (!settings.internalD && settings.warningsEnabled) {
		warning(loc, "old style function declaration.");
	}
}

void warningOldStyleFunctionPtr(Location loc, Settings settings)
{
	if (!settings.internalD && settings.warningsEnabled) {
		warning(loc, "old style function pointer.");
	}
}

void warningOldStyleDelegateType(Location loc, Settings settings)
{
	if (!settings.internalD && settings.warningsEnabled) {
		warning(loc, "old style delegate type.");
	}
}

/*
 *
 * Specific Errors
 *
 */
CompilerException makeNeverReached(Location l, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, "statement never reached.", file, line);
}

CompilerException makeAssigningVoid(Location l, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, "tried to assign a void value.", file, line);
}

CompilerException makeStructValueCall(Location l, string aggName, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, format("expected aggregate type '%s' directly, not an instance.", aggName), file, line);
}

CompilerException makeStructDefaultCtor(Location l, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, "structs or unions may not define default constructors.", file, line);
}

CompilerException makeStructDestructor(Location l, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, "structs or unions may not define a destructor.", file, line);
}

CompilerException makeExpectedOneArgument(Location l, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, "expected only one argument.", file, line);
}

CompilerException makeClassAsAAKey(Location l, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, "classes cannot be associative array key types.", file, line);
}

CompilerException makeExpectedCall(ir.RunExp runexp, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(runexp.location, "expression following #run must be a function call.", file, line);
}

CompilerException makeNonNestedAccess(Location l, ir.Variable var, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, format("cannot access variable '%s' from non-nested function.", var.name), file, line);
}

CompilerException makeMultipleMatches(Location l, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, format("multiple imports contain a symbol '%s'.", name), file, line);
}

CompilerException makeNoStringImportPaths(Location l, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, "no string import file paths defined (use -J).", file, line);
}

CompilerException makeImportFileOpenFailure(Location l, string filename, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, format("couldn't open '%s' for reading.", filename), file, line);
}

CompilerException makeStringImportWrongConstant(Location l, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, "expected non empty string literal as argument to string import.", file, line);
}

CompilerException makeNoSuperCall(Location l, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, "expected explicit super call.", file, line);
}

CompilerException makeInvalidIndexValue(ir.Node n, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	auto str = format("can not index %s.", typeString(type));
	return new CompilerError(n.location, str, file, line);
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

CompilerException makeExpectedTypeMatch(Location loc, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("expected type %s for slice operation.", typeString(type)), file, line);
}

CompilerException makeIndexVarTooSmall(Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("index variable '%s' is too small to hold a size_t.", name), file, line);
}

CompilerException makeNestedNested(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "nested functions may not have nested functions.", file, line);
}

CompilerException makeNonConstantStructLiteral(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "non-constant expression in global struct literal.", file, line);
}

CompilerException makeWrongNumberOfArgumentsToStructLiteral(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "wrong number of arguments to struct literal.", file, line);
}

CompilerException makeCannotDeduceStructLiteralType(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "cannot deduce struct literal's type.", file, line);
}

CompilerException makeArrayNonArrayNotCat(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "binary operations involving array and non array must be use concatenation (~).", file, line);
}

CompilerException makeCannotPickStaticFunction(Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("cannot select static function '%s'.", name), file, line);
}

CompilerException makeCannotPickStaticFunctionVia(Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("cannot select static function '%s' through instance.", name), file, line);
}

CompilerException makeCannotPickMemberFunction(Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("cannot select member function '%s'.", name), file, line);
}

CompilerException makeStaticViaInstance(Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("looking up '%s' static function via instance.", name), file, line);
}

CompilerException makeMixingStaticMember(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "mixing static and member functions.", file, line);
}

CompilerException makeNoZeroProperties(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "no zero argument properties found.", file, line);
}

CompilerException makeMultipleZeroProperties(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "multiple zero argument properties found.", file, line);
}

CompilerException makeUFCSAsProperty(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "an @property function may not be used for UFCS.", file, line);
}

CompilerException makeUFCSAndProperty(Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("functions for lookup '%s' match UFCS *and* @property functions.", name), file, line);
}

CompilerException makeCallingUncallable(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "calling uncallable expression.", file, line);
}

CompilerException makeForeachIndexRef(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "may not mark a foreach index as ref.", file, line);
}

CompilerException makeDoNotSpecifyForeachType(Location loc, string varname, string file = __FILE__, const int line  = __LINE__)
{
	return new CompilerError(loc, format("foreach variables like '%s' may not have explicit type declarations.", varname), file, line);
}

CompilerException makeNoFieldOrPropOrUFCS(ir.Postfix postfix, string file = __FILE__, const int line=__LINE__)
{
	assert(postfix.identifier !is null);
	return new CompilerError(postfix.location, format("postfix lookups like '%s' must be field, property, or UFCS function.", postfix.identifier.value), file, line);
}

CompilerException makeAccessThroughWrongType(Location loc, string field, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("accessing field '%s' through incorrect type.", field), file, line);
}

CompilerException makeVoidReturnMarkedProperty(Location loc, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("@property functions with no arguments like '%s' cannot have a void return type.", name), file, line);
}

CompilerException makeNoFieldOrPropertyOrIsUFCSWithoutCall(Location loc, string value, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("postfix lookups like '%s' that are not fields, properties, or UFCS functions must be a call.", value), file, line);
}

CompilerException makeNoFieldOrPropertyOrUFCS(Location loc, string value, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("'%s' is neither field, nor property, nor a UFCS function.", value), file, line);
}

CompilerException makeUsedBindFromPrivateImport(Location loc, string bind, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("may not bind from private import, as '%s' does.", bind), file, line);
}

CompilerException makeOverriddenNeedsProperty(ir.Function f, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(f.location, format("functions like '%s' that override @property functions must be marked @property themselves.", f.name), file, line);
}

CompilerException makeBadBuiltin(Location l, ir.Type t, string field, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, format("type '%s' doesn't have built-in field '%s'.", typeString(t), field), file, line);
}

CompilerException makeBadMerge(ir.Alias a, ir.Store s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(a.location, "cannot merge alias as it is not a function.", file, line);
}

CompilerException makeScopeOutsideFunction(Location l, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, "scopes must be inside a function.", file, line);
}

CompilerException makeCannotDup(Location l, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, format("cannot duplicate type '%s'.", type.typeString()), file, line);
}

CompilerException makeCannotSlice(Location l, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(l, format("cannot slice type '%s'.", type.typeString()), file, line);
}

CompilerException makeCallClass(Location loc, ir.Class _class, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("attempted to call class '%s'. Did you forget a new?", _class.name), file, line);
}

CompilerException makeMixedSignedness(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("expressions cannot mix signed and unsigned values."), file, line);
}

CompilerException makeStaticArrayLengthMismatch(Location loc, size_t expectedLength, size_t gotLength, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("expected static array literal of length %s, got a length of %s.", expectedLength, gotLength), file, line);
}

CompilerException makeDoesNotImplement(Location loc, ir.Class _class, ir._Interface iface, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, format("'%s' does not implement the '%s' method of interface '%s'.", _class.name, func.name, iface.name), file, line);
}

CompilerException makeCaseFallsThrough(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "non-empty switch cases may not fall through.", file, line);
}

CompilerException makeNoNextCase(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "case falls through, but there are no subsequent cases.", file, line);
}

CompilerException makeGotoOutsideOfSwitch(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "goto must be inside a switch statement.", file, line);
}

CompilerException makeStrayDocComment(Location loc, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(loc, "documentation comment has nothing to document.", file, line);
}

CompilerException makeCallingWithoutInstance(Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto wi = new CompilerError(loc, "instanced functions must be called with an instance.", file, line);
	return wi;
}

CompilerException makeForceLabel(Location loc, ir.Function fun, string file = __FILE__, const int line = __LINE__)
{
	auto fl = new CompilerError(loc, format("calls to @label functions like '%s' must label their arguments.", fun.name), file, line);
	return fl;
}

CompilerException makeNoEscapeScope(Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto es = new CompilerError(loc, "types marked scope may not remove their scope through assignment.", file, line);
	return es;
}

CompilerException makeNoReturnScope(Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto nrs = new CompilerError(loc, "types marked scope may not be returned.", file, line);
	return nrs;
}

CompilerException makeReturnValueExpected(Location loc, ir.Type type, string file = __FILE__, const int line = __LINE__)
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

CompilerException makeUnmatchedLabel(Location loc, string label, string file = __FILE__, const int line = __LINE__)
{
	auto emsg = format("no parameter matches argument label '%s'.", label);
	auto unl = new CompilerError(loc, emsg, file, line);
	return unl;
}

CompilerException makeDollarOutsideOfIndex(ir.Constant constant, string file = __FILE__, const int line = __LINE__)
{
	auto doi = new CompilerError(constant.location, "'$' may only appear in an index expression.", file, line);
	return doi;
}

CompilerException makeBreakOutOfLoop(Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, "break may only appear in a loop or switch.", file, line);
	return e;
}

CompilerException makeAggregateDoesNotDefineOverload(Location loc, ir.Aggregate agg, string func, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, format("type '%s' does not define operator function '%s'.", agg.name, func), file, line);
	return e;
}

CompilerException makeBadWithType(Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, "with statement cannot use given expression.", file, line);
	return e;
}

CompilerException makeForeachReverseOverAA(ir.ForeachStatement fes, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(fes.location, "foreach_reverse cannot be used with an associative array.", file, line);
	return e;
}

CompilerException makeAnonymousAggregateRedefines(ir.Aggregate agg, string name, string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("anonymous aggregate redefines '%s'.", name);
	auto e = new CompilerError(agg.location, msg, file, line);
	return e;
}

CompilerException makeAnonymousAggregateAtTopLevel(ir.Aggregate agg, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(agg.location, "anonymous struct or union not inside aggregate.", file, line);
	return e;
}

CompilerException makeInvalidMainSignature(ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(func.location, "invalid main signature.", file, line);
	return e;
}

CompilerException makeNoValidFunction(Location loc, string fname, ir.Type[] args, string file = __FILE__, const int line = __LINE__)
{
	auto msg = format("no function named '%s' matches arguments %s.", fname, typesString(args));
	auto e = new CompilerError(loc, msg, file, line);
	return e;
}

CompilerException makeCVaArgsOnlyOperateOnSimpleTypes(Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, "C varargs only support retrieving simple types, due to an LLVM limitation.", file, line);
	return e;
}

CompilerException makeVaFooMustBeLValue(Location loc, string foo, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, format("argument to %s is not an lvalue.", foo), file, line);
	return e;
}

CompilerException makeNonLastVariadic(ir.Variable var, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(var.location, "variadic parameter must be last.", file, line);
	return e;
}

CompilerException makeStaticAssert(ir.AssertStatement as, string msg, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("static assert: %s", msg);
	auto e = new CompilerError(as.location, emsg, file, line);
	return e;
}

CompilerException makeConstField(ir.Variable v, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("const or immutable non local/global field '%s' is forbidden.", v.name);
	auto e = new CompilerError(v.location, emsg, file, line);
	return e;
}

CompilerException makeAssignToNonStaticField(ir.Variable v, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("attempted to assign to non local/global field %s.", v.name);
	auto e = new CompilerError(v.location, emsg, file, line);
	return e;
}

CompilerException makeSwitchBadType(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("bad switch type '%s'.", type.typeString());
	auto e = new CompilerError(node.location, emsg, file, line);
	return e;
}

CompilerException makeSwitchDuplicateCase(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(node.location, "duplicate case in switch statement.", file, line);
	return e;
}

CompilerException makeFinalSwitchBadCoverage(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(node.location, "final switch statement must cover all enum members.", file, line);
	return e;
}

CompilerException makeArchNotSupported(string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError("architecture not supported on current platform.", file, line);
}

CompilerException makeNotTaggedOut(ir.Exp exp, size_t i, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(exp.location, format("arguments to out parameters (like no. %s) must be tagged as out.", i+1), file, line);
}

CompilerException makeNotTaggedRef(ir.Exp exp, size_t i, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(exp.location, format("arguments to ref parameters (like no. %s) must be tagged as ref.", i+1), file, line);
}

CompilerException makeFunctionNameOutsideOfFunction(ir.TokenExp fexp, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(fexp.location, format("%s occurring outside of function.", fexp.type == ir.TokenExp.Type.PrettyFunction ? "__PRETTY_FUNCTION__" : "__FUNCTION__"), file, line);
}

CompilerException makeMultipleValidModules(ir.Node node, string[] paths, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("multiple modules are valid: %s.", paths), file, line);
}

CompilerException makeAlreadyLoaded(ir.Module m, string filename, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(m.location, format("module %s already loaded '%s'.", m.name.toString(), filename), file, line);
}

CompilerException makeCannotOverloadNested(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("cannot overload nested function '%s'.", func.name), file, line);
}

CompilerException makeUsedBeforeDeclared(ir.Node node, ir.Variable var, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("variable '%s' used before declaration.", var.name), file, line);
}


CompilerException makeStructConstructorsUnsupported(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, "struct constructors are currently unsupported.", file, line);
}

CompilerException makeCallingStaticThroughInstance(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("calling local or global function '%s' through instance variable.", func.name), file, line);
}

CompilerException makeMarkedOverrideDoesNotOverride(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("override functions like '%s' must override a function.", func.name), file, line);
}

CompilerException makeAbstractHasToBeMember(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("abstract functions like '%s' must be a member of an abstract class.", func.name), file, line);
}

CompilerException makeAbstractBodyNotEmpty(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("abstract functions like '%s' may not have an implementation.", func.name), file, line);
}

CompilerException makeNewAbstract(ir.Node node, ir.Class _class, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("abstract classes like '%s' may not be instantiated.", _class.name), file, line);
}

CompilerException makeBadAbstract(ir.Node node, ir.Attribute attr, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, "only classes and functions may be marked as abstract.", file, line);
}

CompilerException makeCannotImport(ir.Node node, ir.Import _import, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("can't find module '%s'.", _import.name), file, line);
}

CompilerException makeCannotImportAnonymous(ir.Node node, ir.Import _import, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("can't import anonymous module '%s'.", _import.name), file, line);
}

CompilerException makeNotAvailableInCTFE(ir.Node node, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("currently unevaluatable at compile time: '%s'.", s), file, line);
}

CompilerException makeNotAvailableInCTFE(ir.Node node, ir.Node feature, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("%s is currently unevaluatable at compile time.", ir.nodeToString(feature)), file, line);
}

CompilerException makeShadowsDeclaration(ir.Node a, ir.Node b, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(a.location, format("shadows declaration at %s.", b.location.toString()), file, line);
}

CompilerException makeMultipleDefaults(Location location, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, "switches may not have multiple default cases.", file, line);
}

CompilerException makeFinalSwitchWithDefault(Location location, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, "final switches may not define a default case.", file, line);
}

CompilerException makeNoDefaultCase(Location location, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, "switches must have a default case.", file, line);
}

CompilerException makeTryWithoutCatch(Location location, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, "try statement must have a catch block and/or a finally block.", file, line);
}

CompilerException makeMultipleOutBlocks(Location location, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, "a function may only have one in block defined.", file, line);
}

CompilerException makeNeedOverride(ir.Function overrider, ir.Function overridee, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("function '%s' overrides function at %s but is not marked with 'override'.", overrider.name, overridee.location.toString());
	return new CompilerError(overrider.location, emsg, file, line);
}

CompilerException makeThrowOnlyThrowable(ir.Exp exp, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("only types that inherit from object.Throwable may be thrown, not '%s'.", type.typeString());
	return new CompilerError(exp.location, emsg, file, line);
}

CompilerException makeThrowNoInherits(ir.Exp exp, ir.Class clazz, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("only types that inherit from object.Throwable may be thrown, not class '%s'.", clazz.typeString());
	return new CompilerError(exp.location, emsg, file, line);
}

CompilerException makeInvalidAAKey(ir.AAType aa, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(aa.location, format("'%s' is an invalid AA key.", aa.key.typeString()), file, line);
}

CompilerException makeBadAAAssign(Location location, string file = __FILE__, const int line = __LINE__)
{
    return new CompilerError(location, "may not assign associate arrays to prevent semantic inconsistencies.", file, line);
}

CompilerException makeBadAANullAssign(Location location, string file = __FILE__, const int line = __LINE__)
{
    return new CompilerError(location, "cannot set AA to null, use [] instead.", file, line);
}


/*
 *
 * General Util
 *
 */

CompilerException makeError(ir.Node n, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(n.location, s, file, line);
}

CompilerException makeError(Location location, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, s, file, line);
}

CompilerException makeUnsupported(Location location, string feature, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, format("unsupported feature '%s'.", feature), file, line);
}

CompilerException makeExpected(ir.Node node, string s, string file = __FILE__, const int line = __LINE__)
{
	return makeExpected(node.location, s, false, file, line);
}

CompilerException makeExpected(Location location, string s, bool b = false, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, format("expected %s.", s), b, file, line);
}

CompilerException makeExpected(Location location, string expected, string got, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, format("expected '%s', got '%s'.", expected, got), file, line);
}

CompilerException makeUnexpected(ir.Location location, string s, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, format("unexpected %s.", s), file, line);
}

CompilerException makeBadOperation(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, "bad operation.", file, line);
}

CompilerException makeExpectedContext(ir.Node node, ir.Node node2, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, "expected context pointer.", file, line);
}

CompilerException makeNotReached(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, "statement not reached.", file, line);
}


/*
 *
 * Type Conversions
 *
 */

CompilerException makeBadImplicitCast(ir.Node node, ir.Type from, ir.Type to, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("cannot implicitly convert %s to %s.", typeString(from), typeString(to));
	return new CompilerError(node.location, emsg, file, line);
}

CompilerException makeCannotModify(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("cannot modify '%s'.", type.typeString()), file, line);
}

CompilerException makeNotLValue(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, "expected lvalue.", file, line);
}

CompilerException makeTypeIsNot(ir.Node node, ir.Type from, ir.Type to, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("type '%s' is not '%s' as expected.", from.typeString(), to.typeString()), file, line);
}

CompilerException makeInvalidType(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("bad type '%s'.", type.typeString()), file, line);
}

CompilerException makeInvalidUseOfStore(ir.Node node, ir.Store store, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("invalid use of store '%s'.", store.name), file, line);
}


/*
 *
 * Lookups
 *
 */

CompilerException makeWithCreatesAmbiguity(Location loc, string file = __FILE__, const int line = __LINE__)
{
	auto e = new CompilerError(loc, "ambiguous lookup due to with block(s).", file, line);
	return e;
}

CompilerException makeInvalidThis(ir.Node node, ir.Type was, ir.Type expected, string member, string file = __FILE__, const int line = __LINE__)
{
	string emsg = format("'this' is of type '%s' expected '%s' to access member '%s'.", was.typeString(), expected.typeString(), member);
	return new CompilerError(node.location, emsg, file, line);
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
	return new CompilerError(node.location, emsg, file, line);
}

CompilerException makeNotMember(Location location, string aggregate, string member, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, format("'%s' has no member '%s'.", aggregate, member), file, line);
}

CompilerException makeFailedLookup(ir.Node node, string lookup, string file = __FILE__, const int line = __LINE__)
{
	return makeFailedLookup(node.location, lookup, file, line);
}

CompilerException makeFailedEnumLookup(Location location, string enumName, string name, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, format("enum '%s' does not define '%s'.", enumName, name), file, line);
}

CompilerException makeFailedLookup(Location location, string lookup, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, format("unidentified identifier '%s'.", lookup), file, line);
}

CompilerException makeNonTopLevelImport(Location location, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, "imports must occur in the top scope.", file, line);
}


/*
 *
 * Functions
 *
 */

CompilerException makeWrongNumberOfArguments(ir.Node node, size_t got, size_t expected, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("wrong number of arguments; got %s, expected %s.", got, expected), file, line);
}

CompilerException makeBadCall(ir.Node node, ir.Type type, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, format("cannot call '%s'.", type.typeString()), file, line);
}

CompilerException makeCannotDisambiguate(ir.Node node, ir.Function[] functions, ir.Type[] args, string file = __FILE__, const int line = __LINE__)
{
	return makeCannotDisambiguate(node.location, functions, args, file, line);
}

CompilerException makeCannotDisambiguate(Location location, ir.Function[] functions, ir.Type[] args, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, format("no '%s' function (of %s possible) matches arguments '%s'.", functions[0].name, functions.length, typesString(args)), file, line);
}

CompilerException makeCannotInfer(ir.Location location, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, "not enough information to infer type.", true, file, line);
}

CompilerException makeCannotLoadDynamic(ir.Node node, ir.Function func, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(node.location, "@loadDynamic function cannot have body.", file, line);
}

CompilerException makeMultipleFunctionsMatch(ir.Location location, ir.Function[] functions, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerError(location, format("%s overloaded functions match call.", functions.length), file, line);
}


/*
 *
 * Panics
 *
 */

CompilerException panicOhGod(ir.Node node, string file = __FILE__, const int line = __LINE__)
{
	return panic(node.location, "oh god.", file, line);
}

CompilerException panic(ir.Node node, string msg, string file = __FILE__, const int line = __LINE__)
{
	return panic(node.location, msg, file, line);
}

CompilerException panic(Location location, string msg, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerPanic(location, msg, file, line);
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
	return panicUnhandled(node.location, unhandled, file, line);
}

CompilerException panicUnhandled(Location location, string unhandled, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerPanic(location, format("unhandled case '%s'.", unhandled), file, line);
}

CompilerException panicNotMember(ir.Node node, string aggregate, string field, string file = __FILE__, const int line = __LINE__)
{
	auto str = format("no field name '%s' in aggregate '%s' '%s'.",
	                  field, aggregate, ir.nodeToString(node));
	return new CompilerPanic(node.location, str, file, line);
}

CompilerException panicExpected(ir.Location location, string msg, string file = __FILE__, const int line = __LINE__)
{
	return new CompilerPanic(location, format("expected %s.", msg), file, line);
}

void panicAssert(ir.Node node, bool condition, string file = __FILE__, const int line = __LINE__)
{
	if (!condition) {
		throw panic(node.location, "assertion failure.", file, line);
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
