// Copyright © 2012-2016, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.extyper;

import watt.conv : toString;
import watt.text.format : format;
import watt.text.string : replace;

import ir = volt.ir.ir;
import volt.ir.util;
import volt.ir.copy;

import volt.errors;
import volt.interfaces;
import volt.util.string;
import volt.token.location;

import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.visitor.prettyprinter;

import volt.semantic.util;
import volt.semantic.ctfe;
import volt.semantic.typer;
import volt.semantic.nested;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.context;
import volt.semantic.classify;
import volt.semantic.overload;
import volt.semantic.implicit;
import volt.semantic.classresolver;
import volt.semantic.storageremoval;
import volt.semantic.userattrresolver;


/**
 * This handles the auto that has been filled in, removing the auto storage.
 */
void replaceAutoIfNeeded(ref ir.Type type)
{
	auto autotype = cast(ir.AutoType) type;
	if (autotype !is null && autotype.explicitType !is null) {
		type = autotype.explicitType;
		type = flattenStorage(type);
		addStorage(type, autotype);
	}
}

/**
 * Does what the name implies.
 *
 * Checks if fn is null and is okay with more arguments the parameters.
 */
void appendDefaultArguments(Context ctx, ir.Location loc,
                            ref ir.Exp[] arguments, ir.Function fn)
{
	// Nothing to do.
	// Variadic functions may have more arguments then parameters.
	if (fn is null || arguments.length >= fn.params.length) {
		return;
	}

	ir.Exp[] overflow;
	foreach (p; fn.params[arguments.length .. $]) {
		if (p.assign is null) {
			throw makeExpected(loc, "default argument");
		}
		overflow ~= p.assign;
	}

	foreach (i, ee; overflow) {
		auto texp = cast(ir.TokenExp) ee;
		if (texp !is null) {
			texp.location = loc;
			arguments ~= texp;

			acceptExp(arguments[$-1], ctx.extyper);
		} else {
			assert(ee.nodeType == ir.NodeType.Constant);
			arguments ~= copyExp(loc, ee);
		}
	}
}

enum Parent
{
	NA,
	Call,
	Identifier,
	AssignTarget,
	AssignSource,
}

Parent classifyRelationship(ir.Exp child, ir.Exp parent)
{
	if (parent is null) {
		return Parent.NA;
	} else if (auto b = cast(ir.BinOp) parent) {
		if (b.op != ir.BinOp.Op.Assign) {
			return Parent.NA;
		}else if (b.left is child) {
			return Parent.AssignTarget;
		} else if (b.right is child) {
			return Parent.AssignSource;
		} else {
			assert(false);
		}
	} else if (auto p = cast(ir.Postfix) parent) {
		assert(p.child is child);
		if (p.op == ir.Postfix.Op.Call) {
			return Parent.Call;
		} else if (p.op == ir.Postfix.Op.Identifier) {
			return Parent.Identifier;
		} else {
			return Parent.NA;
		}
	} else {
		return Parent.NA;
	}
	version (Volt) assert(false);
}


/*
 *
 * Store resolution functions.
 *
 */

enum StoreSource
{
	Instance,
	Identifier,
	StaticPostfix,
}

void handleStore(Context ctx, string ident, ref ir.Exp exp, ir.Store store,
                 ir.Exp child, Parent parent,StoreSource via)
{
	final switch (store.kind) with (ir.Store.Kind) {
	case Type:
		handleTypeStore(ctx, ident, exp, store, child, parent, via);
		return;
	case Scope:
		handleScopeStore(ctx, ident, exp, store, child, parent, via);
		return;
	case Value:
		handleValueStore(ctx, ident, exp, store, child, parent, via);
		return;
	case Function:
		handleFunctionStore(ctx, ident, exp, store, child, parent, via);
		return;
	case FunctionParam:
		handleFunctionParamStore(ctx, ident, exp, store, child, parent,
		                         via);
		return;
	case EnumDeclaration:
		handleEnumDeclarationStore(ctx, ident, exp, store, child,
		                           parent, via);
		return;
	case Template:
		throw panic(exp, "template used as a value.");
	case Merge:
	case Alias:
		assert(false);
	}
}

void handleFunctionStore(Context ctx, string ident, ref ir.Exp exp,
                         ir.Store store, ir.Exp child, Parent parent,
                         StoreSource via)
{
	// Xor anybody?
	assert(via == StoreSource.Instance && child !is null ||
	       via != StoreSource.Instance && child is null);
	auto fns = store.functions;
	assert(fns.length > 0);

	size_t members;
	foreach (fn; fns) {
		if (fn.kind == ir.Function.Kind.Member ||
		    fn.kind == ir.Function.Kind.Destructor ||
		    fn.kind == ir.Function.Kind.Constructor) {
			members++;
		}

		// Check for nested functions.
		if (fn.nestedHiddenParameter !is null) {
			if (fns.length > 1) {
				throw makeCannotOverloadNested(fn, fn);
			}
			if (fn.type.isProperty) {
				throw panic("property nested functions not supported");
			}
			exp = buildExpReference(exp.location, fn, ident);
			return;
		}
	}

	// Check mixing member and non-member functions.
	// @TODO Should this really be an error?
	if (members != fns.length) {
		if (members > 0) {
			throw makeMixingStaticMember(exp.location);
		}
	}

	// Handle property functions.
	if (rewriteIfPropertyStore(exp, child, ident, parent, fns)) {

		// Do we need to add a this reference?
		auto prop = cast(ir.PropertyExp) exp;
		if (child !is null || !prop.isMember()) {
			return;
		}

		// Do the adding here.
		ir.Variable var;
		prop.child = getThisReferenceNotNull(exp, ctx, var);

		// TODO check that function and child match.
		// if (<checkMemberWantTypeMatchChildType>) {
		//	throw makeWrongTypeOfThis(want, have);
		//}

		// Don't do any more processing on properties.
		return;
	}

	if (members == 0 && via == StoreSource.Instance) {
		throw makeStaticViaInstance(exp.location, ident);
	}

	// Check if we can do overloading.
	if (fns.length > 1 &&
	    parent != Parent.Call &&
	    parent != Parent.AssignSource) {
		// Even if they are mixed, this a good enough guess.
		if (fns[0].kind == ir.Function.Kind.Member) {
			throw makeCannotPickMemberFunction(exp.location, ident);
		} else if (via == StoreSource.Instance) {
			throw makeCannotPickStaticFunctionVia(exp.location, ident);
		} else {
			throw makeCannotPickStaticFunction(exp.location, ident);
		}
	}

	// Do we need a instance?
	// If we we're not given one get the this for the given context.
	if (members > 0 && child is null) {
		ir.Variable thisVar;
		child = getThisReferenceNotNull(exp, ctx, thisVar);
	}

	// Will return the first function directly if there is only one.
	ir.Declaration decl = buildSet(exp.location, fns);
	ir.ExpReference eref = buildExpReference(exp.location, decl, ident);

	if (child !is null) {
		assert(members > 0);
		auto cdg = buildCreateDelegate(exp.location, child, eref);
		cdg.supressVtableLookup = via == StoreSource.StaticPostfix;
		exp = cdg;
	} else {
		assert(members == 0);
		exp = eref;
	}
}

void handleValueStore(Context ctx, string ident, ref ir.Exp exp,
                      ir.Store store, ir.Exp child, Parent parentKind, StoreSource via)
{
	// Xor anybody?
	assert(via == StoreSource.Instance && child !is null ||
	       via != StoreSource.Instance && child is null);

	auto var = cast(ir.Variable) store.node;
	assert(var !is null);
	assert(var.storage != ir.Variable.Storage.Invalid);

	ir.ExpReference makeEref() {
		auto eref = new ir.ExpReference();
		eref.idents = [ident];
		eref.location = exp.location;
		eref.decl = var;
		return eref;
	}

	final switch (via) with (StoreSource) {
	case Instance:
		if (var.storage != ir.Variable.Storage.Field) {
			throw makeAccessThroughWrongType(exp.location, ident);
		}
		// TODO check that field is from the this type.
		break;
	case Identifier:
		if (var.storage == ir.Variable.Storage.Function &&
		    !var.hasBeenDeclared) {
			throw makeUsedBeforeDeclared(exp, var);
		}

		auto eref = makeEref();
		// Set the exp.
		exp = eref;

		// Handle member functions accessing fields directly.
		replaceExpReferenceIfNeeded(ctx, exp, eref);

		// Handle nested variables.
		tagNestedVariables(ctx, var, store, exp);

		break;
	case StaticPostfix:
		final switch (var.storage) with (ir.Variable.Storage) {
		case Invalid:
			throw panic(exp, "invalid storage " ~ var.location.toString());
		case Field:
		case Function:
		case Nested:
			throw makeError(exp, "can not access fields and function variables via static lookups.");
		case Local:
		case Global:
			// Just a simple variable lookup.
			exp = makeEref();
			break;
		}
		break;
	}
}

void handleFunctionParamStore(Context ctx, string ident, ref ir.Exp exp,
                              ir.Store store, ir.Exp child, Parent parent,
                              StoreSource via)
{
	if (via == StoreSource.Instance) {
		throw makeError(exp, "can not access function parameter via value");
	}
	auto fp = cast(ir.FunctionParam) store.node;
	assert(fp !is null);

	auto eref = new ir.ExpReference();
	eref.idents = [ident];
	eref.location = exp.location;
	eref.decl = fp;
	exp = eref;
}

void handleEnumDeclarationStore(Context ctx, string ident, ref ir.Exp exp,
                                ir.Store store, ir.Exp child, Parent parent,
                                StoreSource via)
{
	if (via == StoreSource.Instance) {
		throw makeError(exp, "can not access enum via value");
	}

	auto ed = cast(ir.EnumDeclaration) store.node;
	assert(ed !is null);
	assert(ed.assign !is null);

//	// TODO This logic warrants futher investigation.
//	// The commented out code does not work, while the code below does.
//	auto ed = cast(ir.EnumDeclaration) store.node;
//	assert(ed !is null);
//	assert(ed.assign !is null);
//	exp = copyExp(ed.assign);

	auto eref = new ir.ExpReference();
	eref.idents = [ident];
	eref.location = exp.location;
	eref.decl = ed;
	exp = eref;
}

void handleTypeStore(Context ctx, string ident, ref ir.Exp exp, ir.Store store,
                     ir.Exp child, Parent parent, StoreSource via)
{
	if (via == StoreSource.Instance) {
		throw makeError(exp, "can not access types via value");
	}

	if (store.myScope !is null) {
		return handleScopeStore(ctx, ident, exp, store, child, parent, via);
	}

	auto t = cast(ir.Type) store.node;
	assert(t !is null);

	auto te = new ir.TypeExp();
	te.location = exp.location;
	//te.idents = [ident];
	te.type = copyTypeSmart(exp.location, t);
	exp = te;
}

void handleScopeStore(Context ctx, string ident, ref ir.Exp exp, ir.Store store,
                      ir.Exp child, Parent parent, StoreSource via)
{
	if (via == StoreSource.Instance) {
		throw makeError(exp, "can not access types via value");
	}

	auto se = new ir.StoreExp();
	se.location = exp.location;
	se.idents = [ident];
	se.store = store;
	exp = se;
}


/*
 *
 * extypeIdentifierExp code.
 *
 */

/**
 * If qname has a child of name leaf, returns an expression looking it up.
 * Otherwise, null is returned.
 */
ir.Exp withLookup(Context ctx, ref ir.Exp exp, ir.Scope current,
                  string leaf)
{
	ir.Exp access = buildAccess(exp.location, copyExp(exp), leaf);
	ir.Class _class;
	string emsg;
	ir.Scope eScope;
	auto type = realType(getExpType(ctx.lp, exp, current), false);
	if (exp.nodeType == ir.NodeType.Postfix) {
		retrieveScope(ctx.lp, type, cast(ir.Postfix)exp, eScope, _class, emsg);
	} else {
		retrieveScope(ctx.lp, type, cast(ir.Postfix)access, eScope, _class, emsg);
	}
	if (eScope is null) {
		throw makeBadWithType(exp.location);
	}
	auto store = lookupInGivenScopeOnly(ctx.lp, eScope, exp.location, leaf);
	if (store is null) {
		return null;
	}
	if (exp.nodeType == ir.NodeType.IdentifierExp) {
		extypePostfix(ctx, access, Parent.NA);
	}
	return access;
}

/**
 * Replace IdentifierExps with another exp, often ExpReference.
 */
void extypeIdentifierExp(Context ctx, ref ir.Exp e, ir.IdentifierExp i, ir.Exp parent)
{
	switch (i.value) {
	case "this":
		auto parentKind = classifyRelationship(i, parent);
		return rewriteThis(ctx, e, i, parentKind == Parent.Call);
	case "super":
		auto parentKind = classifyRelationship(i, parent);
		return rewriteSuper(ctx, e, i,
			parentKind == Parent.Call,
			parentKind == Parent.Identifier);
	default:
	}

	auto current = i.globalLookup ? getModuleFromScope(i.location, ctx.current).myScope : ctx.current;

	// Rewrite expressions that rely on a with block lookup.
	ir.Exp rewriteExp;
	if (!i.globalLookup) foreach_reverse (withExp; ctx.withExps) {
		auto _rewriteExp = withLookup(ctx, withExp, current, i.value);
		if (_rewriteExp is null) {
			continue;
		}
		if (rewriteExp !is null) {
			throw makeWithCreatesAmbiguity(i.location);
		}
		rewriteExp = _rewriteExp;
		rewriteExp.location = e.location;
		// Continue to ensure no ambiguity.
	}
	if (rewriteExp !is null) {
		auto store = lookup(ctx.lp, current, i.location, i.value);
		if (store !is null && isStoreLocal(ctx.lp, ctx.current, store)) {
			throw makeWithCreatesAmbiguity(i.location);
		}
		e = rewriteExp;
		acceptExp(e, ctx.extyper);
		return;
	}

	// With rewriting is completed after this point, and regular lookup logic resumes.
	auto store = lookup(ctx.lp, current, i.location, i.value);
	if (store is null) {
		throw makeFailedLookup(i, i.value);
	}

	auto parentKind = classifyRelationship(i, parent);
	handleStore(ctx, i.value, e, store, null, parentKind,
	            StoreSource.Identifier);
}


/*
 *
 * extypePostfixExp code.
 *
 */

bool replaceAAPostfixesIfNeeded(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	auto l = postfix.location;
	if (postfix.op == ir.Postfix.Op.Call) {
		assert(postfix.identifier is null);
		auto child = cast(ir.Postfix) postfix.child;
		if (child is null || child.identifier is null) {
			return false;
		}
		auto aa = cast(ir.AAType) realType(getExpType(ctx.lp, child.child, ctx.current));
		if (aa is null) {
			return false;
		}
		if (child.identifier.value != "get" && child.identifier.value != "remove") {
			return false;
		}
		bool keyIsArray = isArray(realType(aa.key));
		bool valIsArray = isArray(realType(aa.value));
		ir.ExpReference rtFn;
		ir.Exp[] args;
		if (child.identifier.value == "get") {
			if (postfix.arguments.length != 2) {
				return false;
			}
			args = new ir.Exp[](3);
			args[0] = copyExp(child.child);
			args[1] = copyExp(postfix.arguments[0]);
			args[2] = copyExp(postfix.arguments[1]);
			exp = buildAAGet(l, aa, args);
		} else if (child.identifier.value == "remove") {
			if (postfix.arguments.length != 1) {
				return false;
			}
			args = new ir.Exp[](2);
			args[0] = copyExp(child.child);
			args[1] = copyExp(postfix.arguments[0]);
			exp = buildAARemove(l, args);
		} else {
			panicAssert(child, false);
		}
		return true;
	}

	if (postfix.identifier is null) {
		return false;
	}
	auto aa = cast(ir.AAType) realType(getExpType(ctx.lp, postfix.child, ctx.current));
	if (aa is null) {
		return false;
	}
	ir.Exp[] arg = [copyExp(postfix.child)];
	switch (postfix.identifier.value) {
	case "keys":
		exp = buildAAKeys(l, aa, arg);
		return true;
	case "values":
		exp = buildAAValues(l, aa, arg);
		return true;
	case "length":
		exp = buildAALength(l, ctx.lp, arg);
		return true;
	case "rehash":
		exp = buildAARehash(l, arg);
		return true;
	case "get":
		return false;
	case "remove":
		return false;
	default:
		auto store = lookup(ctx.lp, ctx.current, postfix.location, postfix.identifier.value);
		if (store is null || store.functions.length == 0) {
			throw makeBadBuiltin(postfix.location, aa, postfix.identifier.value);
		}
		return false;
	}
	assert(false);
}

void handleArgumentLabelsIfNeeded(Context ctx, ir.Postfix postfix,
                                  ir.Function fn, ref ir.Exp exp)
{
	if (fn is null) {
		return;
	}
	size_t[string] positions;
	ir.Exp[string] defaults;
	size_t defaultArgCount;
	foreach (i, param; fn.params) {
		defaults[param.name] = param.assign;
		positions[param.name] = i;
		if (param.assign !is null) {
			defaultArgCount++;
		}
	}

	if (postfix.argumentLabels.length == 0) {
		if (fn.type.forceLabel && fn.type.params.length > defaultArgCount) {
			throw makeForceLabel(exp.location, fn);
		}
		return;
	}

	if (postfix.argumentLabels.length != postfix.arguments.length) {
		throw panic(exp.location, "argument count and label count unmatched");
	}

	// If they didn't provide all the arguments, try filling in any default arguments.
	if (postfix.arguments.length < fn.params.length) {
		bool[string] labels;
		foreach (label; postfix.argumentLabels) {
			labels[label] = true;
		}
		foreach (arg, def; defaults) {
			if (def is null) {
				continue;
			}
			if (auto p = arg in labels) {
				continue;
			}
			postfix.arguments ~= def;
			postfix.argumentLabels ~= arg;
			postfix.argumentTags ~= ir.Postfix.TagKind.None;
		}
	}

	if (postfix.arguments.length != fn.params.length) {
		throw makeWrongNumberOfArguments(postfix, postfix.arguments.length, fn.params.length);
	}

	// Reorder arguments to match parameter order.
	for (size_t i = 0; i < postfix.argumentLabels.length; i++) {
		auto argumentLabel = postfix.argumentLabels[i];
		auto p = argumentLabel in positions;
		if (p is null) {
			throw makeUnmatchedLabel(postfix.location, argumentLabel);
		}
		auto labelIndex = *p;
		if (labelIndex == i) {
			continue;
		}
		auto tmp = postfix.arguments[i];
		auto tmp2 = postfix.argumentLabels[i];
		auto tmp3 = postfix.argumentTags[i];
		postfix.arguments[i] = postfix.arguments[labelIndex];
		postfix.argumentLabels[i] = postfix.argumentLabels[labelIndex];
		postfix.argumentTags[i] = postfix.argumentTags[labelIndex];
		postfix.arguments[labelIndex] = tmp;
		postfix.argumentLabels[labelIndex] = tmp2;
		postfix.argumentTags[labelIndex] = tmp3;
		i = 0;
	}
	exp = postfix;
}

/// Given a.foo, if a is a pointer to a class, turn it into (*a).foo.
private void dereferenceInitialClass(ir.Postfix postfix, ir.Type type)
{
	if (!isPointerToClass(type)) {
		return;
	}

	postfix.child = buildDeref(postfix.child.location, postfix.child);
}

// Hand check va_start(vl) and va_end(vl), then modify their calls.
private void rewriteVaStartAndEnd(Context ctx, ir.Function fn,
                                  ir.Postfix postfix, ref ir.Exp exp)
{
	if (fn is ctx.lp.vaStartFunc ||
	    fn is ctx.lp.vaEndFunc ||
	    fn is ctx.lp.vaCStartFunc ||
	    fn is ctx.lp.vaCEndFunc) {
		if (postfix.arguments.length != 1) {
			throw makeWrongNumberOfArguments(postfix, postfix.arguments.length, 1);
		}
		auto etype = getExpType(ctx.lp, postfix.arguments[0], ctx.current);
		auto ptr = cast(ir.PointerType) etype;
		if (ptr is null || !isVoid(ptr.base)) {
			throw makeExpected(postfix, "va_list argument");
		}
		if (!isLValue(postfix.arguments[0])) {
			throw makeVaFooMustBeLValue(postfix.arguments[0].location, (fn is ctx.lp.vaStartFunc || fn is ctx.lp.vaCStartFunc) ? "va_start" : "va_end");
		}
		postfix.arguments[0] = buildAddrOf(postfix.arguments[0]);
		if (fn is ctx.lp.vaStartFunc) {
			assert(ctx.currentFunction.params[$-1].name == "_args");
			auto eref = buildExpReference(postfix.location, ctx.currentFunction.params[$-1], "_args");
			postfix.arguments ~= buildArrayPtr(postfix.location, buildVoid(postfix.location), eref);
		}
		if (ctx.currentFunction.type.linkage == ir.Linkage.Volt) {
			if (fn is ctx.lp.vaStartFunc) {
				exp = buildVaArgStart(postfix.location, postfix.arguments[0], postfix.arguments[1]);
				return;
			} else if (fn is ctx.lp.vaEndFunc) {
				exp = buildVaArgEnd(postfix.location, postfix.arguments[0]);
				return;
			} else {
				throw makeExpected(postfix.location, "volt va_args function.");
			}
		}
	}
}

private void rewriteVarargs(Context ctx,ir.CallableType asFunctionType,
                            ir.Postfix postfix)
{
	if (!asFunctionType.hasVarArgs ||
		asFunctionType.linkage != ir.Linkage.Volt) {
		return;
	}
	ir.ExpReference asExp;
	if (postfix.child.nodeType == ir.NodeType.Postfix) {
		assert(postfix.op == ir.Postfix.Op.Call);
		auto pfix = cast(ir.Postfix) postfix.child;
		assert(pfix !is null);
		assert(pfix.op == ir.Postfix.Op.CreateDelegate);
		assert(pfix.memberFunction !is null);
		asExp = pfix.memberFunction;
	}
	if (asExp is null) {
		asExp = cast(ir.ExpReference) postfix.child;
	}
	auto asFunction = cast(ir.Function) asExp.decl;
	assert(asFunction !is null);

	auto callNumArgs = postfix.arguments.length;
	auto funcNumArgs = asFunctionType.params.length - 2; // 2 == the two hidden arguments
	if (callNumArgs < funcNumArgs) {
		throw makeWrongNumberOfArguments(postfix, callNumArgs, funcNumArgs);
	}
	auto amountOfVarArgs = callNumArgs - funcNumArgs;
	auto argsSlice = postfix.arguments[0 .. funcNumArgs];
	auto varArgsSlice = postfix.arguments[funcNumArgs .. $];

	auto tinfoClass = ctx.lp.typeInfoClass;
	auto tr = buildTypeReference(postfix.location, tinfoClass, tinfoClass.name);
	tr.location = postfix.location;
	auto array = new ir.ArrayType();
	array.location = postfix.location;
	array.base = tr;

	auto typeidsLiteral = new ir.ArrayLiteral();
	typeidsLiteral.location = postfix.location;
	typeidsLiteral.type = array;

	int[] sizes;
	int totalSize;
	ir.Type[] types;
	foreach (i, _exp; varArgsSlice) {
		auto etype = getExpType(ctx.lp, _exp, ctx.current);
		if (ctx.lp.settings.internalD &&
		    realType(etype).nodeType == ir.NodeType.Struct) {
			warning(_exp.location, "passing struct to var-arg function.");
		}
		auto typeId = buildTypeidSmart(postfix.location, etype);
		typeidsLiteral.exps ~= typeId;
		types ~= etype;
		// TODO this probably isn't right.
		sizes ~= cast(int)size(ctx.lp, etype);
		totalSize += sizes[$-1];
	}

	postfix.arguments = argsSlice ~ typeidsLiteral ~ buildInternalArrayLiteralSliceSmart(postfix.location, buildArrayType(postfix.location, buildVoid(postfix.location)), types, sizes, totalSize, ctx.lp.memcpyFunc, varArgsSlice);
}

private void resolvePostfixOverload(Context ctx, ir.Postfix postfix,
                                    ir.ExpReference eref, ref ir.Function fn,
                                    ref ir.CallableType asFunctionType,
                                    ref ir.FunctionSetType asFunctionSet,
                                    bool reeval)
{
	if (eref is null) {
		throw panic(postfix.location, "expected expref");
	}
	asFunctionSet.set.reference = eref;
	fn = selectFunction(ctx.lp, ctx.current, asFunctionSet.set, postfix.arguments, postfix.location);
	eref.decl = fn;
	asFunctionType = fn.type;

	if (reeval) {
		replaceExpReferenceIfNeeded(ctx, postfix.child, eref);
	}
}

/**
 * Rewrite a call to a homogenous variadic if needed.
 * Makes individual parameters at the end into an array.
 */
private void rewriteHomogenousVariadic(Context ctx,
                                       ir.CallableType asFunctionType,
                                       ref ir.Exp[] arguments)
{
	if (!asFunctionType.homogenousVariadic || arguments.length == 0) {
		return;
	}
	auto i = asFunctionType.params.length - 1;
	auto etype = getExpType(ctx.lp, arguments[i], ctx.current);
	auto arr = cast(ir.ArrayType) asFunctionType.params[i];
	if (arr is null) {
		throw panic(arguments[0].location, "homogenous variadic not array type");
	}
	if (willConvert(etype, arr)) {
		return;
	}
	if (!typesEqual(etype, arr)) {
		auto exps = arguments[i .. $];
		if (exps.length == 1) {
			auto alit = cast(ir.ArrayLiteral) exps[0];
			if (alit !is null && alit.exps.length == 0) {
				exps = [];
			}
		}
		foreach (ref aexp; exps) {
			checkAndConvertStringLiterals(ctx, arr.base, aexp);
		}
		arguments[i] = buildInternalArrayLiteralSmart(arguments[0].location, asFunctionType.params[i], exps);
		arguments = arguments[0 .. i + 1];
		return;
	}
}

/**
 * Turns identifier postfixes into CreateDelegates,
 * and resolves property function calls in postfixes,
 * type safe varargs, and explicit constructor calls.
 */
void extypePostfixLeave(Context ctx, ref ir.Exp exp, ir.Postfix postfix,
                        Parent parent)
{
	if (postfix.arguments.length > 0) {
		ctx.enter(postfix);
		foreach (ref arg; postfix.arguments) {
			acceptExp(arg, ctx.extyper);
		}
		ctx.leave(postfix);
	}

	if (opOverloadRewriteIndex(ctx, postfix, exp)) {
		return;
	}

	if (replaceAAPostfixesIfNeeded(ctx, exp, postfix)) {
		return;
	}

	final switch (postfix.op) with (ir.Postfix.Op) {
	case Slice:
	case CreateDelegate:
		// TODO write checking code?
		break;
	case Increment:
	case Decrement:
		// TODO Check that child is a PrimtiveType.
		return;
	case Identifier:
		extypePostfixIdentifier(ctx, exp, postfix, parent);
		break;
	case Call:
		extypePostfixCall(ctx, exp, postfix);
		break;
	case Index:
		extypePostfixIndex(ctx, exp, postfix);
		break;
	case None:
		throw panic(postfix, "invalid op");
	}
}

void extypePostfixCall(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	assert(postfix.op == ir.Postfix.Op.Call);

	// This is a hack to handle UFCS
	auto b = cast(ir.BuiltinExp) postfix.child;
	if (b !is null && b.kind == ir.BuiltinExp.Kind.UFCS) {
		// Should we really call selectFunction here?
		auto arguments = b.children[0] ~ postfix.arguments;
		auto fn = selectFunction(ctx.lp, ctx.current, b.functions, arguments, postfix.location);

		if (fn is null) {
			throw makeNoFieldOrPropertyOrUFCS(postfix.location, postfix.identifier.value);
		}

		postfix.arguments = arguments;
		postfix.child = buildExpReference(postfix.location, fn, fn.name);
		// We are done, make sure that the rebuilt call isn't messed with when
		// it get visited again by the extypePostfix function.

		auto theTag = ir.Postfix.TagKind.None;
		if (fn.type.isArgRef[0]) {
			theTag = ir.Postfix.TagKind.Ref;
		} else if (fn.type.isArgOut[0]) {
			theTag = ir.Postfix.TagKind.Out;
		}

		postfix.argumentTags = theTag ~ postfix.argumentTags;
	}

	auto type = getExpType(ctx.lp, postfix.child, ctx.current);
	bool thisCall;

	ir.CallableType asFunctionType;
	auto asFunctionSet = cast(ir.FunctionSetType) realType(type);
	ir.Function fn;

	auto eref = cast(ir.ExpReference) postfix.child;
	bool reeval = true;

	if (eref is null) {
		reeval = false;
		auto pchild = cast(ir.Postfix) postfix.child;
		if (pchild !is null) {
			eref = cast(ir.ExpReference) pchild.memberFunction;
		}
	}

	if (asFunctionSet !is null) {
		resolvePostfixOverload(ctx, postfix, eref, fn, asFunctionType, asFunctionSet, reeval);
	} else if (eref !is null) {
		fn = cast(ir.Function) eref.decl;
		asFunctionType = cast(ir.CallableType) realType(type);
		if (asFunctionType is null) {
			if (asFunctionType is null) {
				auto _class = cast(ir.Class) type;
				if (_class !is null) {
					// this(blah);
					fn = selectFunction(ctx.lp, ctx.current, _class.userConstructors, postfix.arguments, postfix.location);
					asFunctionType = fn.type;
					eref.decl = fn;
					thisCall = true;
				} else {
					throw makeBadCall(postfix, type);
				}
			}
		}
	}

	if (asFunctionType is null) {
		asFunctionType = cast(ir.CallableType)type;
		if (asFunctionType is null) {
			return;
		}
	}

	handleArgumentLabelsIfNeeded(ctx, postfix, fn, exp);

	// Not providing an argument to a homogenous variadic function.
	if (asFunctionType.homogenousVariadic && postfix.arguments.length + 1 == asFunctionType.params.length) {
		postfix.arguments ~= buildArrayLiteralSmart(postfix.location, asFunctionType.params[$-1], []);
	}

	rewriteVaStartAndEnd(ctx, fn, postfix, exp);
	rewriteVarargs(ctx, asFunctionType, postfix);

	appendDefaultArguments(ctx, postfix.location, postfix.arguments, fn);
	if (!(asFunctionType.hasVarArgs || asFunctionType.params.length > 0 && asFunctionType.homogenousVariadic) &&
	    postfix.arguments.length != asFunctionType.params.length) {
		throw makeWrongNumberOfArguments(postfix, postfix.arguments.length, asFunctionType.params.length);
	}
	assert(asFunctionType.params.length <= postfix.arguments.length);
	rewriteHomogenousVariadic(ctx, asFunctionType, postfix.arguments);
	foreach (i; 0 .. asFunctionType.params.length) {
		if (asFunctionType.isArgRef[i] || asFunctionType.isArgOut[i]) {
			if (!isLValue(postfix.arguments[i])) {
				throw makeNotLValue(postfix.arguments[i]);
			}
			if (asFunctionType.isArgRef[i] &&
			    postfix.argumentTags[i] != ir.Postfix.TagKind.Ref &&
			    !ctx.lp.settings.internalD) {
				throw makeNotTaggedRef(postfix.arguments[i], i);
			}
			if (asFunctionType.isArgOut[i] &&
			    postfix.argumentTags[i] != ir.Postfix.TagKind.Out &&
			    !ctx.lp.settings.internalD) {
				throw makeNotTaggedOut(postfix.arguments[i], i);
			}
		}
		tagLiteralType(postfix.arguments[i], asFunctionType.params[i]);
		checkAndConvertStringLiterals(ctx, asFunctionType.params[i], postfix.arguments[i]);
	}

	if (thisCall) {
		// Explicit constructor call.
		auto tvar = getThisVarNotNull(postfix, ctx);
		auto tref = buildExpReference(postfix.location, tvar, "this");
		postfix.arguments = buildCastToVoidPtr(postfix.location, tref) ~ postfix.arguments;
	}
}

/**
 * This function acts as a extyperExpReference function would do,
 * but it also takes a extra type context which is used for the
 * cases when looking up Member variables via Types.
 *
 * pkg.mod.Class.member = 4;
 *
 * Even though FunctionSets might need rewriting they are not rewritten
 * directly but instead this function is called after they have been
 * rewritten and the ExpReference has been resolved to a single Function.
 */
void replaceExpReferenceIfNeeded(Context ctx, ref ir.Exp exp, ir.ExpReference eRef)
{
	// For vtable and property.
	if (eRef.rawReference) {
		return;
	}

	// Early out on static vars.
	// Or function sets.
	auto decl = eRef.decl;
	final switch (decl.declKind) with (ir.Declaration.Kind) {
	case Function:
		auto asFn = cast(ir.Function)decl;
		if (isFunctionStatic(asFn)) {
			return;
		}
		break;
	case Variable:
		auto asVar = cast(ir.Variable)decl;
		if (isVariableStatic(asVar)) {
			return;
		}
		break;
	case FunctionParam:
		return;
	case EnumDeclaration:
	case FunctionSet:
		return;
	case Invalid:
		throw panic(decl, "invalid declKind");
	}

	ir.Exp thisRef;
	ir.Variable thisVar;
	thisRef = getThisReferenceNotNull(eRef, ctx, thisVar);
	assert(thisRef !is null && thisVar !is null);

	auto tr = cast(ir.TypeReference) thisVar.type;
	assert(tr !is null);

	auto thisAgg = cast(ir.Aggregate) tr.type;
	auto referredType = thisAgg;
	auto expressionAgg = referredType;
	assert(thisAgg !is null);

	string ident = eRef.idents[$-1];
	auto store = lookupInGivenScopeOnly(ctx.lp, expressionAgg.myScope, exp.location, ident);
	if (store !is null && store.node !is eRef.decl) {
		if (eRef.decl.nodeType !is ir.NodeType.FunctionParam) {
			bool found = false;
			foreach (fn; store.functions) {
				if (fn is eRef.decl) {
					found = true;
				}
			}
			if (!found) {
				throw makeNotMember(eRef, expressionAgg, ident);
			}
		}
	}

	auto thisClass = cast(ir.Class) thisAgg;
	auto expressionClass = cast(ir.Class) expressionAgg;
	if (thisClass !is null && expressionClass !is null) {
		if (!thisClass.isOrInheritsFrom(expressionClass)) {
			throw makeInvalidType(exp, expressionClass);
		}
	} else if (thisAgg !is expressionAgg) {
		throw makeInvalidThis(eRef, thisAgg, expressionAgg, ident);
	}

	if (thisClass !is expressionClass) {
		thisRef = buildCastSmart(eRef.location, expressionClass, thisRef);
	}

	if (eRef.decl.declKind == ir.Declaration.Kind.Function) {
		exp = buildCreateDelegate(eRef.location, thisRef, eRef);
	} else {
		exp = buildAccess(eRef.location, thisRef, ident);
	}

	return;
}

/**
 * Turn identifier postfixes into <ExpReference>.ident.
 */
void consumeIdentsIfScopesOrTypes(Context ctx, ref ir.Postfix[] postfixes,
                                  ref ir.Exp exp, Parent parent)
{
	ir.Store lookStore; // The store that we are look in.
	ir.Scope lookScope; // The scope attached to the lookStore.
	ir.Type lookType;   // If lookStore is a type, the type.

	// Only consume identifiers.
	if (postfixes[0].op != ir.Postfix.Op.Identifier) {
		return;
	}

	void setupArrayAndExp(ir.Exp toReplace, size_t i)
	{
		if (i+1 >= postfixes.length) {
			exp = toReplace;
			postfixes = [];
		} else {
			postfixes[i+1].child = toReplace;
			postfixes = postfixes[i+1 .. $];
		}
	}

	if (!getIfStoreOrTypeExp(postfixes[0].child, lookStore, lookType)) {
		return;
	}

	// Early out on type only.
	if (lookStore is null) {
		assert(lookType !is null);
		ir.Exp toReplace = postfixes[0];
		if (typeLookup(ctx, toReplace, lookType)) {
			setupArrayAndExp(toReplace, 0);
		}
		// We have no scope to look in.
		return;
	}

	// Get a scope from said lookStore.
	lookScope = lookStore.myScope;
	assert(lookScope !is null);

	// Loop over the identifiers.
	foreach (i, postfix; postfixes) {
		// First check type.
		if (lookType !is null) {
			// Remove int.max etc.
			ir.Exp toReplace = postfixes[i];
			if (typeLookup(ctx, toReplace, lookType)) {
				setupArrayAndExp(toReplace, i);
				return;
			}
		}

		// Do the actual lookup.
		assert(postfix.identifier !is null);
		string name = postfix.identifier.value;
		auto store = lookupAsImportScope(ctx.lp, lookScope, postfix.location, name);
		if (store is null) {
			throw makeFailedLookup(postfix.location, name);
		}

		// Not the last ident, and this store has a scope.
		if (i+1 < postfixes.length &&
		    postfixes[i+1].op == ir.Postfix.Op.Identifier &&
		    store.myScope !is null) {
			lookStore = store;
			lookScope = store.myScope;
			lookType = cast(ir.Type) lookStore.node;
			continue;
		}

		auto parentKind = Parent.NA;
		// Are we the last postfix.
		if (i+1 >= postfixes.length) {
			parentKind = parent;
		} else {
			parentKind = classifyRelationship(postfix, postfixes[i+1]);
		}

		// Temporary set.
		ir.Exp toReplace = postfix;
		handleStore(ctx, name, toReplace, store, null, parentKind,
		            StoreSource.StaticPostfix);
		setupArrayAndExp(toReplace, i);
		return;
	}

	assert(false);
}

void extypePostfixIndex(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	assert(postfix.op == ir.Postfix.Op.Index);
	assert(postfix.arguments.length == 1);

	auto errorType = getExpType(ctx.lp, postfix.child, ctx.current);
	auto type = realType(errorType);
	switch (type.nodeType) with (ir.NodeType) {
	case AAType:
		auto aa = cast(ir.AAType)type;
		checkAndDoConvert(ctx, aa.key, postfix.arguments[0]);
		break;
	case StaticArrayType:
	case PointerType:
	case ArrayType:
		// TODO
		//auto sizeT = buildSizeT(exp.location, ctx.lp);
		//checkAndDoConvert(ctx, sizeT, postfix.arguments[0]);
		break;
	default:
		throw makeInvalidIndexValue(exp, errorType);
	}
}

/**
 * This function will check for ufcs functions on a Identifier postfix,
 * it assumes we have already looked for a field and not found anything.
 *
 * Volt does not support property ufcs functions.
 */
void postfixIdentifierUFCS(Context ctx, ref ir.Exp exp,
                           ir.Postfix postfix, Parent parent)
{
	assert(postfix.identifier !is null);

	auto store = lookup(ctx.lp, ctx.current, postfix.location, postfix.identifier.value);
	if (store is null || store.functions.length == 0) {
		throw makeNoFieldOrPropertyOrUFCS(postfix.location, postfix.identifier.value);
	}

	bool isProp;
	foreach (fn; store.functions) {
		if (isProp && !fn.type.isProperty) {
			throw makeUFCSAndProperty(postfix.location, postfix.identifier.value);
		}

		isProp = fn.type.isProperty;
	}

	if (isProp) {
		throw makeUFCSAsProperty(postfix.location);
	}

	// This is here to so that it errors
	if (parent != Parent.Call) {
		throw makeNoFieldOrPropertyOrIsUFCSWithoutCall(postfix.location, postfix.identifier.value);
	}

	auto type = getExpType(ctx.lp, postfix.child, ctx.current);
	auto set = buildSet(postfix.location, store.functions);

	exp = buildUFCS(postfix.location, type, postfix.child, store.functions);
}

bool builtInField(Context ctx, ref ir.Exp exp, ir.Exp child, ir.Type type, string field)
{
	bool isPointer;
	auto ptr = cast(ir.PointerType) type;
	if (ptr !is null) {
		isPointer = true;
		type = ptr.base;
	}

	auto array = cast(ir.ArrayType) type;
	auto sarray = cast(ir.StaticArrayType) type;
	if (sarray is null && array is null) {
		return false;
	}

	switch (field) {
	case "ptr":
		auto base = array is null ? sarray.base : array.base;
		assert(base !is null);

		if (isPointer) {
			child = buildDeref(exp.location, child);
		}
		exp = buildArrayPtr(exp.location, base, child);
		return true;
	case "length":
		if (isPointer) {
			child = buildDeref(exp.location, child);
		}
		exp = buildArrayLength(exp.location, ctx.lp, child);
		return true;
	default:
		// Error?
		return false;
	}
}

bool builtInField(ir.Type type, string field)
{
	auto aa = cast(ir.AAType) type;
	if (aa !is null) {
		return field == "length" ||
			field == "get" ||
			field == "remove" ||
			field == "keys" ||
			field == "values";
	}
	return false;
}

/**
 * Rewrite exp if the store contains any property functions, works
 * for both PostfixExp and IdentifierExp.
 *
 * Child can be null.
 */
bool rewriteIfPropertyStore(ref ir.Exp exp, ir.Exp child, string name,
                            Parent parent, ir.Function[] funcs)
{
	if (funcs.length == 0) {
		return false;
	}

	ir.Function   getFn;
	ir.Function[] setFns;

	foreach (fn; funcs) {
		if (!fn.type.isProperty) {
			continue;
		}

		if (fn.type.params.length > 1) {
			throw panic(fn, "property function with more than one argument.");
		} else if (fn.type.params.length == 1) {
			setFns ~= fn;
			continue;
		}

		// fn.params.length is 0

		if (getFn !is null) {
			throw makeMultipleZeroProperties(exp.location);
		}
		getFn = fn;
	}

	if (getFn is null && setFns.length == 0) {
		return false;
	}

	if (parent != Parent.AssignTarget && getFn is null) {
		throw makeNoZeroProperties(exp.location);
	}

	exp = buildProperty(exp.location, name, child, getFn, setFns);

	return true;
}

/**
 * Handling cases:
 *
 * inst.field               ( Any parent )
 * inst.inbuilt<field/prop> ( Any parent (no set inbuilt in Volt) )
 * inst.prop                ( Any parent )
 * inst.method              ( Any parent but Postfix.Op.Call )
 *
 * Check if there is a call on these cases.
 *
 * inst.inbuilt<function>() ( Postfix.Op.Call )
 * inst.method()            ( Postfix.Op.Call )
 * inst.ufcs()              ( Postfix.Op.Call )
 *
 * Error otherwise.
 */
void extypePostfixIdentifier(Context ctx, ref ir.Exp exp,
                             ir.Postfix postfix, Parent parent)
{
	assert(postfix.op == ir.Postfix.Op.Identifier);

	string field = postfix.identifier.value;

	ir.Type oldType = getExpType(ctx.lp, postfix.child, ctx.current);
	ir.Type type = realType(oldType, false);
	assert(type !is null);
	assert(type.nodeType != ir.NodeType.FunctionSetType);
	if (builtInField(ctx, exp, postfix.child, type, field)) {
		return;
	}
	if (builtInField(type, field)) {
		// TODO might not be needed.
		replaceAAPostfixesIfNeeded(ctx, exp, postfix);
		return;
	}

	// If we are pointing to a pointer to a class.
	dereferenceInitialClass(postfix, oldType);

	// Get store for ident on type, do not look for ufcs functions.
	ir.Store store;
	auto _scope = getScopeFromType(type);
	if (_scope !is null) {
		store = lookupAsThisScope(ctx.lp, _scope, postfix.location, field);
	}

	if (store is null) {
		// Check if there is a UFCS function.
		// Note that Volt doesn't not support UFCS get/set properties
		// unlike D which does, this is because we are going to
		// remove properties in favor for C# properties.

		postfixIdentifierUFCS(ctx, exp, postfix, parent);

		// postfixIdentifierUFCS will error so if we get here all is good.
		return;
	}

	// We are looking up via a instance error on static vars and types.
	// The two following cases are handled by the consumeIdents code:
	// pkg.mod.Class.staticVar
	// pkg.mod.Class.Enum
	//
	// But this is an error:
	// pkg.mode.Class instance;
	// instance.Enum
	// instance.staticVar
	//
	// @todo will the code be stupid and do this:
	// staticVar++ --> lowered to this.staticVar++ in a member function.
	//
	//if (<check>) {
	//	throw makeBadLookup();
	//}

	// Is the store a field on the object.
	auto store2 = lookupOnlyThisScopeAndClassParents(
		ctx.lp, _scope, postfix.location, field);
	assert(store2 !is null);

	// What if store and store2 fields does not match?
	// TODO this should be handled by the handleStore functions,
	// pereferedly looking at childs type and see if they match.
	auto var = cast(ir.Variable) store.node;
	auto var2 = cast(ir.Variable) store.node;
	if (var !is null && var !is var2 &&
	    var.storage == ir.Variable.Storage.Field) {
		throw makeAccessThroughWrongType(postfix.location, field);
	}

	handleStore(ctx, field, exp, store, postfix.child, parent,
	            StoreSource.Instance);
}

void extypePostfix(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto postfix = cast(ir.Postfix)exp;
	auto allPostfixes = collectPostfixes(postfix);

	// Process first none postfix exp, often a IdentifierExp.
	// 'ident'.field.prop
	// 'typeid(int)'.mangledName
	// 'int'.max
	auto top = allPostfixes[0];
	if (top.child.nodeType == ir.NodeType.IdentifierExp) {
		auto ie = cast(ir.IdentifierExp) top.child;
		extypeIdentifierExp(ctx, top.child, ie, top);
	} else {
		acceptExp(allPostfixes[0].child, ctx.extyper);
	}

	consumeIdentsIfScopesOrTypes(ctx, allPostfixes, exp, parent);

	// Now process the list of postfixes.
	while (allPostfixes.length > 0) {

		// front
		auto working = allPostfixes[0];
		// popFront this way we advance and know if we have more.
		allPostfixes = allPostfixes[1 .. $];

		if (allPostfixes.length == 0) {
			// Exp points to the field in parent where the initial
			// postfix is stored.

			// The last element should be exp.
			assert(working is exp);

			extypePostfixLeave(ctx, exp, working, parent);
		} else {
			// Set the next in line as parent. This allows handling
			// of bar.ufcs(4, 5) and the like.
			auto tmp = allPostfixes[0];

			// Make sure we haven't rewritten this yet.
			assert(tmp.child is working);

			auto parentKind = classifyRelationship(working, tmp);
			extypePostfixLeave(ctx, tmp.child, working, parentKind);
		}
	}
	// The postfix parameter is stale now, don't touch it.
}


/*
 *
 * extypeUnary code.
 *
 */

/**
 * Stops casting to an overloaded function name, casting from null, and wires
 * up some runtime magic needed for classes.
 */
void extypeUnaryCastTo(Context ctx, ref ir.Exp exp, ir.Unary unary)
{
	assert(unary.type !is null);
	assert(unary.value !is null);

	auto type = realType(getExpType(ctx.lp, unary.value, ctx.current));
	if (type.nodeType == ir.NodeType.FunctionSetType) {
		auto fset = cast(ir.FunctionSetType) type;
		throw makeCannotDisambiguate(unary, fset.set.functions, null);
	}

	// Handling cast(Foo)null
	if (handleIfNull(ctx, unary.type, unary.value)) {
		exp = unary.value;
		return;
	}

	auto to = getClass(unary.type);
	auto from = getClass(type);

	if (to is null || from is null || to is from) {
		return;
	}

	auto fnref = buildExpReference(unary.location, ctx.lp.castFunc, "vrt_handle_cast");
	auto tid = buildTypeidSmart(unary.location, to);
	auto val = buildCastToVoidPtr(unary.location, unary.value);
	unary.value = buildCall(unary.location, fnref, [val, cast(ir.Exp)tid]);
}

/**
 * Type new expressions.
 */
void extypeUnaryNew(Context ctx, ref ir.Exp exp, ir.Unary _unary)
{
	assert(_unary.type !is null);

	if (!_unary.hasArgumentList) {
		return;
	}

	auto at = cast(ir.AutoType) _unary.type;
	if (at !is null) {
		if (_unary.argumentList.length == 0) {
			throw makeExpected(_unary, "argument(s)");
		}
		_unary.type = copyTypeSmart(_unary.location, getExpType(ctx.lp, _unary.argumentList[0], ctx.current));
	}
	auto array = cast(ir.ArrayType) _unary.type;
	if (array !is null) {
		if (_unary.argumentList.length == 0) {
			throw makeExpected(_unary, "argument(s)");
		}
		bool isArraySize = isIntegral(getExpType(ctx.lp, _unary.argumentList[0], ctx.current));
		foreach (ref arg; _unary.argumentList) {
			auto type = getExpType(ctx.lp, arg, ctx.current);
			if (isIntegral(type)) {
				if (isArraySize) {
					// multi/one-dimensional array:
					//   new type[](1)
					//   new type[](1, 2, ...)
					continue;
				}
				throw makeExpected(arg, "array");
			} else if (isArraySize) {
				throw makeExpected(arg, "array size");
			}

			// it's a concatenation or copy:
			//   new type[](array1)
			//   new type[](array1, array2, ...)
			auto asArray = cast(ir.ArrayType) type;
			if (asArray is null) {
				throw makeExpected(arg, "array");
			}
			if (!typesEqual(asArray, array) &&
			    !isImplicitlyConvertable(asArray, array)) {
				if (typesEqual(asArray, array, true) &&
					(array.isConst || array.isImmutable ||
					array.base.isConst || array.base.isImmutable ||
					!mutableIndirection(array.base))) {
					// char[] buf;
					// auto str = new string(buf);
					continue;
				}
				throw makeBadImplicitCast(arg, asArray, array);
			}
		}
	}

	auto tr = cast(ir.TypeReference) _unary.type;
	if (tr is null) {
		return;
	}
	auto _struct = cast(ir.Struct) tr.type;
	if (_struct !is null) {
		assert(_unary.hasArgumentList);
		throw makeStructConstructorsUnsupported(_unary);
	}
	auto _class = cast(ir.Class) tr.type;
	if (_class is null) {
		return;
	}

	if (_class.isAbstract) {
		throw makeNewAbstract(_unary, _class);
	}

	// Needed because of userConstructors.
	ctx.lp.actualize(_class);

	auto fn = selectFunction(ctx.lp, ctx.current, _class.userConstructors, _unary.argumentList, _unary.location);
	_unary.ctor = fn;

	ctx.lp.resolve(ctx.current, fn);

	appendDefaultArguments(ctx, _unary.location, _unary.argumentList, fn);
	if (_unary.argumentList.length > 0) {
		rewriteHomogenousVariadic(ctx, fn.type, _unary.argumentList);
	}

	for (size_t i = 0; i < _unary.argumentList.length; ++i) {
		checkAndDoConvert(ctx, fn.type.params[i], _unary.argumentList[i]);
	}
}

/**
 * Lower 'new foo[0 .. $]' expressions to BuiltinExps.
 */
void extypeUnaryDup(Context ctx, ref ir.Exp exp, ir.Unary _unary)
{
	panicAssert(_unary, _unary.dupName !is null);
	panicAssert(_unary, _unary.dupBeginning !is null);
	panicAssert(_unary, _unary.dupEnd !is null);

	auto l = exp.location;
	if (!ctx.isFunction) {
		throw makeExpected(l, "function context");
	}

	auto type = getExpType(ctx.lp, _unary.value, ctx.current);
	auto asStatic = cast(ir.StaticArrayType)realType(type);
	if (asStatic !is null) {
		type = buildArrayTypeSmart(asStatic.location, asStatic.base);
	}

	auto rtype = realType(type);
	if (rtype.nodeType != ir.NodeType.AAType &&
	    rtype.nodeType != ir.NodeType.ArrayType) {
		throw makeCannotDup(l, rtype);
	}

	if (rtype.nodeType == ir.NodeType.AAType) {
		if (!_unary.fullShorthand) {
			// Actual indices were used, which makes no sense for AAs.
			throw makeExpected(l, format("new %s[..]", _unary.dupName));
		}
		auto aa = cast(ir.AAType)rtype;
		panicAssert(rtype, aa !is null);
		exp = buildAADup(l, aa, [_unary.value]);
	} else {
		exp = buildArrayDup(l, rtype, [copyExp(_unary.value), copyExp(_unary.dupBeginning), copyExp(_unary.dupEnd)]);
	}
}

void extypeUnary(Context ctx, ref ir.Exp exp, ir.Unary _unary)
{
	switch (_unary.op) with (ir.Unary.Op) {
	case Cast:
		return extypeUnaryCastTo(ctx, exp, _unary);
	case New:
		return extypeUnaryNew(ctx, exp, _unary);
	case Dup:
		return extypeUnaryDup(ctx, exp, _unary);
	default:
	}
}


/*
 *
 * extypeBinOp code.
 *
 */

/**
 * Everyone's favourite: integer promotion! :D!
 * In general, converts to the largest type needed in a binary expression.
 */
void extypeBinOp(Context ctx, ir.BinOp bin, ir.PrimitiveType lprim, ir.PrimitiveType rprim)
{
	auto intsz = size(ir.PrimitiveType.Kind.Int);
	auto shortsz = size(ir.PrimitiveType.Kind.Short);

	auto leftsz = size(lprim.type);
	auto rightsz = size(rprim.type);

	if (isIntegral(lprim) && isIntegral(rprim)) {
		bool leftUnsigned = isUnsigned(lprim.type);
		bool rightUnsigned = isUnsigned(rprim.type);
		if (leftUnsigned != rightUnsigned) {
			// Cast constants.
			if (leftUnsigned) {
				if (fitsInPrimitive(lprim, bin.right)) {
					bin.right = buildCastSmart(lprim, bin.right);
					rightUnsigned = true;
					rightsz = leftsz;
				}
			} else {
				if (fitsInPrimitive(rprim, bin.left)) {
					bin.left = buildCastSmart(rprim, bin.left);
					leftUnsigned = true;
					leftsz = rightsz;
				}
			}
			bool smallerUnsigned = leftsz < rightsz ? leftUnsigned : rightUnsigned;
			size_t smallersz = leftsz < rightsz ? leftsz : rightsz;
			size_t biggersz = leftsz > rightsz ? leftsz : rightsz;
			if ((leftsz <= shortsz && rightsz <= shortsz) || (smallerUnsigned && smallersz < biggersz)) {
				// Safe.
			} else if (leftUnsigned != rightUnsigned) {
				throw makeMixedSignedness(bin.location);
			}
		}
	}

	if (bin.op != ir.BinOp.Op.Assign &&
	    bin.op != ir.BinOp.Op.Is &&
	    bin.op != ir.BinOp.Op.NotIs &&
	    bin.op != ir.BinOp.Op.Equal &&
	    bin.op != ir.BinOp.Op.NotEqual) {
		if (isBool(lprim)) {
			auto i = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
			lprim = i;
			bin.left = buildCastSmart(i, bin.left);
		}
		if (isBool(rprim)) {
			auto i = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
			rprim = i;
			bin.right = buildCastSmart(i, bin.right);
		}
	}

	size_t largestsz;
	ir.Type largestType;

	if ((isFloatingPoint(lprim) && isFloatingPoint(rprim)) ||
	    (isIntegral(lprim) && isIntegral(rprim))) {
		if (leftsz > rightsz) {
			largestsz = leftsz;
			largestType = lprim;
		} else {
			largestsz = rightsz;
			largestType = rprim;
		}

		if (bin.op != ir.BinOp.Op.Assign && intsz > largestsz && isIntegral(lprim)) {
			largestsz = intsz;
			largestType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
		}

		if (leftsz < largestsz) {
			bin.left = buildCastSmart(largestType, bin.left);
		}

		if (rightsz < largestsz) {
			bin.right = buildCastSmart(largestType, bin.right);
		}

		return;
	}

	if (isFloatingPoint(lprim) && isIntegral(rprim)) {
		bin.right = buildCastSmart(lprim, bin.right);
	} else {
		bin.left = buildCastSmart(rprim, bin.left);
	}
}

/**
 * If the given binop is working on an aggregate
 * that overloads that operator, rewrite a call to that overload.
 */
bool opOverloadRewrite(Context ctx, ir.BinOp binop, ref ir.Exp exp)
{
	auto l = exp.location;
	auto _agg = opOverloadableOrNull(getExpType(ctx.lp, binop.left, ctx.current));
	if (_agg is null) {
		return false;
	}
	bool neg = binop.op == ir.BinOp.Op.NotEqual;
	string overfn = overloadName(neg ? ir.BinOp.Op.Equal : binop.op);
	if (overfn.length == 0) {
		return false;
	}
	auto store = lookupAsThisScope(ctx.lp, _agg.myScope, l, overfn);
	if (store is null || store.functions.length == 0) {
		throw makeAggregateDoesNotDefineOverload(exp.location, _agg, overfn);
	}
	auto fn = selectFunction(ctx.lp, ctx.current, store.functions, [binop.right], l);
	assert(fn !is null);
	exp = buildCall(l, buildCreateDelegate(l, binop.left, buildExpReference(l, fn, overfn)), [binop.right]);
	if (neg) {
		exp = buildNot(l, exp);
	}
	return true;
}

/**
 * If this postfix operates on an aggregate with an index
 * operator overload, rewrite it.
 */
bool opOverloadRewriteIndex(Context ctx, ir.Postfix pfix, ref ir.Exp exp)
{
	if (pfix.op != ir.Postfix.Op.Index) {
		return false;
	}
	auto type = getExpType(ctx.lp, pfix.child, ctx.current);
	auto _agg = opOverloadableOrNull(type);
	if (_agg is null) {
		return false;
	}
	auto name = overloadIndexName();
	auto store = lookupAsThisScope(ctx.lp, _agg.myScope, exp.location, name);
	if (store is null || store.functions.length == 0) {
		throw makeAggregateDoesNotDefineOverload(exp.location, _agg, name);
	}
	assert(pfix.arguments.length > 0 && pfix.arguments[0] !is null);
	auto fn = selectFunction(ctx.lp, ctx.current, store.functions, [pfix.arguments[0]], exp.location);
	assert(fn !is null);
	pfix = buildCall(exp.location, buildCreateDelegate(exp.location, pfix.child, buildExpReference(exp.location, fn, name)), [pfix.arguments[0]]);
	exp = pfix;

	extypePostfixCall(ctx, exp, pfix);

	return true;
}

bool extypeBinOpPropertyAssign(Context ctx, ir.BinOp binop, ref ir.Exp exp)
{
	if (binop.op != ir.BinOp.Op.Assign) {
		return false;
	}
	auto p = cast(ir.PropertyExp) binop.left;
	if (p is null) {
		return false;
	}

	auto args = [binop.right];
	auto fn = selectFunction(
		ctx.lp, ctx.current,
		p.setFns, args,
		binop.location, DoNotThrow);

	auto name = p.identifier.value;
	auto expRef = buildExpReference(binop.location, fn, name);

	if (p.child is null) {
		exp = buildCall(binop.location, expRef, args);
	} else {
		exp = buildMemberCall(binop.location,
		                      p.child,
		                      expRef, name, args);
	}

	return true;
}

/**
 * Handles logical operators (making a && b result in a bool),
 * binary of storage types, otherwise forwards to assign or primitive
 * specific functions.
 */
void extypeBinOp(Context ctx, ir.BinOp binop, ref ir.Exp exp)
{
	bool isAssign = .isAssign(binop.op);

	if (extypeBinOpPropertyAssign(ctx, binop, exp)) {
		return;
	}

	ir.Type ltype, rtype;
	{
		auto lraw = getExpType(ctx.lp, binop.left, ctx.current);
		auto rraw = getExpType(ctx.lp, binop.right, ctx.current);
		ltype = realType(removeRefAndOut(lraw));
		rtype = realType(removeRefAndOut(rraw));
	}

	if (isAssign) {
		checkConst(exp, ltype);
	}

	if (handleIfNull(ctx, rtype, binop.left)) {
		ltype = rtype; // Update the type.
	}
	if (handleIfNull(ctx, ltype, binop.right)) {
		rtype = ltype; // Update the type.
	}

	if (opOverloadRewrite(ctx, binop, exp)) {
		return;
	}

	auto lclass = cast(ir.Class)ltype;
	auto rclass = cast(ir.Class)rtype;
	if (lclass !is null && rclass !is null && !typesEqual(lclass, rclass)) {
		auto common = commonParent(lclass, rclass);
		if (lclass !is common) {
			binop.left = buildCastSmart(exp.location, common, binop.left);
			rtype = ltype;
		}
		if (rclass !is common) {
			binop.right = buildCastSmart(exp.location, common, binop.right);
			rtype = ltype;
		}
	}

	// key in aa => some_vrt_call(aa, key)
	if (binop.op == ir.BinOp.Op.In) {
		auto asAA = cast(ir.AAType) rtype;
		if (asAA is null) {
			throw makeExpected(binop.right.location, "associative array");
		}
		checkAndDoConvert(ctx, asAA.key, binop.left);
		auto l = binop.location;
		ir.Exp rtFn, key;
		if (isArray(ltype)) {
			key = buildCast(l, buildArrayType(l, buildVoid(l)), copyExp(binop.left));
		} else {
			key = buildCast(l, buildUlong(l), copyExp(binop.left));
		}
		assert(key !is null);
		exp = buildAAIn(l, asAA, [copyExp(binop.right), binop.left]);
		return;
	}

	// Check for lvalue and touch up aa[key] = 'left'.
	if (isAssign) {
		if (!isAssignable(binop.left)) {
			throw makeExpected(binop.left.location, "lvalue");
		}

		auto asPostfix = cast(ir.Postfix)binop.left;
		if (asPostfix !is null) {
			auto postfixLeft = getExpType(ctx.lp, asPostfix.child, ctx.current);
			if (postfixLeft !is null &&
			    postfixLeft.nodeType == ir.NodeType.AAType &&
			    asPostfix.op == ir.Postfix.Op.Index) {
				auto aa = cast(ir.AAType)postfixLeft;

				checkAndDoConvert(ctx, aa.value, binop.right);
			}
		}
	}

	if (!isAssign) {
		// We may return any of these types, remove storage modifiers
		// its a value we return not a reference to them.
		ltype = removeStorageFields(ltype);
		rtype = removeStorageFields(rtype);
	} else {
		// No need to scrub the storage from the source if we are
		// assigning, we will always return the ltype in that case.
	}

	bool assigningOutsideFunction;
	if (auto eref = cast(ir.ExpReference)binop.left) {
		auto var = cast(ir.Variable) eref.decl;
		assigningOutsideFunction = var !is null && var.storage != ir.Variable.Storage.Function;
	}
	if (assigningOutsideFunction && rtype.isScope && mutableIndirection(ltype) && isAssign && !binop.isInternalNestedAssign) {
		throw makeNoEscapeScope(exp.location);
	}


	if (binop.op == ir.BinOp.Op.Assign) {
		if (effectivelyConst(ltype)) {
			throw makeCannotModify(binop, ltype);
		}

		auto postfixl = cast(ir.Postfix)binop.left;
		auto postfixr = cast(ir.Postfix)binop.right;
		bool copying = postfixl !is null && postfixl.op == ir.Postfix.Op.Slice;
		tagLiteralType(binop.right, ltype);
		if (copying) {
			if (!typesEqual(ltype, rtype, IgnoreStorage)) {
				throw makeExpectedTypeMatch(binop.location, ltype);
			}
		} else {
			checkAndDoConvert(ctx, ltype, binop.right);
		}

		return;
	}

	if (binop.op == ir.BinOp.Op.AndAnd || binop.op == ir.BinOp.Op.OrOr) {
		auto boolType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		if (!typesEqual(ltype, boolType)) {
			binop.left = buildCastSmart(boolType, binop.left);
		}
		if (!typesEqual(rtype, boolType)) {
			binop.right = buildCastSmart(boolType, binop.right);
		}
		return;
	}

	auto larray = cast(ir.ArrayType)ltype;
	auto rarray = cast(ir.ArrayType)rtype;
	if ((binop.op == ir.BinOp.Op.Cat ||
	     binop.op == ir.BinOp.Op.CatAssign) &&
	    (larray !is null || rarray !is null)) {
		if (binop.op == ir.BinOp.Op.CatAssign &&
		    effectivelyConst(ltype)) {
			throw makeCannotModify(binop, ltype);
		}
		bool swapped = binop.op != ir.BinOp.Op.CatAssign && larray is null;
		if (swapped) {
			extypeCat(ctx, binop.right, binop.left, rarray, ltype);
		} else {
			extypeCat(ctx, binop.left, binop.right, larray, rtype);
		}
		return;
	}

	// We only get here if op != Cat && op != CatAssign.
	if ((larray is null && rarray !is null) ||
	    (larray !is null && rarray is null)) {
	    throw makeArrayNonArrayNotCat(binop.location);
	}

	if (ltype.nodeType == ir.NodeType.PrimitiveType &&
	    rtype.nodeType == ir.NodeType.PrimitiveType) {
		auto lprim = cast(ir.PrimitiveType) ltype;
		auto rprim = cast(ir.PrimitiveType) rtype;
		assert(lprim !is null && rprim !is null);
		extypeBinOp(ctx, binop, lprim, rprim);
		return;
	}

	// Handle 'exp' is 'exp', types must match.
	// This needs to come after the primitive type check,
	// But before the pointer arithmetic check.
	if (binop.op == ir.BinOp.Op.NotIs ||
	    binop.op == ir.BinOp.Op.Is) {
		if (!typesEqual(ltype, rtype)) {
			throw makeError(binop, "types must match for 'is'.");
		}
		return;
	}

	// Handle pointer arithmetics.
	if (ltype.nodeType == ir.NodeType.PointerType) {
		switch (binop.op) with (ir.BinOp.Op) {
		case AddAssign, SubAssign, Add, Sub:
			break;
		default:
			throw makeError(binop, "illegal pointer arithemetic.");
		}
		auto rprim = cast(ir.PrimitiveType) rtype;
		if (rprim is null || !isOkayForPointerArithmetic(rprim.type)) {
			throw makeError(binop, "illegal pointer arithemetic invalid type.");
		}
		return;
	}

	// Default
	if (!typesEqual(ltype, rtype)) {
		makeError(binop, "missmatch types.");
	}
}


/*
 *
 * Other extype code.
 *
 */

/**
 * Ensure concatentation is sound.
 */
void extypeCat(Context ctx, ref ir.Exp lexp, ref ir.Exp rexp,
               ir.ArrayType left, ir.Type right)
{
	if (typesEqual(left, right) ||
	    typesEqual(right, left.base)) {
		return;
	}

	void getClass(ir.Type t, ref int depth, ref ir.Class _class)
	{
		depth = 0;
		_class = cast(ir.Class)realType(t);
		auto array = cast(ir.ArrayType)realType(t);
		while (array !is null && _class is null) {
			depth++;
			_class = cast(ir.Class)realType(array.base);
			array = cast(ir.ArrayType)realType(array.base);
		}
	}

	ir.Type buildDeepArraySmart(Location location, int depth, ir.Type base)
	{
		ir.ArrayType array = new ir.ArrayType();
		array.location = location;
		auto firstArray = array;
		for (size_t i = 1; i < cast(size_t) depth; ++i) {
			array.base = new ir.ArrayType();
			array.base.location = location;
			array = cast(ir.ArrayType)array.base;
		}
		array.base = copyTypeSmart(location, base);
		return firstArray;
	}

	ir.Class lclass, rclass;
	int ldepth, rdepth;
	getClass(left, ldepth, lclass);
	getClass(right, rdepth, rclass);
	if (lclass !is null && rclass !is null) {
		auto _class = commonParent(lclass, rclass);
		if (ldepth >= 1 && ldepth == rdepth) {
			auto l = lexp.location;
			if (lclass !is _class) {
				lexp = buildCastSmart(buildDeepArraySmart(l, ldepth, _class), lexp);
			}
			if (rclass !is _class) {
				rexp = buildCastSmart(buildDeepArraySmart(l, rdepth, _class), rexp);
			}
			return;
		} else if (ldepth == 0 || rdepth == 0) {
			if (ldepth == 0 && lclass !is _class) {
				lexp = buildCastSmart(_class, lexp);
				return;
			} else if (rdepth == 0 && rclass !is _class) {
				rexp = buildCastSmart(_class, rexp);
				return;
			}
		}
	}

	auto rarray = cast(ir.ArrayType) realType(right);
	if (rarray !is null && isImplicitlyConvertable(rarray.base, left.base)) {
		return;
	}

	checkAndDoConvert(ctx, rarray is null ? left.base : left, rexp);
	rexp = buildCastSmart(left.base, rexp);
}

void extypeTernary(Context ctx, ir.Ternary ternary)
{
	auto trueType = realType(getExpType(ctx.lp, ternary.ifTrue, ctx.current));
	auto falseType = realType(getExpType(ctx.lp, ternary.ifFalse, ctx.current));

	auto aClass = cast(ir.Class) trueType;
	auto bClass = cast(ir.Class) falseType;
	if (aClass !is null && bClass !is null) {
		auto common = commonParent(aClass, bClass);
		checkAndDoConvert(ctx, common, ternary.ifTrue);
		checkAndDoConvert(ctx, common, ternary.ifFalse);
	} else {
		// matchLevel lives in volt.semantic.overload.
		int trueMatchLevel = trueType.nodeType == ir.NodeType.NullType ? 0 : matchLevel(false, trueType, falseType);
		int falseMatchLevel = falseType.nodeType == ir.NodeType.NullType ? 0 : matchLevel(false, falseType, trueType);
		ir.Exp baseExp = trueMatchLevel > falseMatchLevel ? ternary.ifTrue : ternary.ifFalse;
		auto baseType = getExpType(ctx.lp, baseExp, ctx.current);
		assert(baseType.nodeType != ir.NodeType.NullType);
		if (trueMatchLevel > falseMatchLevel) {
			checkAndDoConvert(ctx, baseType, ternary.ifFalse);
		} else {
			checkAndDoConvert(ctx, baseType, ternary.ifTrue);
		}
	}

	auto condType = getExpType(ctx.lp, ternary.condition, ctx.current);
	if (!isBool(condType)) {
		ternary.condition = buildCastToBool(ternary.condition.location, ternary.condition);
	}
}

void extypeStructLiteral(Context ctx, ir.StructLiteral sl)
{
	if (sl.type is null) {
		throw makeCannotDeduceStructLiteralType(sl.location);
	}

	auto asStruct = cast(ir.Struct) realType(sl.type);
	assert(asStruct !is null);
	ir.Type[] types = getStructFieldTypes(asStruct);

	// @TODO fill out with T.init
	if (types.length != sl.exps.length) {
		throw makeWrongNumberOfArgumentsToStructLiteral(sl.location);
	}

	foreach (i, ref sexp; sl.exps) {

		if (ctx.isFunction || isBackendConstant(sexp)) {
			checkAndDoConvert(ctx, types[i], sexp);
			continue;
		}

		auto n = evaluateOrNull(ctx.lp, ctx.current, sexp);
		if (n is null) {
			throw makeNonConstantStructLiteral(sexp.location);
		}

		sexp = n;
		checkAndDoConvert(ctx, types[i], sexp);
	}
}

/// Replace TypeOf with its expression's type, if needed.
void replaceTypeOfIfNeeded(Context ctx, ref ir.Type type)
{
	auto asTypeOf = cast(ir.TypeOf) realType(type);
	if (asTypeOf is null) {
		assert(type.nodeType != ir.NodeType.TypeOf);
		return;
	}
	auto t = getExpType(ctx.lp, asTypeOf.exp, ctx.current);
	if (t.nodeType == ir.NodeType.NoType) {
		throw makeError(asTypeOf.exp, "expression has no type.");
	}
	type = copyTypeSmart(asTypeOf.location, t);
}

/**
 * Ensure that a thrown type inherits from Throwable.
 */
void extypeThrow(Context ctx, ir.ThrowStatement t)
{
	auto throwable = cast(ir.Class) retrieveTypeFromObject(ctx.lp, t.location, "Throwable");
	assert(throwable !is null);

	auto type = realType(getExpType(ctx.lp, t.exp, ctx.current), false);
	auto asClass = cast(ir.Class) type;
	if (asClass is null) {
		throw makeThrowOnlyThrowable(t.exp, type);
	}

	if (!asClass.isOrInheritsFrom(throwable)) {
		throw makeThrowNoInherits(t.exp, asClass);
	}

	if (asClass !is throwable) {
		t.exp = buildCastSmart(t.exp.location, throwable, t.exp);
	}
}

/**
 * Correct this references in nested functions.
 */
void handleNestedThis(ir.Function fn, ir.BlockStatement bs)
{
	bs = fn._body;
	auto np = fn.nestedVariable;
	auto ns = fn.nestStruct;
	if (np is null || ns is null) {
		return;
	}
	size_t index;
	for (index = 0; index < bs.statements.length; ++index) {
		if (bs.statements[index] is np) {
			break;
		}
	}
	if (++index >= bs.statements.length) {
		return;
	}
	if (fn.thisHiddenParameter !is null) {
		auto l = buildAccess(fn.location, buildExpReference(np.location, np, np.name), "this");
		auto tv = fn.thisHiddenParameter;
		auto r = buildExpReference(bs.location, tv, tv.name);
		r.doNotRewriteAsNestedLookup = true;
		ir.Node n = buildExpStat(l.location, buildAssign(l.location, l, r));
		bs.statements.insertInPlace(index, n);
	}
}

/**
 * Given a nested function fn, add its parameters to the nested
 * struct and insert statements after the nested declaration.
 */
void handleNestedParams(Context ctx, ir.Function fn, ir.BlockStatement bs)
{
	auto np = fn.nestedVariable;
	auto ns = fn.nestStruct;
	if (np is null || ns is null) {
		return;
	}

	// Don't add parameters for nested functions.
	if (fn.kind == ir.Function.Kind.Nested) {
		return;
	}

	// This is needed for the parent function.
	size_t index;
	for (index = 0; index < bs.statements.length; ++index) {
		if (bs.statements[index] is np) {
			break;
		}
	}
	++index;

	if (index > bs.statements.length) {
		index = 0;  // We didn't find a usage, so put it at the start.
	}

	foreach (i, param; fn.params) {
		if (!param.hasBeenNested) {
			param.hasBeenNested = true;

			auto type = param.type;
			bool refParam = fn.type.isArgRef[i] || fn.type.isArgOut[i];
			if (refParam) {
				type = buildPtrSmart(param.location, param.type);
			}
			auto name = param.name != "" ? param.name : "__anonparam_" ~ toString(index);
			auto var = buildVariableSmart(param.location, type, ir.Variable.Storage.Field, name);
			addVarToStructSmart(ns, var);
			// Insert an assignment of the param to the nest struct.

			auto l = buildAccess(param.location, buildExpReference(np.location, np, np.name), name);
			auto r = buildExpReference(param.location, param, name);
			r.doNotRewriteAsNestedLookup = true;
			ir.BinOp bop;
			if (!refParam) {
				bop = buildAssign(l.location, l, r);
			} else {
				bop = buildAssign(l.location, l, buildAddrOf(r.location, r));
			}
			bop.isInternalNestedAssign = true;
			ir.Node n = buildExpStat(l.location, bop);
			if (isNested(fn)) {
				// Nested function.
				bs.statements = n ~ bs.statements;
			} else {
				// Parent function with nested children.
				bs.statements.insertInPlace(index++, n);
			}
		}
	}
}

// Moved here for now.
struct ArrayCase
{
	ir.Exp originalExp;
	ir.SwitchCase _case;
	ir.IfStatement lastIf;
}

/**
 * Ensure that a given switch statement is semantically sound.
 * Errors on bad final switches (doesn't cover all enum members, not on an enum at all),
 * and checks for doubled up cases.
 *
 * oldCondition is the switches condition prior to the extyper being run on it.
 * It's a bit of a hack, but we need the unprocessed enum to evaluate final switches.
 */
void verifySwitchStatement(Context ctx, ir.SwitchStatement ss)
{
	auto conditionType = realType(getExpType(ctx.lp, ss.condition, ctx.current), false);
	auto originalCondition = ss.condition;
	if (isArray(conditionType)) {
		auto l = ss.location;
		auto asArray = cast(ir.ArrayType) conditionType;
		assert(asArray !is null);
		ir.Exp ptr = buildCastSmart(buildVoidPtr(l), buildArrayPtr(l, asArray.base, ss.condition));
		ir.Exp length = buildBinOp(l, ir.BinOp.Op.Mul, buildArrayLength(l, ctx.lp, copyExp(ss.condition)),
				buildAccess(l, buildTypeidSmart(l, asArray.base), "size"));
		ss.condition = buildCall(ss.condition.location, ctx.lp.hashFunc, [ptr, length]);
		conditionType = buildUint(ss.condition.location);
	}
	ArrayCase[uint] arrayCases;
	size_t[] toRemove;  // Indices of cases that have been folded into a collision case.

	int defaultCount;
	foreach (i, _case; ss.cases) {
		void addExp(ir.Exp e, ref ir.Exp exp, ref size_t sz, ref uint[] intArrayData, ref ulong[] longArrayData)
		{
			auto constant = cast(ir.Constant) e;
			if (constant !is null) {
				if (sz == 0) {
					sz = size(ctx.lp, constant.type);
					assert(sz > 0);
				}
				switch (sz) {
				case 8:
					longArrayData ~= constant.u._ulong;
					break;
				default:
					intArrayData ~= constant.u._uint;
					break;
				}
				return;
			}
			auto cexp = cast(ir.Unary) e;
			if (cexp !is null) {
				assert(cexp.op == ir.Unary.Op.Cast);
				assert(sz == 0);
				sz = size(ctx.lp, cexp.type);
				assert(sz == 8);
				addExp(cexp.value, exp, sz, intArrayData, longArrayData);
				return;
			}
			auto type = getExpType(ctx.lp, exp, ctx.current);
			throw makeSwitchBadType(ss, type);
		}
		void replaceWithHashIfNeeded(ref ir.Exp exp) 
		{
			if (exp is null) {
				return;
			}

			auto etype = getExpType(ctx.lp, exp, ctx.current);
			if (!isArray(etype)) {
				return;
			}

			uint h;
			auto constant = cast(ir.Constant) exp;
			if (constant !is null) {
				assert(isString(etype));
				assert(constant._string[0] == '\"');
				assert(constant._string[$-1] == '\"');
				auto str = constant._string[1..$-1];
				h = hash(cast(ubyte[]) str);
			} else {
				auto alit = cast(ir.ArrayLiteral) exp;
				assert(alit !is null);
				auto atype = cast(ir.ArrayType) etype;
				assert(atype !is null);
				uint[] intArrayData;
				ulong[] longArrayData;
				size_t sz;

				foreach (e; alit.exps) {
					addExp(e, exp, sz, intArrayData, longArrayData);
				}
				if (sz == 8) {
					h = hash(cast(ubyte[]) longArrayData);
				} else {
					h = hash(cast(ubyte[]) intArrayData);
				}
			}
			if (auto p = h in arrayCases) {
				auto aStatements = _case.statements.statements;
				auto bStatements = p._case.statements.statements;
				auto c = p._case.statements.myScope;
				auto aBlock = buildBlockStat(exp.location, p._case.statements, c, aStatements);
				auto bBlock = buildBlockStat(exp.location, p._case.statements, c, bStatements);
				p._case.statements.statements = null;
				auto cmp = buildBinOp(exp.location, ir.BinOp.Op.Equal, copyExp(exp), copyExp(originalCondition));
				auto ifs = buildIfStat(exp.location, p._case.statements, cmp, aBlock, bBlock);
				p._case.statements.statements[0] = ifs;
				if (p.lastIf !is null) {
					p.lastIf.thenState.myScope.parent = ifs.elseState.myScope;
					p.lastIf.elseState.myScope.parent = ifs.elseState.myScope;
				}
				p.lastIf = ifs;
				toRemove ~= i;
			} else {
				ArrayCase ac = {exp, _case, null};
				arrayCases[h] = ac;
			}
			exp = buildConstantUint(exp.location, h);
		}

		if (_case.isDefault) {
			defaultCount++;
		}
		if (_case.firstExp !is null) {
			replaceWithHashIfNeeded(_case.firstExp);
			checkAndDoConvert(ctx, conditionType, _case.firstExp);
		}
		if (_case.secondExp !is null) {
			replaceWithHashIfNeeded(_case.secondExp);
			checkAndDoConvert(ctx, conditionType, _case.secondExp);
		}
		foreach (ref exp; _case.exps) {
			replaceWithHashIfNeeded(exp);
			checkAndDoConvert(ctx, conditionType, exp);
		}
	}

	if (!ss.isFinal && defaultCount == 0) {
		throw makeNoDefaultCase(ss.location);
	}
	if (ss.isFinal && defaultCount > 0) {
		throw makeFinalSwitchWithDefault(ss.location);
	}
	if (defaultCount > 1) {
		throw makeMultipleDefaults(ss.location);
	}

	for (int i = cast(int) toRemove.length - 1; i >= 0; i--) {
		ss.cases = ss.cases[0 .. i] ~ ss.cases[i .. $];
	}

	auto asEnum = cast(ir.Enum) conditionType;
	if (asEnum is null && ss.isFinal) {
		asEnum = cast(ir.Enum)realType(getExpType(ctx.lp, ss.condition, ctx.current), false);
		if (asEnum is null) {
			throw makeExpected(ss, "enum type for final switch");
		}
	}
	size_t caseCount;
	foreach (_case; ss.cases) {
		if (_case.firstExp !is null) {
			caseCount++;
		}
		if (_case.secondExp !is null) {
			caseCount++;
		}
		caseCount += _case.exps.length;
	}

	if (ss.isFinal && caseCount != asEnum.members.length) {
		throw makeFinalSwitchBadCoverage(ss);
	}
}

/**
 * Check a given Aggregate's anonymous structs/unions
 * (if any) for name collisions.
 */
void checkAnonymousVariables(Context ctx, ir.Aggregate agg)
{
	if (agg.anonymousAggregates.length == 0) {
		return;
	}
	bool[string] names;
	foreach (anonAgg; agg.anonymousAggregates) foreach (n; anonAgg.members.nodes) {
		auto var = cast(ir.Variable) n;
		auto fn = cast(ir.Function) n;
		string name;
		if (var !is null) {
			name = var.name;
		} else if (fn !is null) {
			name = fn.name;
		} else {
			continue;
		}
		if ((name in names) !is null) {
			throw makeAnonymousAggregateRedefines(anonAgg, name);
		}
		auto store = lookupAsThisScope(ctx.lp, agg.myScope, agg.location, name);
		if (store !is null) {
			throw makeAnonymousAggregateRedefines(anonAgg, name);
		}
	}
}

/// Turn a runtime assert into an if and a throw.
ir.Node transformRuntimeAssert(Context ctx, ir.AssertStatement as)
{
	if (as.isStatic) {
		throw panic(as.location, "expected runtime assert");
	}
	auto l = as.location;
	ir.Exp message = as.message;
	if (message is null) {
		message = buildConstantString(l, "assertion failure");
	}
	assert(message !is null);
	auto exception = buildNew(l, ctx.lp.assertErrorClass, "AssertError", message);
	auto theThrow  = buildThrowStatement(l, exception);
	auto thenBlock = buildBlockStat(l, null, ctx.current, theThrow);
	auto ifS = buildIfStat(l, buildNot(l, as.condition), thenBlock);
	return ifS;
}

/**
 * Process the types and expressions on a foreach.
 * Foreaches become for loops before the backend sees them,
 * but they still need to be made valid by the extyper.
 */
void extypeForeach(Context ctx, ir.ForeachStatement fes)
{
	if (fes.itervars.length == 0) {
		if (fes.beginIntegerRange is null || fes.endIntegerRange is null) {
			throw makeExpected(fes.location, "variable");
		}
		fes.itervars ~= buildVariable(fes.location, buildAutoType(fes.location),
			ir.Variable.Storage.Function, ctx.current.genAnonIdent());
	}

	bool isBlankVariable(size_t i)
	{
		auto atype = cast(ir.AutoType) fes.itervars[i].type;
		return atype !is null && atype.explicitType is null;
	}

	void fillBlankVariable(size_t i, ir.Type t)
	{
		if (!isBlankVariable(i)) {
			return;
		}
		fes.itervars[i].type = copyTypeSmart(fes.itervars[i].location, t);
	}

	foreach (var; fes.itervars) {
		auto at = cast(ir.AutoType) var.type;
		if (at !is null && at.isForeachRef) {
			fes.refvars ~= true;
			var.type = at.explicitType;
		} else {
			fes.refvars ~= false;
		}
	}

	if (fes.aggregate is null) {
		auto a = cast(ir.PrimitiveType) getExpType(ctx.lp, fes.beginIntegerRange, ctx.current);
		auto b = cast(ir.PrimitiveType) getExpType(ctx.lp, fes.endIntegerRange, ctx.current);
		if (a is null || b is null) {
			throw makeExpected(fes.beginIntegerRange.location, "primitive types");
		}
		if (!typesEqual(a, b)) {
			auto asz = size(ctx.lp, a);
			auto bsz = size(ctx.lp, b);
			if (bsz > asz) {
				checkAndDoConvert(ctx, b, fes.beginIntegerRange);
				fillBlankVariable(0, b);
			} else if (asz > bsz) {
				checkAndDoConvert(ctx, a, fes.endIntegerRange);
				fillBlankVariable(0, a);
			} else {
				auto ac = evaluateOrNull(ctx.lp, ctx.current, fes.beginIntegerRange);
				auto bc = evaluateOrNull(ctx.lp, ctx.current, fes.endIntegerRange);
				if (ac !is null) {
					checkAndDoConvert(ctx, b, fes.beginIntegerRange);
					fillBlankVariable(0, b);
				} else if (bc !is null) {
					checkAndDoConvert(ctx, a, fes.endIntegerRange);
					fillBlankVariable(0, a);
				}
			}
		}
		fillBlankVariable(0, a);
		return;
	}

	acceptExp(fes.aggregate, ctx.extyper);

	auto aggType = realType(getExpType(ctx.lp, fes.aggregate, ctx.current));

	if (!isString(aggType)) foreach (i, ivar; fes.itervars) {
		if (!isBlankVariable(i)) {
			throw makeDoNotSpecifyForeachType(fes.itervars[i].location, fes.itervars[i].name);
		}
	} else  {
		if (fes.itervars.length != 1 && fes.itervars.length != 2) {
			throw makeExpected(fes.location, "one or two iteration variables");
		}
		size_t charIndex = fes.itervars.length == 2 ? 1 : 0;
		foreach (i, ivar; fes.itervars) {// isString(aggType)
			if (i == charIndex && !isChar(fes.itervars[i].type)) {
				throw makeExpected(fes.itervars[i].location, "'char', 'wchar', or 'dchar'");
			} else if (i != charIndex && !isBlankVariable(i)) {
				throw makeDoNotSpecifyForeachType(fes.itervars[i].location, fes.itervars[i].name);
			}
		}
		auto asArray = cast(ir.ArrayType)realType(aggType);
		panicAssert(fes, asArray !is null);
		auto fromPtype = cast(ir.PrimitiveType)realType(asArray.base);
		auto toPtype = cast(ir.PrimitiveType)realType(fes.itervars[charIndex].type);
		panicAssert(fes, fromPtype !is null && toPtype !is null);
		if (!typesEqual(fromPtype, toPtype, IgnoreStorage)) {
			if (toPtype.type != ir.PrimitiveType.Kind.Dchar ||
			    fromPtype.type != ir.PrimitiveType.Kind.Char) {
				throw panic(fes.location, "only char to dchar foreach decoding is currently supported.");
			}
			if (!fes.reverse) {
				fes.decodeFunction = ctx.lp.utfDecode_u8_d;
			} else {
				fes.decodeFunction = ctx.lp.utfReverseDecode_u8_d;
			}
		}
	}

	ir.Type key, value;
	switch (aggType.nodeType) {
	case ir.NodeType.ArrayType:
		auto asArray = cast(ir.ArrayType) aggType;
		value = copyTypeSmart(fes.aggregate.location, asArray.base);
		key = buildSizeT(fes.location, ctx.lp);
		break;
	case ir.NodeType.StaticArrayType:
		auto asArray = cast(ir.StaticArrayType) aggType;
		value = copyTypeSmart(fes.aggregate.location, asArray.base);
		key = buildSizeT(fes.location, ctx.lp);
		break;
	case ir.NodeType.AAType:
		auto asArray = cast(ir.AAType) aggType;
		value = copyTypeSmart(fes.aggregate.location, asArray.value);
		key = copyTypeSmart(fes.aggregate.location, asArray.key);
		break;
	default:
		throw makeExpected(fes.aggregate.location, "array, static array, or associative array.");
	}


	if (fes.itervars.length == 2) {
		fillBlankVariable(0, key);
		fillBlankVariable(1, value);
	} else if (fes.itervars.length == 1) {
		fillBlankVariable(0, value);
	} else {
		throw makeExpected(fes.location, "one or two variables after foreach");
	}
}

bool isInternalVariable(ir.Class c, ir.Variable v)
{
	foreach (ivar; c.ifaceVariables) {
		if (ivar is v) {
			return true;
		}
	}
	return v is c.typeInfo || v is c.vtableVariable || v is c.initVariable;
}

void writeVariableAssignsIntoCtors(Context ctx, ir.Class _class)
{
	foreach (n; _class.members.nodes) {
		auto v = cast(ir.Variable) n;
		if (v is null || v.assign is null ||
			isInternalVariable(_class, v) ||
		   !(v.storage != ir.Variable.Storage.Local && 
		    v.storage != ir.Variable.Storage.Global)) {
			continue;
		}
		foreach (ctor; _class.userConstructors) {
			assert(ctor.thisHiddenParameter !is null);
			auto eref = buildExpReference(ctor.thisHiddenParameter.location, ctor.thisHiddenParameter, ctor.thisHiddenParameter.name);
			auto assign = buildAssign(ctor.location, buildAccess(ctor.location, eref, v.name), v.assign);
			auto stat = new ir.ExpStatement();
			stat.location = ctor.location;
			stat.exp = copyExp(assign);
			ctor._body.statements = stat ~ ctor._body.statements;
		}
		v.assign = null;
		if (v.type.isConst || v.type.isImmutable) {
			throw makeConstField(v);
		}
	}
}

class GotoReplacer : NullVisitor
{
public:
	override Status enter(ir.GotoStatement gs)
	{
		assert(exp !is null);
		if (gs.isCase && gs.exp is null) {
			gs.exp = copyExp(exp);
		}
		return Continue;
	}

public:
	ir.Exp exp;
}

/**
 * Given a switch statement, replace 'goto case' with an explicit
 * jump to the next case.
 */
void replaceGotoCase(Context ctx, ir.SwitchStatement ss)
{
	auto gr = new GotoReplacer();
	foreach_reverse (sc; ss.cases) {
		if (gr.exp !is null) {
			accept(sc.statements, gr);
		}
		gr.exp = sc.exps.length > 0 ? sc.exps[0] : sc.firstExp;
	}
}


/*
 *
 * Resolver functions.
 *
 */

/**
 * Resolves a Variable.
 */
void resolveVariable(Context ctx, ir.Variable v)
{
	auto done = ctx.lp.startResolving(v);
	ctx.isVarAssign = true;

	scope (success) {
		ctx.isVarAssign = false;
		done();
	}

	v.hasBeenDeclared = true;
	foreach (u; v.userAttrs) {
		ctx.lp.resolve(ctx.current, u);
	}

	// Fix up type as best as possible.
	accept(v.type, ctx.extyper);
	v.type = ctx.lp.resolve(ctx.current, v.type);

	bool inAggregate = (cast(ir.Aggregate) ctx.current.node) !is null;
	if (inAggregate && v.assign !is null &&
	    ctx.current.node.nodeType != ir.NodeType.Class &&
            (v.storage != ir.Variable.Storage.Global &&
             v.storage != ir.Variable.Storage.Local)) {
		throw makeAssignToNonStaticField(v);
	}

	if (inAggregate && (v.type.isConst || v.type.isImmutable)) {
		throw makeConstField(v);
	}

	replaceTypeOfIfNeeded(ctx, v.type);

	if (v.assign !is null) {
		if (!isAuto(v.type)) {
			tagLiteralType(v.assign, v.type);
		}
		acceptExp(v.assign, ctx.extyper);
		auto rtype = getExpType(ctx.lp, v.assign, ctx.current);
		if (isAuto(v.type)) {
			auto atype = cast(ir.AutoType)v.type;
			if (rtype.nodeType == ir.NodeType.FunctionSetType || atype is null) {
				throw makeCannotInfer(v.assign.location);
			}
			atype.explicitType = copyTypeSmart(v.assign.location, rtype);
		} else {
			if (!willConvert(ctx, v.type, v.assign)) {
				throw makeBadImplicitCast(v, rtype, v.type);
			}
		}
		replaceAutoIfNeeded(v.type);
		doConvert(ctx, v.type, v.assign);
	}

	replaceAutoIfNeeded(v.type);
	accept(v.type, ctx.extyper);
	v.isResolved = true;
}

/**
 * If type is effectively const, throw an error.
 */
void checkConst(ir.Node n, ir.Type type)
{
	if (effectivelyConst(type)) {
		throw makeCannotModify(n, type);
	}
}

void emitNestedFromBlock(Context ctx, ir.Function currentFunction, ir.BlockStatement bs, bool skipFunction = true)
{
	if (bs is null || (skipFunction && bs is currentFunction._body)) {
		return;
	}
	ir.Struct[] structs;
	emitNestedStructs(currentFunction, bs, structs);
	foreach (_s; structs) {
		accept(_s, ctx.extyper);
	}
	handleNestedParams(ctx, currentFunction, currentFunction._body);
	handleNestedThis(currentFunction, bs);
	if (currentFunction.nestStruct !is null &&
	    currentFunction.thisHiddenParameter !is null &&
	    currentFunction.kind != ir.Function.Kind.Nested &&
	    currentFunction.nestStruct.myScope.getStore("this") is null) {
		auto cvar = copyVariableSmart(currentFunction.thisHiddenParameter.location, currentFunction.thisHiddenParameter);
		addVarToStructSmart(currentFunction.nestStruct, cvar);
	}
}

void resolveFunction(Context ctx, ir.Function fn)
{
	auto done = ctx.lp.startResolving(fn);
	scope (success) done();

	if (ctx.current.node.nodeType == ir.NodeType.BlockStatement ||
	    fn.kind == ir.Function.Kind.Nested) {
		auto ns = ctx.parentFunction.nestStruct;
		panicAssert(fn, ns !is null);
		auto tr = buildTypeReference(ns.location, ns, "__Nested");
		auto decl = buildVariable(fn.location, tr, ir.Variable.Storage.Function, "__nested");
		decl.isResolved = true;
		decl.specialInitValue = true;

		if (fn.nestedHiddenParameter is null) {
			// XXX: Note __nested is not added to any scope.
			// XXX: Instead make sure that nestedHiddenParameter is visited (and as such visited)
			fn.nestedHiddenParameter = decl;
			fn.nestedVariable = decl;
			fn.nestStruct = ns;
			fn.type.hiddenParameter = true;
			fn._body.statements = decl ~ fn._body.statements;
		}
	}

	if (fn.isAutoReturn) {
		fn.type.ret = buildVoid(fn.type.ret.location);
	}

	if (fn.type.isProperty &&
	    fn.type.params.length == 0 &&
	    isVoid(fn.type.ret)) {
		throw makeInvalidType(fn, buildVoid(fn.location));
	} else if (fn.type.isProperty &&
	           fn.type.params.length > 1) {
		throw makeWrongNumberOfArguments(fn, fn.type.params.length, isVoid(fn.type.ret) ? 0U : 1U);
	}

	fn.type = cast(ir.FunctionType)ctx.lp.resolve(fn.myScope.parent, fn.type);


	if (fn.name == "main" && fn.type.linkage == ir.Linkage.Volt) {

		if (fn.params.length == 0) {
			addParam(fn.location, fn, buildStringArray(fn.location), "");
		} else if (fn.params.length > 1) {
			throw makeInvalidMainSignature(fn);
		}

		auto arr = cast(ir.ArrayType) fn.type.params[0];
		if (arr is null ||
		    !isString(realType(arr.base)) ||
		    (!isVoid(fn.type.ret) && !isInt(fn.type.ret))) {
			throw makeInvalidMainSignature(fn);
		}
	}

	if ((fn.kind == ir.Function.Kind.Function ||
	     (cast(ir.Class) fn.myScope.parent.node) is null) &&
	    fn.isMarkedOverride) {
		throw makeMarkedOverrideDoesNotOverride(fn, fn);
	}

	replaceVarArgsIfNeeded(ctx.lp, fn);

	ctx.lp.resolve(ctx.current, fn.userAttrs);

	if (fn.type.homogenousVariadic && !isArray(realType(fn.type.params[$-1]))) {
		throw makeExpected(fn.params[$-1].location, "array type");
	}

	if (fn.outParameter.length > 0) {
		assert(fn.outContract !is null);
		auto l = fn.outContract.location;
		auto var = buildVariableSmart(l, copyTypeSmart(l, fn.type.ret), ir.Variable.Storage.Function, fn.outParameter);
		fn.outContract.statements = var ~ fn.outContract.statements;
		fn.outContract.myScope.addValue(var, var.name);
	}

	foreach (i, ref param; fn.params) {
		if (param.assign is null) {
			continue;
		}
		auto texp = cast(ir.TokenExp) param.assign;
		if (texp !is null) {
			continue;
		}

		// We don't extype TokenExp because we want it to be resolved
		// at the call site not where it was defined.
		acceptExp(param.assign, ctx.extyper);
		param.assign = evaluate(ctx.lp, ctx.current, param.assign);
	}

	if (fn.loadDynamic && fn._body !is null) {
		throw makeCannotLoadDynamic(fn, fn);
	}

	fn.isResolved = true;
}

ir.Constant evaluateIsExp(Context ctx, ir.IsExp isExp)
{
	// We need to remove replace TypeOf, but we need
	// to preserve extra type info like enum.
	if (isExp !is null) {
		replaceTypeOfIfNeeded(ctx, isExp.type);
	}
	if (isExp.specType !is null) {
		replaceTypeOfIfNeeded(ctx, isExp.specType);
	}

	if (isExp.specialisation != ir.IsExp.Specialisation.Type ||
	    isExp.compType != ir.IsExp.Comparison.Exact ||
	    isExp.specType is null) {
		throw makeNotAvailableInCTFE(isExp, isExp);
	}
	return buildConstantBool(isExp.location, typesEqual(isExp.type, isExp.specType));
}

/**
 * Given a expression and a type, if the expression is a literal,
 * tag it (and its subexpressions) with the type.
 */
void tagLiteralType(ir.Exp exp, ir.Type type)
{
	auto literal = cast(ir.LiteralExp)exp;
	if (literal is null) {
		return;
	}
	literal.type = copyTypeSmart(exp.location, type);

	switch (literal.nodeType) with (ir.NodeType) {
	case ArrayLiteral:
		ir.Type base;
		auto atype = cast(ir.ArrayType)realType(type);
		if (atype !is null) {
			base = atype.base;
		}
		auto satype = cast(ir.StaticArrayType)realType(type);
		if (satype !is null) {
			base = satype.base;
		}
		auto aatype = cast(ir.AAType)realType(type);
		if (aatype is null && base is null) {
			throw makeUnexpected(exp.location, "array literal");
		}

		auto alit = cast(ir.ArrayLiteral)exp;
		panicAssert(exp, alit !is null);
		foreach (val; alit.exps) {
			if (aatype !is null) {
				auto aapair = cast(ir.AAPair)val;
				if (aapair is null) {
					throw makeExpected(exp.location, "associative array pair");
				}
				tagLiteralType(aapair.key, aatype.key);
				tagLiteralType(aapair.value, aatype.value);
			} else {
				tagLiteralType(val, base);
			}
		}
		break;
	case StructLiteral:
		auto stype = cast(ir.Struct)realType(type);
		auto slit = cast(ir.StructLiteral)exp;
		if (stype is null || slit is null) {
			throw panic(exp.location, "tagging struct literal as not an struct.");
		}
		auto vars = getStructFieldVars(stype);
		if (slit.exps.length > vars.length) {
			throw makeWrongNumberOfArgumentsToStructLiteral(exp.location);
		}
		foreach (i, val; slit.exps) {
			tagLiteralType(val, vars[i].type);
		}
		break;
	default:
		throw panicUnhandled(exp.location, "literal type");
	}
}

/**
 * If type casting were to be strict, type T could only
 * go to type T without an explicit cast. Implicit casts
 * are places where the language deems automatic conversion
 * safe enough to insert casts for the user.
 *
 * Thus, the primary job of extyper ('explicit typer') is
 * to insert casts where an implicit conversion has taken place.
 *
 * The second job of extyper is to make any implicit or
 * inferred types or expressions concrete -- for example,
 * to make const i = 2 become const int = 2.
 */
class ExTyper : NullVisitor, Pass
{
public:
	Context ctx;

public:
	this(LanguagePass lp)
	{
		ctx = new Context(lp, this);
	}


	/*
	 *
	 * Pass.
	 *
	 */

	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close()
	{
	}


	/*
	 *
	 * Called by the LanguagePass.
	 *
	 */

	/**
	 * For out of band checking of Variables.
	 */
	void resolve(ir.Scope current, ir.Variable v)
	{
		ctx.setupFromScope(current);
		scope (success) ctx.reset();

		accept(v, this);
	}

	/**
	 * For out of band checking of Functions.
	 */
	void resolve(ir.Scope current, ir.Function fn)
	{
		ctx.setupFromScope(current);
		scope (success) ctx.reset();

		resolveFunction(ctx, fn);
	}

	/**
	 * For out of band checking of UserAttributes.
	 */
	void transform(ir.Scope current, ir.Attribute a)
	{
		ctx.setupFromScope(current);
		scope (exit) ctx.reset();

		basicValidateUserAttribute(ctx.lp, ctx.current, a);

		auto ua = a.userAttribute;
		assert(ua !is null);

		foreach (i, ref arg; a.arguments) {
			checkAndDoConvert(ctx, ua.fields[i].type, a.arguments[i]);
			acceptExp(a.arguments[i], this);
		}
	}

	void transform(ir.Scope current, ir.EnumDeclaration ed)
	{
		ctx.setupFromScope(current);
		scope (exit) ctx.reset();

		ir.EnumDeclaration[] edStack;
		ir.Exp prevExp;

		do {
			edStack ~= ed;
			if (ed.assign !is null) {
				break;
			}

			ed = ed.prevEnum;
			if (ed is null) {
				break;
			}

			if (ed.resolved) {
				prevExp = ed.assign;
				break;
			}
		} while (true);

		foreach_reverse (e; edStack) {
			resolve(e, prevExp);
			prevExp = e.assign;
		}
	}

	private void resolve(ir.EnumDeclaration ed, ir.Exp prevExp)
	{
		ed.type = ctx.lp.resolve(ctx.current, ed.type);

		if (ed.assign is null) {
			if (prevExp is null) {
				ed.assign = buildConstantInt(ed.location, 0);
			} else {
				auto loc = ed.location;
				auto prevType = realType(getExpType(ctx.lp, prevExp, ctx.current));
				if (!isIntegral(prevType)) {
					throw makeTypeIsNot(ed, prevType, buildInt(ed.location));
				}

				ed.assign = evaluate(ctx.lp, ctx.current, buildAdd(loc, copyExp(prevExp), buildConstantInt(loc, 1)));
			}
		} else {
			acceptExp(ed.assign, this);
			if (needsEvaluation(ed.assign)) {
				ed.assign = evaluate(ctx.lp, ctx.current, ed.assign);
			}
		}

		auto e = cast(ir.Enum)realType(ed.type, false);
		auto rtype = getExpType(ctx.lp, ed.assign, ctx.current);
		if (e !is null && isAuto(realType(e.base))) {
			e.base = realType(e.base);
			auto atype = cast(ir.AutoType)e.base;
			atype.explicitType = realType(copyTypeSmart(ed.assign.location, rtype));
			replaceAutoIfNeeded(e.base);
		}
		if (isAuto(realType(ed.type))) {
			ed.type = realType(ed.type);
			auto atype = cast(ir.AutoType)ed.type;
			atype.explicitType = realType(copyTypeSmart(ed.assign.location, rtype));
			replaceAutoIfNeeded(ed.type);
		}
		checkAndDoConvert(ctx, ed.type, ed.assign);
		accept(ed.type, this);

		ed.resolved = true;
	}


	/*
	 *
	 * Visitor
	 *
	 */

	override Status enter(ir.Module m)
	{
		ctx.enter(m);
		return Continue;
	}

	override Status leave(ir.Module m)
	{
		ctx.leave(m);
		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		ctx.lp.resolve(a);
		return ContinueParent;
	}

	override Status enter(ir.Struct s)
	{
		ctx.lp.actualize(s);
		ctx.enter(s);
		return Continue;
	}

	override Status leave(ir.Struct s)
	{
		checkAnonymousVariables(ctx, s);
		ctx.leave(s);
		return Continue;
	}

	override Status enter(ir._Interface i)
	{
		ctx.lp.actualize(i);
		ctx.enter(i);
		return Continue;
	}

	override Status leave(ir._Interface i)
	{
		ctx.leave(i);
		return Continue;
	}

	override Status enter(ir.Union u)
	{
		ctx.lp.actualize(u);
		ctx.enter(u);
		return Continue;
	}

	override Status leave(ir.Union u)
	{
		checkAnonymousVariables(ctx, u);
		ctx.leave(u);
		return Continue;
	}

	override Status enter(ir.Class c)
	{
		ctx.lp.actualize(c);
		ctx.enter(c);
		return Continue;
	}

	override Status leave(ir.Class c)
	{
		checkAnonymousVariables(ctx, c);
		writeVariableAssignsIntoCtors(ctx, c);
		ctx.leave(c);
		return Continue;
	}

	override Status enter(ir.Enum e)
	{
		ctx.lp.resolveNamed(e);
		ctx.enter(e);
		return Continue;
	}

	override Status leave(ir.Enum e)
	{
		ctx.leave(e);
		return Continue;
	}

	override Status enter(ir.UserAttribute ua)
	{
		ctx.lp.actualize(ua);
		// Everything is done by actualize.
		return ContinueParent;
	}

	override Status enter(ir.EnumDeclaration ed)
	{
		ctx.lp.resolve(ctx.current, ed);
		return ContinueParent;
	}

	override Status enter(ir.StorageType st)
	{
		return Continue;
	}

	override Status enter(ir.FunctionParam p)
	{
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		if (!v.isResolved) {
			resolveVariable(ctx, v);
		}
		return ContinueParent;
	}

	override Status enter(ir.Function fn)
	{
		if (ctx.functionDepth >= 2) {
			throw makeNestedNested(fn.location);
		}
		if (!fn.isResolved) {
			resolveFunction(ctx, fn);
		}

		ctx.enter(fn);

		emitNestedFromBlock(ctx, fn, fn._body, false);

		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		ctx.leave(fn);
		return Continue;
	}


	/*
	 *
	 * Statements.
	 *
	 */

	override Status enter(ir.WithStatement ws)
	{
		acceptExp(ws.exp, this);

		if (!isValidWithExp(ws.exp)) {
			throw makeExpected(ws.exp, "qualified identifier");
		}

		ctx.pushWith(ws.exp);
		accept(ws.block, this);
		ctx.popWith(ws.exp);

		return ContinueParent;
	}

	override Status enter(ir.ReturnStatement ret)
	{
		auto fn = getParentFunction(ctx.current);
		if (fn is null) {
			throw panic(ret, "return statement outside of function.");
		}

		if (ret.exp !is null) {
			acceptExp(ret.exp, this);
			auto retType = getExpType(ctx.lp, ret.exp, ctx.current);
			if (fn.isAutoReturn) {
				fn.type.ret = copyTypeSmart(retType.location, getExpType(ctx.lp, ret.exp, ctx.current));
				if (cast(ir.NullType)fn.type.ret !is null) {
					fn.type.ret = buildVoidPtr(ret.location);
				}
			}
			if (retType.isScope && mutableIndirection(retType)) {
				throw makeNoReturnScope(ret.location);
			}
			checkAndDoConvert(ctx, fn.type.ret, ret.exp);
		} else if (!isVoid(realType(fn.type.ret))) {
			// No return expression on function returning a value.
			throw makeReturnValueExpected(ret.location, fn.type.ret);
		}

		return ContinueParent;
	}

	override Status enter(ir.IfStatement ifs)
	{
		auto l = ifs.location;
		if (ifs.exp !is null) {
			acceptExp(ifs.exp, this);
		}

		if (ifs.autoName.length > 0) {
			assert(ifs.exp !is null);
			assert(ifs.thenState !is null);

			auto t = getExpType(ctx.lp, ifs.exp, ctx.current);
			auto var = buildVariable(l,
					copyTypeSmart(l, t),
					ir.Variable.Storage.Function,
					ifs.autoName);

			// Resolve the variable making it propper and usable.
			resolveVariable(ctx, var);

			// A hack to work around exp getting resolved twice.
			var.assign = ifs.exp;

			auto eref = buildExpReference(l, var);
			ir.Node[] vars = [cast(ir.Node)var];
			ifs.exp = buildStatementExp(l, vars, eref);

			// Add it to its proper scope.
			ifs.thenState.myScope.addValue(var, var.name);
		}

		// Need to do this after any autoName rewriting.
		if (ifs.exp !is null) {
			implicitlyCastToBool(ctx, ifs.exp);
		}

		if (ifs.thenState !is null) {
			accept(ifs.thenState, this);
		}

		if (ifs.elseState !is null) {
			accept(ifs.elseState, this);
		}

		return ContinueParent;
	}

	override Status enter(ir.ForeachStatement fes)
	{
		if (fes.beginIntegerRange !is null) {
			assert(fes.endIntegerRange !is null);
			acceptExp(fes.beginIntegerRange, this);
			acceptExp(fes.endIntegerRange, this);
		}
		emitNestedFromBlock(ctx, ctx.currentFunction, fes.block);
		ctx.enter(fes.block);
		extypeForeach(ctx, fes);
		foreach (ivar; fes.itervars) {
			accept(ivar, this);
		}
		if (fes.aggregate !is null) {
			auto aggType = realType(getExpType(ctx.lp, fes.aggregate, ctx.current));
			if (fes.itervars.length == 2 &&
				(aggType.nodeType == ir.NodeType.StaticArrayType || 
				aggType.nodeType == ir.NodeType.ArrayType)) {
				auto keysz = size(ctx.lp, fes.itervars[0].type);
				auto sizetsz = size(ctx.lp, buildSizeT(fes.location, ctx.lp));
				if (keysz < sizetsz) {
					throw makeIndexVarTooSmall(fes.location, fes.itervars[0].name);
				}
			}
		}
		// fes.aggregate is visited by extypeForeach
		foreach (ctxment; fes.block.statements) {
			accept(ctxment, this);
		}
		ctx.leave(fes.block);
		return ContinueParent;
	}

	override Status enter(ir.ForStatement fs)
	{
		emitNestedFromBlock(ctx, ctx.currentFunction, fs.block);
		ctx.enter(fs.block);
		foreach (i; fs.initVars) {
			accept(i, this);
		}
		foreach (ref i; fs.initExps) {
			acceptExp(i, this);
		}

		if (fs.test !is null) {
			acceptExp(fs.test, this);
			implicitlyCastToBool(ctx, fs.test);
		}
		foreach (ref increment; fs.increments) {
			acceptExp(increment, this);
		}
		foreach (ctxment; fs.block.statements) {
			accept(ctxment, this);
		}
		ctx.leave(fs.block);

		return ContinueParent;
	}

	override Status enter(ir.WhileStatement ws)
	{
		if (ws.condition !is null) {
			acceptExp(ws.condition, this);
			implicitlyCastToBool(ctx, ws.condition);
		}

		accept(ws.block, this);

		return ContinueParent;
	}

	override Status enter(ir.DoStatement ds)
	{
		accept(ds.block, this);

		if (ds.condition !is null) {
			acceptExp(ds.condition, this);
			implicitlyCastToBool(ctx, ds.condition);
		}

		return ContinueParent;
	}

	override Status enter(ir.SwitchStatement ss)
	{
		acceptExp(ss.condition, this);

		foreach (ref wexp; ss.withs) {
			acceptExp(wexp, this);
			if (!isValidWithExp(wexp)) {
				throw makeExpected(wexp, "qualified identifier");
			}
			ctx.pushWith(wexp);
		}

		foreach (_case; ss.cases) {
			accept(_case, this);
		}

		verifySwitchStatement(ctx, ss);
		replaceGotoCase(ctx, ss);

		foreach_reverse(wexp; ss.withs) {
			ctx.popWith(wexp);
		}
		return ContinueParent;
	}

	override Status leave(ir.ThrowStatement t)
	{
		extypeThrow(ctx, t);
		return Continue;
	}

	override Status leave(ir.AssertStatement as)
	{
		if (!as.isStatic) {
			return Continue;
		}
		as.condition = evaluate(ctx.lp, ctx.current, as.condition);
		if (as.message !is null) {
			as.message = evaluate(ctx.lp, ctx.current, as.message);
		}
		auto cond = cast(ir.Constant) as.condition;
		ir.Constant msg;
		if (as.message !is null) {
			msg = cast(ir.Constant) as.message;
		} else {
			msg = buildConstantString(as.location, "");
		}
		if ((cond is null || msg is null) || (!isBool(cond.type) || !isString(msg.type))) {
			throw panicUnhandled(as, "non simple static asserts (bool and string literal only).");
		}
		if (!cond.u._bool) {
			throw makeStaticAssert(as, msg._string);
		}
		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		emitNestedFromBlock(ctx, ctx.currentFunction, bs);
		ctx.enter(bs);
		// Translate runtime asserts before processing the block.
		for (size_t i = 0; i < bs.statements.length; i++) {
			auto as = cast(ir.AssertStatement) bs.statements[i];
			if (as is null || as.isStatic) {
				continue;
			}
			bs.statements[i] = transformRuntimeAssert(ctx, as);
		}
		return Continue;
	}

	override Status leave(ir.BlockStatement bs)
	{
		ctx.leave(bs);
		return Continue;
	}


	/*
	 *
	 * Types.
	 *
	 */

	override Status enter(ir.FunctionType ftype)
	{
		replaceTypeOfIfNeeded(ctx, ftype.ret);
		return Continue;
	}

	override Status enter(ir.DelegateType dtype)
	{
		replaceTypeOfIfNeeded(ctx, dtype.ret);
		return Continue;
	}


	/*
	 *
	 * Expressions.
	 *
	 */

	override Status leave(ref ir.Exp exp, ir.Typeid _typeid)
	{
		if (_typeid.ident.length > 0) {
			auto store = lookup(ctx.lp, ctx.current, _typeid.location, _typeid.ident);
			if (store is null) {
				throw makeFailedLookup(_typeid, _typeid.ident);
			}
			switch (store.kind) with (ir.Store.Kind) {
			case Type:
				_typeid.type = buildTypeReference(_typeid.location, cast(ir.Type) store.node, _typeid.ident);
				assert(_typeid.type !is null);
				break;
			case Value, EnumDeclaration, FunctionParam, Function:
				auto decl = cast(ir.Declaration) store.node;
				_typeid.exp = buildExpReference(_typeid.location, decl, _typeid.ident);
				break;
			default:
				throw panicUnhandled(_typeid, "store kind");
			}
			_typeid.ident = null;
		}
		if (_typeid.exp !is null) {
			_typeid.type = getExpType(ctx.lp, _typeid.exp, ctx.current);
			if ((cast(ir.Aggregate) _typeid.type) !is null) {
				_typeid.type = buildTypeReference(_typeid.type.location, _typeid.type);
			} else {
				_typeid.type = copyType(_typeid.type);
			}
			_typeid.exp = null;
		}

		_typeid.type = ctx.lp.resolve(ctx.current, _typeid.type);
		replaceTypeOfIfNeeded(ctx, _typeid.type);
		return Continue;
	}

	/// If this is an assignment to a @property function, turn it into a function call.
	override Status enter(ref ir.Exp e, ir.BinOp bin)
	{
		if (bin.left.nodeType == ir.NodeType.Postfix) {
			auto parentKind = classifyRelationship(bin.left, e);
			extypePostfix(ctx, bin.left, parentKind);
		} else if (bin.left.nodeType == ir.NodeType.IdentifierExp) {
			auto ie = cast(ir.IdentifierExp) bin.left;
			extypeIdentifierExp(ctx, bin.left, ie, e);
		} else {
			acceptExp(bin.left, this);
		}
		if (bin.right.nodeType == ir.NodeType.Postfix) {
			auto parentKind = classifyRelationship(bin.left, e);
			extypePostfix(ctx, bin.right, parentKind);
		} else if (bin.right.nodeType == ir.NodeType.IdentifierExp) {
			auto ie = cast(ir.IdentifierExp) bin.right;
			extypeIdentifierExp(ctx, bin.right, ie, e);
		} else {
			acceptExp(bin.right, this);
		}

		// If not rewritten.
		if (e is bin) {
			extypeBinOp(ctx, bin, e);
		}
		return ContinueParent;
	}

	override Status enter(ref ir.Exp exp, ir.Postfix postfix)
	{
		extypePostfix(ctx, exp, Parent.NA);
		return ContinueParent;
	}

	override Status enter(ref ir.Exp exp, ir.Unary _unary)
	{
		if (_unary.type !is null) {
			_unary.type = ctx.lp.resolve(ctx.current, _unary.type);
		}
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Unary _unary)
	{
		if (_unary.type !is null) {
			replaceTypeOfIfNeeded(ctx, _unary.type);
		}
		extypeUnary(ctx, exp, _unary);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Ternary ternary)
	{
		extypeTernary(ctx, ternary);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.TypeExp te)
	{
		te.type = ctx.lp.resolve(ctx.current, te.type);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.VaArgExp vaexp)
	{
		vaexp.type = ctx.lp.resolve(ctx.current, vaexp.type);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.VaArgExp vaexp)
	{
		if (!isLValue(vaexp.arg)) {
			throw makeVaFooMustBeLValue(vaexp.arg.location, "va_exp");
		}
		if (ctx.currentFunction.type.linkage == ir.Linkage.C) {
			if (vaexp.type.nodeType != ir.NodeType.PrimitiveType && vaexp.type.nodeType != ir.NodeType.PointerType) {
				throw makeCVaArgsOnlyOperateOnSimpleTypes(vaexp.location);
			}
			vaexp.arg = buildAddrOf(vaexp.location, copyExp(vaexp.arg));
		} else {
			exp = buildVaArgCast(vaexp.location, vaexp);
		}
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.ExpReference eref)
	{
		ctx.lp.resolve(ctx.current, eref);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.IdentifierExp ie)
	{
		extypeIdentifierExp(ctx, exp, ie, null);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.Constant constant)
	{
		constant.type = ctx.lp.resolve(ctx.current, constant.type);
		if (constant._string == "$" && isIntegral(constant.type)) {
			if (ctx.lastIndexChild is null) {
				throw makeDollarOutsideOfIndex(constant);
			}
			auto l = constant.location;
			// Rewrite $ to (arrayName.length).
			exp = buildArrayLength(l, ctx.lp, copyExp(ctx.lastIndexChild));
		}
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.StructLiteral sl)
	{
		extypeStructLiteral(ctx, sl);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.IsExp isExp)
	{
		isExp.type = ctx.lp.resolve(ctx.current, isExp.type);
		isExp.type = flattenStorage(isExp.type);
		isExp.specType = ctx.lp.resolve(ctx.current, isExp.specType);
		isExp.specType = flattenStorage(isExp.specType);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.IsExp isExp)
	{
		exp = evaluateIsExp(ctx, isExp);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.TokenExp fexp)
	{
		if (fexp.type == ir.TokenExp.Type.File) {
			string fname = fexp.location.filename;
			version (Windows) {
				fname = fname.replace("\\", "/");
			}
			exp = buildConstantString(fexp.location, fname);
			return Continue;
		} else if (fexp.type == ir.TokenExp.Type.Line) {
			exp = buildConstantInt(fexp.location, cast(int) fexp.location.line);
			return Continue;
		}

		char[] buf;
		void sink(string s)
		{
			buf ~= s;
		}
		version (Volt) {
			// @TODO fix this.
			// auto buf = new StringSink();
			// auto pp = new PrettyPrinter("\t", buf.sink);
			auto pp = new PrettyPrinter("\t", cast(void delegate(string))sink);
		} else {
			auto pp = new PrettyPrinter("\t", &sink);
		}

		string[] names;
		ir.Scope scop = ctx.current;
		ir.Function foundFunction;
		while (scop !is null) {
			if (scop.node.nodeType != ir.NodeType.BlockStatement) {
				names ~= scop.name;
			}
			if (scop.node.nodeType == ir.NodeType.Function) {
				foundFunction = cast(ir.Function) scop.node;
			}
			scop = scop.parent;
		}
		if (foundFunction is null) {
			throw makeFunctionNameOutsideOfFunction(fexp);
		}

		if (fexp.type == ir.TokenExp.Type.PrettyFunction) {
			pp.transformType(foundFunction.type.ret);
			buf ~= " ";
		}

		foreach_reverse (i, name; names) {
			buf ~= name ~ (i > 0 ? "." : "");
		}

		if (fexp.type == ir.TokenExp.Type.PrettyFunction) {
			buf ~= "(";
			foreach (i, ptype; ctx.currentFunction.type.params) {
				pp.transformType(ptype);
				if (i < ctx.currentFunction.type.params.length - 1) {
					buf ~= ", ";
				}
			}
			buf ~= ")";
		}

		version (Volt) {
			auto str = new string(buf);
		} else {
			auto str = buf.idup;
		}
		exp = buildConstantString(fexp.location, str);
		return Continue;
	}
}
