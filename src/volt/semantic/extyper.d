/*#D*/
// Copyright © 2012-2017, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.extyper;

import watt.io.std;
import watt.conv : toString;
import watt.text.format : format;
import watt.text.string : replace;
import watt.text.sink : StringSink;

import ir = volta.ir;
import volta.util.util;
import volta.util.copy;
import volta.util.dup;

import volt.errors;
import volt.interfaces;
import volta.util.string;
import volta.ir.location;

import volta.parser.declaration : parseBlock;
import volta.parser.base : ParserStream;
import volta.parser.parser : checkError;

import volta.visitor.visitor;
import volt.visitor.prettyprinter;

import volt.semantic.util;
import volt.semantic.evaluate;
import volt.semantic.typer;
import volt.semantic.nested;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.context;
import volt.semantic.classify;
import volt.semantic.overload;
import volt.semantic.implicit;
import volt.semantic.typeinfo;
import volt.semantic.classresolver;
import volt.semantic.lifter;
import volt.semantic.templatelifter;


/*!
 * Does what the name implies.
 *
 * Checks if func is null and is okay with more arguments the parameters.
 */
void appendDefaultArguments(Context ctx, ir.Location loc,
                            ref ir.Exp[] arguments, ir.Function func)
{
	// Nothing to do.
	// Variadic functions may have more arguments then parameters.
	if (func is null || arguments.length >= func.params.length ||
		func.type.hasVarArgs || func is ctx.lp.vaStartFunc) {
		return;
	}

	ir.Exp[] overflow;
	foreach (p; func.params[arguments.length .. $]) {
		if (p.assign is null) {
			throw makeArgumentCountMismatch(/*#ref*/loc, func);
		}
		overflow ~= p.assign;
	}

	foreach (i, ee; overflow) {
		if (ee.nodeType == ir.NodeType.TokenExp) {
			auto texp = ee.toTokenExpFast();
			texp.loc = loc;
			arguments ~= texp;

			extype(ctx, /*#ref*/arguments[$-1], Parent.NA);
		} else {
			assert(ee.nodeType == ir.NodeType.Constant);
			arguments ~= copyExp(/*#ref*/ee.loc, ee);
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
	} else if (parent.nodeType == ir.NodeType.BinOp) {
		auto b = parent.toBinOpFast();
		if (b.op != ir.BinOp.Op.Assign) {
			return Parent.NA;
		} else if (b.left is child) {
			return Parent.AssignTarget;
		} else if (b.right is child) {
			return Parent.AssignSource;
		} else {
			assert(false);
		}
	} else if (parent.nodeType == ir.NodeType.Postfix) {
		auto p = parent.toPostfixFast();
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

ir.Type handleStore(Context ctx, string ident, ref ir.Exp exp, ir.Store store,
                    ir.Exp child, Parent parent, StoreSource via)
{
	final switch (store.kind) with (ir.Store.Kind) {
	case Type:
		return handleTypeStore(ctx, ident, /*#ref*/exp, store, child, parent,
		                       via);
	case Scope, MultiScope:
		return handleScopeStore(ctx, ident, /*#ref*/exp, store, child, parent,
		                        via);
	case Value:
		return handleValueStore(ctx, ident, /*#ref*/exp, store, child, via);
	case Function:
		return handleFunctionStore(ctx, ident, /*#ref*/exp, store, child,
		                           parent, via);
	case FunctionParam:
		return handleFunctionParamStore(ctx, ident, /*#ref*/exp, store, child,
		                                parent, via);
	case EnumDeclaration:
		return handleEnumDeclarationStore(ctx, ident, /*#ref*/exp, store, child,
		                                  parent, via);
	case TemplateInstance:
		foreach (ti; store.templateInstances) {
			if (ti.kind == ir.TemplateKind.Function) {
				extypeTemplateInstance(ctx, ti);
			}
		}
		if (store.templateInstances.length > 0) {
			goto case Function;
		}
		goto case;
	case Template:
		throw panic(exp, "template used as a value.");
	case Merge:
	case Alias:
		assert(false);
	case Reserved:
		throw panic(exp, "reserved ident '%s' found.", store.name);
	}
}

ir.Type handleFunctionStore(Context ctx, string ident, ref ir.Exp exp,
                            ir.Store store, ir.Exp child, Parent parent,
                            StoreSource via)
{
	// Xor anybody?
	assert(via == StoreSource.Instance && child !is null ||
	       via != StoreSource.Instance && child is null);
	auto fns = store.functions;
	assert(fns.length > 0);

	size_t members;
	foreach (func; fns) {
		if (func.kind == ir.Function.Kind.Member ||
		    func.kind == ir.Function.Kind.Destructor ||
		    func.kind == ir.Function.Kind.Constructor) {
			members++;
		}

		if (func.kind == ir.Function.Kind.Nested) {
			if (fns.length > 1) {
				throw makeCannotOverloadNested(func, func);
			}
			if (func.type.isProperty) {
				throw panic("property nested functions not supported");
			}

			exp = buildExpReference(/*#ref*/exp.loc, func, ident);

			auto dgt = new ir.DelegateType(func.type);
			dgt.loc = exp.loc;
			dgt.isScope = true;
			return dgt;
		}
	}

	// Check mixing member and non-member functions.
	// @TODO Should this really be an error?
	if (members != fns.length) {
		if (members > 0) {
			throw makeMixingStaticMember(/*#ref*/exp.loc);
		}
	}

	// Handle property functions.
	if (rewriteIfPropertyStore(/*#ref*/exp, child, ident, parent, fns)) {

		auto prop = exp.toPropertyExpFast();

		// Do we need to add a this reference?
		if (child is null && prop.isMember()) {
			// Do the adding here.
			ir.Variable var;
			prop.child = getThisReferenceNotNull(exp, ctx, /*#out*/var);
		}

		// TODO check that function and child match.
		// if (<checkMemberWantTypeMatchChildType>) {
		//	throw makeWrongTypeOfThis(want, have);
		//}

		// Don't do any more processing on properties.

		// Return type.
		if (prop.getFn is null) {
			return buildNoType(/*#ref*/prop.loc);
		} else {
			return prop.getFn.type.ret;
		}
	}

	if (members == 0 && via == StoreSource.Instance) {
		throw makeStaticViaInstance(/*#ref*/exp.loc, ident);
	}

	// Check if we can do overloading.
	if (fns.length > 1 &&
	    parent != Parent.Call &&
	    parent != Parent.AssignSource) {
		// Even if they are mixed, this a good enough guess.
		if (fns[0].kind == ir.Function.Kind.Member) {
			throw makeCannotPickMemberFunction(/*#ref*/exp.loc, ident);
		} else if (via == StoreSource.Instance) {
			throw makeCannotPickStaticFunctionVia(/*#ref*/exp.loc, ident);
		} else {
			throw makeCannotPickStaticFunction(/*#ref*/exp.loc, ident);
		}
	}

	// Do we need a instance?
	// If we we're not given one get the this for the given context.
	if (members > 0 && child is null) {
		ir.Variable thisVar;
		child = getThisReferenceNotNull(exp, ctx, /*#out*/thisVar);
	}

	// Will return the first function directly if there is only one.
	ir.Declaration decl = buildSet(/*#ref*/exp.loc, fns);
	ir.ExpReference eref = buildExpReference(/*#ref*/exp.loc, decl, ident);
	ir.FunctionSet set = cast(ir.FunctionSet) decl;
	ir.Type ret;


	if (child !is null) {
		assert(members > 0);
		auto cdgt = buildCreateDelegate(/*#ref*/exp.loc, child, eref);
		cdgt.supressVtableLookup = via == StoreSource.StaticPostfix;
		exp = cdgt;

		if (set !is null) {
			set.type.isFromCreateDelegate = true;
			ret = set.type;
		} else {
			auto func = fns[0];
			auto dgt = new ir.DelegateType(func.type);
			dgt.loc = exp.loc;
			ret = dgt;
		}
	} else {
		assert(members == 0);
		exp = eref;

		if (set !is null) {
			ret = set.type;
		} else {
			assert(fns.length == 1);
			assert(fns[0].nestedHiddenParameter is null);
			ret = fns[0].type;
		}
	}

	return ret;
}

ir.Type handleValueStore(Context ctx, string ident, ref ir.Exp exp,
                         ir.Store store, ir.Exp child, StoreSource via)
{
	// Xor anybody?
	assert(via == StoreSource.Instance && child !is null ||
	       via != StoreSource.Instance && child is null);

	auto var = cast(ir.Variable) store.node;
	assert(var !is null);
	assert(var.type !is null);
	assert(var.storage != ir.Variable.Storage.Invalid);

	ir.ExpReference makeEref() {
		auto eref = new ir.ExpReference();
		eref.idents = [ident];
		eref.loc = exp.loc;
		eref.decl = var;
		return eref;
	}

	final switch (via) with (StoreSource) {
	case Instance:
		if (var.storage != ir.Variable.Storage.Field) {
			throw makeAccessThroughWrongType(/*#ref*/exp.loc, ident);
		}

		// TODO check that field is from the this type.
		// TODO Hook up aggregate
		auto ae = new ir.AccessExp();
		ae.loc = exp.loc;
		ae.child = child;
		ae.field = var;

		exp = ae;
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
		replaceExpReferenceIfNeeded(ctx, /*#ref*/exp, eref);

		// Handle nested variables.
		nestExtyperTagVariable(/*#ref*/exp.loc, ctx, var, store);

		break;
	case StaticPostfix:
		final switch (var.storage) with (ir.Variable.Storage) {
		case Invalid:
			throw panic(exp, format("invalid storage %s", var.loc.toString()));
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

	return var.type;
}

ir.Type handleFunctionParamStore(Context ctx, string ident, ref ir.Exp exp,
                                 ir.Store store, ir.Exp child, Parent parent,
                                 StoreSource via)
{
	if (via == StoreSource.Instance) {
		throw makeError(exp, "can not access function parameter via value");
	}
	auto fp = cast(ir.FunctionParam) store.node;
	assert(fp !is null);
	assert(fp.type !is null);

	auto eref = new ir.ExpReference();
	eref.idents = [ident];
	eref.loc = exp.loc;
	eref.decl = fp;
	exp = eref;

	return fp.type;
}

ir.Type handleEnumDeclarationStore(Context ctx, string ident, ref ir.Exp exp,
                                   ir.Store store, ir.Exp child, Parent parent,
                                   StoreSource via)
{
	if (via == StoreSource.Instance) {
		throw makeError(exp, "can not access enum via value");
	}

	auto ed = cast(ir.EnumDeclaration) store.node;
	assert(ed !is null);
	assert(ed.type !is null);
	assert(ed.assign !is null);

//	// TODO This logic warrants futher investigation.
//	// The commented out code does not work, while the code below does.
//	auto ed = cast(ir.EnumDeclaration) store.node;
//	assert(ed !is null);
//	assert(ed.assign !is null);
//	exp = copyExp(ed.assign);

	auto eref = new ir.ExpReference();
	eref.idents = [ident];
	eref.loc = exp.loc;
	eref.decl = ed;
	exp = eref;

	return ed.type;
}

ir.Type handleTypeStore(Context ctx, string ident, ref ir.Exp exp, ir.Store store,
                     ir.Exp child, Parent parent, StoreSource via)
{
	if (via == StoreSource.Instance) {
		throw makeError(exp, "can not access types via value");
	}

	if (store.myScope !is null) {
		return handleScopeStore(ctx, ident, /*#ref*/exp, store, child, parent, via);
	}

	auto t = cast(ir.Type) store.node;
	assert(t !is null);

	auto te = new ir.TypeExp();
	te.loc = exp.loc;
	//te.idents = [ident];
	te.type = copyTypeSmart(/*#ref*/exp.loc, t);
	exp = te;

	return te.type;
}

ir.Type handleScopeStore(Context ctx, string ident, ref ir.Exp exp, ir.Store store,
                         ir.Exp child, Parent parent, StoreSource via)
{
	if (via == StoreSource.Instance) {
		throw makeError(exp, "can not access types via value");
	}

	auto se = new ir.StoreExp();
	se.loc = exp.loc;
	se.idents = [ident];
	se.store = store;
	exp = se;

	auto ret = cast(ir.Type) store.node;
	if (ret is null) {
		return buildNoType(/*#ref*/exp.loc);
	}
	return ret;
}


/*
 *
 * extypeIdentifierExp code.
 *
 */

/*!
 * If qname has a child of name leaf, returns an expression looking it up.
 * Otherwise, null is returned.
 */
ir.Exp withLookup(Context ctx, ir.Exp withExp, string leaf)
{
	ir.Postfix access = buildPostfixIdentifier(/*#ref*/withExp.loc, copyExp(withExp), leaf);
	ir.Class _class; string emsg; ir.Scope eScope;

	auto type = realType(getExpType(withExp), false);
	retrieveScope(type, access, /*#ref*/eScope, /*#ref*/_class, /*#ref*/emsg);
	if (eScope is null) {
		throw makeBadWithType(/*#ref*/withExp.loc);
	}
	auto store = lookupInGivenScopeOnly(ctx.lp, eScope, /*#ref*/withExp.loc, leaf);
	if (store is null) {
		return null;
	}
	return access;
}

/*!
 * Replace IdentifierExps with another exp, often ExpReference.
 */
ir.Type extypeIdentifierExp(Context ctx, ref ir.Exp e, Parent parent)
{
	auto i = e.toIdentifierExpFast();
	assert(i !is null);

	switch (i.value) {
	case "this":
		return rewriteThis(ctx, /*#ref*/e, i, parent == Parent.Call);
	case "super":
		return rewriteSuper(ctx, /*#ref*/e, i,
			parent == Parent.Call,
			parent == Parent.Identifier);
	default:
	}

	auto current = i.globalLookup ? getModuleFromScope(/*#ref*/i.loc, ctx.current).myScope : ctx.current;

	// Rewrite expressions that rely on a with block lookup.
	ir.Exp rewriteExp;
	if (!i.globalLookup) foreach_reverse (withExp; ctx.withExps) {
		auto _rewriteExp = withLookup(ctx, withExp, i.value);
		if (_rewriteExp is null) {
			continue;
		}
		if (rewriteExp !is null) {
			throw makeWithCreatesAmbiguity(/*#ref*/i.loc);
		}
		rewriteExp = _rewriteExp;
		rewriteExp.loc = e.loc;
		// Continue to ensure no ambiguity.
	}
	if (rewriteExp !is null) {
		auto store = lookup(ctx.lp, current, /*#ref*/i.loc, i.value);
		if (store !is null && isStoreLocal(ctx.lp, ctx.current, store)) {
			throw makeWithCreatesAmbiguity(/*#ref*/i.loc);
		}
		e = rewriteExp;
		return extype(ctx, /*#ref*/e, parent);
	}

	// With rewriting is completed after this point, and regular lookup logic resumes.
	auto store = lookup(ctx.lp, current, /*#ref*/i.loc, i.value);
	if (store is null) {
		throw makeFailedLookup(i, i.value);
	}

	return handleStore(ctx, i.value, /*#ref*/e, store, null, parent,
	                   StoreSource.Identifier);
}

import watt.io.std;

/*
 *
 * extypePostfixExp code.
 *
 */

ir.Type replaceAAPostfixesIfNeeded(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	auto loc = exp.loc;

	switch (postfix.op) with (ir.Postfix.Op) {
	case Call:
		assert(postfix.identifier is null);

		if (postfix.child is null ||
			postfix.child.nodeType != ir.NodeType.Postfix) {
			return null;
		}
		auto child = postfix.child.toPostfixFast();
		if (child.identifier is null) {
			return null;
		}
		auto rt = realType(getExpType(child.child));
		if (rt.nodeType != ir.NodeType.AAType) {
			return null;
		}
		auto aa = rt.toAATypeFast();

		switch (child.identifier.value) {
		case "get":
			if (postfix.arguments.length != 2) {
				return null;
			}
			auto args = new ir.Exp[](3);
			args[0] = child.child;
			args[1] = postfix.arguments[0];
			args[2] = postfix.arguments[1];

			ir.BuiltinExp be;
			exp = be = buildAAGet(/*#ref*/loc, aa, args);
			return be.type;
		case "remove":
			if (postfix.arguments.length != 1) {
				return null;
			}
			auto args = new ir.Exp[](2);
			args[0] = child.child;
			args[1] = postfix.arguments[0];

			ir.BuiltinExp be;
			exp = be = buildAARemove(/*#ref*/loc, args);
			return be.type;
		default:
			return null;
		}

	case Identifier:
		auto aa = cast(ir.AAType) realType(getExpType(postfix.child));
		if (aa is null) {
			return null;
		}

		switch (postfix.identifier.value) {
		case "keys":
			ir.BuiltinExp be;
			exp = be = buildAAKeys(/*#ref*/loc, aa, [postfix.child]);
			return be.type;
		case "values":
			ir.BuiltinExp be;
			exp = be = buildAAValues(/*#ref*/loc, aa, [postfix.child]);
			return be.type;
		case "length":
			ir.BuiltinExp be;
			exp = be = buildAALength(/*#ref*/loc, ctx.lp.target, [postfix.child]);
			return be.type;
		case "rehash":
			ir.BuiltinExp be;
			exp = be = buildAARehash(/*#ref*/loc, [postfix.child]);
			return be.type;
		case "get", "remove":
			return buildNoType(/*#ref*/loc);
		default:
			auto store = lookup(ctx.lp, ctx.current, /*#ref*/postfix.loc, postfix.identifier.value);
			if (store is null || store.functions.length == 0) {
				throw makeBadBuiltin(/*#ref*/postfix.loc, aa, postfix.identifier.value);
			}
			return null;
		}
	default:
		return null;
	}
}

void handleArgumentLabelsIfNeeded(Context ctx, ref ir.Exp[] arguments, ref string[] argumentLabels,
								  ref ir.Postfix.TagKind[] argumentTags,
                                  ir.Function func, ref ir.Exp exp)
{
	if (func is null) {
		return;
	}
	size_t[string] positions;
	ir.Exp[string] defaults;
	size_t defaultArgCount;
	foreach (i, param; func.params) {
		defaults[param.name] = param.assign;
		positions[param.name] = i;
		if (param.assign !is null) {
			defaultArgCount++;
		}
	}

	if (argumentLabels.length == 0) {
		if (func.type.forceLabel && func.type.params.length > defaultArgCount) {
			throw makeForceLabel(/*#ref*/exp.loc, func);
		}
		return;
	}

	if (argumentLabels.length != arguments.length) {
		throw panic(/*#ref*/exp.loc, "argument count and label count unmatched");
	}

	// If they didn't provide all the arguments, try filling in any default arguments.
	if (arguments.length < func.params.length) {
		bool[string] labels;
		foreach (label; argumentLabels) {
			labels[label] = true;
		}
		foreach (arg, def; defaults) {
			if (def is null) {
				continue;
			}
			if (auto p = arg in labels) {
				continue;
			}
			arguments ~= copyExp(/*#ref*/def.loc, def);
			arguments[$-1].loc = def.loc;
			argumentLabels ~= arg;
			argumentTags ~= ir.Postfix.TagKind.None;
		}
	}

	if (arguments.length != func.params.length) {
		throw makeWrongNumberOfArguments(exp, func, arguments.length, func.params.length);
	}

	auto labels = new string[](arguments.length);

	// Check all the labels exist.
	for (size_t i = 0; i < argumentLabels.length; i++) {
		auto argumentLabel = argumentLabels[i];
		auto p = argumentLabel in positions;
		if (p is null) {
			throw makeUnmatchedLabel(/*#ref*/exp.loc, argumentLabel);
		}
		foreach (previouslySeenLabel; labels) {
			if (previouslySeenLabel == argumentLabel) {
				throw makeDuplicateLabel(/*#ref*/exp.loc, argumentLabel);
			}
		}
		labels[i] = argumentLabel;
	}

	// Reorder arguments to match parameter order.
	for (size_t i = 0; i < argumentLabels.length; i++) {
		auto argumentLabel = argumentLabels[i];
		auto p = argumentLabel in positions;
		if (p is null) {
			throw makeUnmatchedLabel(/*#ref*/exp.loc, argumentLabel);
		}
		auto labelIndex = *p;
		if (labelIndex == i) {
			continue;
		}
		auto tmp = arguments[i];
		auto tmp2 = argumentLabels[i];
		auto tmp3 = argumentTags[i];
		arguments[i] = arguments[labelIndex];
		argumentLabels[i] = argumentLabels[labelIndex];
		argumentTags[i] = 	argumentTags[labelIndex];
		arguments[labelIndex] = tmp;
		argumentLabels[labelIndex] = tmp2;
		argumentTags[labelIndex] = tmp3;
		i = 0;
	}
}

//! Given a.foo, if a is a pointer to a class, turn it into (*a).foo.
private void dereferenceInitialClass(ir.Postfix postfix, ir.Type type)
{
	if (!isPointerToClass(type)) {
		return;
	}

	postfix.child = buildDeref(/*#ref*/postfix.child.loc, postfix.child);
}

// Verify va_start and va_end, then emit BuiltinExps for them.
private void rewriteVaStartAndEnd(Context ctx, ir.Function func,
                                  ir.Postfix postfix, ref ir.Exp exp)
{
	if (func is ctx.lp.vaStartFunc ||
	    func is ctx.lp.vaEndFunc) {
		if (postfix.arguments.length != 1) {
			throw makeWrongNumberOfArguments(postfix, func, postfix.arguments.length, 1);
		}
		auto etype = getExpType(postfix.arguments[0]);
		auto ptr = cast(ir.PointerType) etype;
		if (ptr is null || !isVoid(ptr.base)) {
			throw makeExpected(postfix, "va_list argument");
		}
		if (!isLValue(postfix.arguments[0])) {
			throw makeVaFooMustBeLValue(/*#ref*/postfix.arguments[0].loc, func.name);
		}
		if (ctx.currentFunction.type.linkage == ir.Linkage.Volt) {
			if (func is ctx.lp.vaStartFunc) {
				auto eref = buildExpReference(/*#ref*/postfix.loc, ctx.currentFunction.type.varArgsArgs, "_args");
				exp = buildVaArgStart(/*#ref*/postfix.loc, postfix.arguments[0], eref);
				return;
			} else if (func is ctx.lp.vaEndFunc) {
				exp = buildVaArgEnd(/*#ref*/postfix.loc, postfix.arguments[0]);
				return;
			} else {
				throw makeExpected(/*#ref*/postfix.loc, "volt va_args function.");
			}
		}
	}
}

private void resolvePostfixOverload(Context ctx, ir.Postfix postfix,
                                    ir.ExpReference eref, ref ir.Function func,
                                    ref ir.CallableType asFunctionType,
                                    ref ir.FunctionSetType asFunctionSet,
                                    bool reeval)
{
	if (eref is null) {
		throw panic(/*#ref*/postfix.loc, "expected expref");
	}
	asFunctionSet.set.reference = eref;
	func = selectFunction(ctx.lp.target, asFunctionSet.set, postfix.arguments, /*#ref*/postfix.loc);
	eref.decl = func;
	asFunctionType = func.type;

	if (reeval) {
		replaceExpReferenceIfNeeded(ctx, /*#ref*/postfix.child, eref);
	}
}

/*!
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
	auto etype = getExpType(arguments[i]);
	auto arr = cast(ir.ArrayType) asFunctionType.params[i];
	if (arr is null) {
		throw panic(/*#ref*/arguments[0].loc, "homogenous variadic not array type");
	}
	foreach (arg; arguments[i .. $]) {
		if (getExpType(arg).nodeType == ir.NodeType.NullType) {
			throw makeUnsupported(/*#ref*/arg.loc, "null arguments to homogenous variadic functions");
		}
	}
	if (willConvert(arr, etype)) {
		return;
	}
	if (!typesEqual(etype, arr)) {
		auto exps = arguments[i .. $];
		if (exps.length == 1) {
			auto alit = cast(ir.ArrayLiteral) exps[0];
			if (alit !is null && alit.exps.length == 0) {
				exps = null;
			}
		}
		foreach (ref aexp; exps) {
			checkAndConvertStringLiterals(ctx, arr.base, /*#ref*/aexp);
		}
		arguments[i] = buildArrayLiteralSmart(/*#ref*/arguments[0].loc, asFunctionType.params[i], exps);
		arguments = arguments[0 .. i + 1];
		return;
	}
}

/*!
 * Turns identifier postfixes into CreateDelegates,
 * and resolves property function calls in postfixes,
 * type safe varargs, and explicit constructor calls.
 */
ir.Type extypePostfixLeave(Context ctx, ref ir.Exp exp, ir.Postfix postfix,
                           Parent parent)
{
	if (postfix.arguments.length > 0) {
		ctx.enter(postfix);
		foreach (ref arg; postfix.arguments) {
			extype(ctx, /*#ref*/arg, Parent.NA);
		}
		ctx.leave(postfix);
	}

	if (auto ret = opOverloadRewritePostfix(ctx, postfix, /*#ref*/exp)) {
		return ret;
	}

	if (auto ret = replaceAAPostfixesIfNeeded(ctx, /*#ref*/exp, postfix)) {
		return ret;
	}

	final switch (postfix.op) with (ir.Postfix.Op) {
	case Slice:
		auto t = realType(getExpType(postfix.child));
		auto nt = t.nodeType;
		if (nt != ir.NodeType.PointerType && nt != ir.NodeType.StaticArrayType &&
		    nt != ir.NodeType.ArrayType) {
			throw makeCannotSlice(/*#ref*/postfix.loc, t);
		}
		break;
	case CreateDelegate:
		// TODO write checking code?
		break;
	case Increment:
	case Decrement:
		if (effectiveConstAccessExp(postfix.child)) {
			auto ptype = getExpType(postfix.child);
			throw makeCannotModify(postfix.child, ptype);
		}
		// TODO Check that child is a PrimtiveType.
		break;
	case Identifier:
		return extypePostfixIdentifier(ctx, /*#ref*/exp, postfix, parent);
	case Call:
		extypePostfixCall(ctx, /*#ref*/exp, postfix);
		break;
	case Index:
		extypePostfixIndex(ctx, /*#ref*/exp, postfix);
		break;
	case Default:
		if (postfix.child.nodeType == ir.NodeType.TypeExp ||
			postfix.child.nodeType == ir.NodeType.TypeReference ||
			postfix.child.nodeType == ir.NodeType.StoreExp) {
			auto t = realType(getExpType(postfix.child));
			exp = getDefaultInit(/*#ref*/exp.loc, ctx.lp, t);
		} else {
			throw makeDefaultOnExpression(/*#ref*/exp.loc);
		}
		break;
	case None:
		throw panic(postfix, "invalid op");
	}

	return getExpType(exp);
}

void extypePostfixCall(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	assert(postfix.op == ir.Postfix.Op.Call);

	ir.Function func;
	ir.CallableType asFunctionType;

	// This is a hack to handle UFCS
	auto b = cast(ir.BuiltinExp) postfix.child;
	if (b !is null && b.kind == ir.BuiltinExp.Kind.UFCS) {
		// Should we really call selectFunction here?
		auto arguments = b.children[0] ~ postfix.arguments;
		func = selectFunction(ctx.lp.target, b.functions, arguments, /*#ref*/postfix.loc);

		if (func is null) {
			throw makeNoFieldOrPropertyOrUFCS(/*#ref*/postfix.loc, postfix.identifier.value, getExpType(postfix.child));
		}

		postfix.arguments = arguments;
		postfix.child = buildExpReference(/*#ref*/postfix.loc, func, func.name);
		// We are done, make sure that the rebuilt call isn't messed with when
		// it get visited again by the extypePostfix function.

		auto theTag = ir.Postfix.TagKind.None;
		if (func.type.isArgRef[0]) {
			theTag = ir.Postfix.TagKind.Ref;
		} else if (func.type.isArgOut[0]) {
			theTag = ir.Postfix.TagKind.Out;
		}

		if (postfix.argumentLabels.length > 0) {
			postfix.argumentLabels = [func.params[0].name] ~ postfix.argumentLabels;
		}

		postfix.argumentTags = theTag ~ postfix.argumentTags;
		asFunctionType = func.type;

	} else {
		if (postfix.arguments.length == 0 &&
		    b !is null &&
		    (b.kind == ir.BuiltinExp.Kind.AAKeys ||
		    b.kind == ir.BuiltinExp.Kind.AAValues)) {
		    exp = postfix.child;
		    return;
		}
		auto childType = getExpType(postfix.child);

		auto eref = cast(ir.ExpReference) postfix.child;
		bool reeval = true;

		if (eref is null) {
			reeval = false;
			auto pchild = cast(ir.Postfix) postfix.child;
			if (pchild !is null) {
				eref = cast(ir.ExpReference) pchild.memberFunction;
			}
		}

		auto asFunctionSet = cast(ir.FunctionSetType) realType(childType);
		if (asFunctionSet !is null) {
			resolvePostfixOverload(ctx, postfix, eref, /*#ref*/func,
			                       /*#ref*/asFunctionType, /*#ref*/asFunctionSet,
			                       reeval);
		} else if (eref !is null) {
			func = cast(ir.Function) eref.decl;
			if (func !is null) {
				asFunctionType = func.type;
			}
		}

		if (asFunctionType is null) {
			asFunctionType = cast(ir.CallableType) realType(childType);
		}

		auto podAgg = cast(ir.PODAggregate)realType(childType);
		if (podAgg !is null && podAgg.constructors.length > 0) {
			if (isValueExp(postfix.child)) {
				throw makeStructValueCall(/*#ref*/postfix.loc, podAgg.name);
			}
			auto ctor = selectFunction(ctx.lp.target, podAgg.constructors, postfix.arguments, /*#ref*/postfix.loc);
			exp = buildPODCtor(/*#ref*/postfix.loc, podAgg, postfix, ctor);
			return;
		}

		if (asFunctionType is null) {
			if (postfix.child.nodeType == ir.NodeType.PropertyExp) {
				throw makeBadPropertyCall(postfix, childType);
			} else {
				throw makeBadCall(postfix, childType);
			}
		}
	}

	assert(asFunctionType !is null);

	// All of the selecting function work has been done,
	// and we have a single function or function type to call.
	// Though func might be null.

	handleArgumentLabelsIfNeeded(ctx, /*#ref*/postfix.arguments,
		/*#ref*/postfix.argumentLabels, /*#ref*/postfix.argumentTags, func, /*#ref*/exp);

	// Not providing an argument to a homogenous variadic function.
	if (asFunctionType.homogenousVariadic && postfix.arguments.length + 1 == asFunctionType.params.length) {
		postfix.arguments ~= buildArrayLiteralSmart(/*#ref*/postfix.loc, asFunctionType.params[$-1]);
	}

	rewriteVaStartAndEnd(ctx, func, postfix, /*#ref*/exp);
	if ((asFunctionType.hasVarArgs && asFunctionType.linkage == ir.Linkage.Volt) ||
		func is ctx.lp.vaStartFunc || func is ctx.lp.vaEndFunc) {
		return;
	}

	appendDefaultArguments(ctx, postfix.loc, /*#ref*/postfix.arguments, func);
	if (!(asFunctionType.hasVarArgs || asFunctionType.params.length > 0 && asFunctionType.homogenousVariadic) &&
	    postfix.arguments.length != asFunctionType.params.length) {
		throw makeWrongNumberOfArguments(postfix, func, postfix.arguments.length, asFunctionType.params.length);
	}
	assert(asFunctionType.params.length <= postfix.arguments.length);
	rewriteHomogenousVariadic(ctx, asFunctionType, /*#ref*/postfix.arguments);
	checkCallRefOutTags(ctx, asFunctionType, /*#ref*/postfix.arguments,
		/*#ref*/postfix.argumentTags);
}

void checkCallRefOutTags(Context ctx, ir.CallableType ftype, ref ir.Exp[] arguments,
	ref ir.Postfix.TagKind[] argumentTags)
{
	foreach (i; 0 .. ftype.params.length) {
		if (i < argumentTags.length) {
			auto _paramref = ftype.isArgRef[i];
			auto _paramout = ftype.isArgOut[i];
			auto _tagref   = argumentTags[i] == ir.Postfix.TagKind.Ref;
			auto _tagout   = argumentTags[i] == ir.Postfix.TagKind.Out;
			auto _tagnone  = argumentTags[i] == ir.Postfix.TagKind.None;
			if (_paramref || _paramout) {
				if (!isLValue(arguments[i])) {
					throw makeNotLValueButRefOut(arguments[i], ftype.isArgRef[i]);
				}
				if ((_paramref && _tagout) || (_paramout && _tagref)) {
					throw makeWrongTag(arguments[i], _tagref);
				}
				if (_paramref && _tagnone) {
					throw makeNotTaggedRef(arguments[i]);
				}
				if (_paramout && _tagnone) {
					throw makeNotTaggedOut(arguments[i]);
				}
			}
			if (!_paramref && !_paramout && !_tagnone) {
				throw makeSpuriousTag(arguments[i], _tagref);
			}
		}
		tagLiteralType(arguments[i], ftype.params[i]);
		checkAndConvertStringLiterals(ctx, ftype.params[i], /*#ref*/arguments[i]);
	}
}

/*!
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
	thisRef = getThisReferenceNotNull(eRef, ctx, /*#out*/thisVar);
	assert(thisRef !is null && thisVar !is null);

	auto tr = cast(ir.TypeReference) thisVar.type;
	assert(tr !is null);

	auto thisAgg = cast(ir.Aggregate) tr.type;
	auto referredType = thisAgg;
	auto expressionAgg = referredType;
	assert(thisAgg !is null);

	string ident = eRef.idents[$-1];
	auto store = lookupInGivenScopeOnly(ctx.lp, expressionAgg.myScope, /*#ref*/exp.loc, ident);
	if (store !is null && store.node !is eRef.decl) {
		if (eRef.decl.nodeType !is ir.NodeType.FunctionParam) {
			bool found = false;
			foreach (func; store.functions) {
				if (func is eRef.decl) {
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
		thisRef = buildCastSmart(/*#ref*/eRef.loc, expressionClass, thisRef);
	}

	if (eRef.decl.declKind == ir.Declaration.Kind.Function) {
		exp = buildCreateDelegate(/*#ref*/eRef.loc, thisRef, eRef);
	} else {
		auto var = cast(ir.Variable)eRef.decl;
		panicAssert(eRef, var !is null);
		exp = buildAccessExp(/*#ref*/eRef.loc, thisRef, var);
	}

	return;
}

/*!
 * Turn identifier postfixes into <ExpReference>.ident.
 */
ir.Type consumeIdentsIfScopesOrTypes(Context ctx, ref ir.Postfix[] postfixes,
                                     ref ir.Exp exp, Parent parent)
{
	ir.Store lookStore; // The store that we are look in.
	ir.Scope lookScope; // The scope attached to the lookStore.
	ir.Type lookType;   // If lookStore is a type, the type.

	// Only consume identifiers.
	if (postfixes[0].op != ir.Postfix.Op.Identifier) {
		return null;
	}

	void setupArrayAndExp(ir.Exp toReplace, size_t i)
	{
		if (i+1 >= postfixes.length) {
			exp = toReplace;
			postfixes = null;
		} else {
			postfixes[i+1].child = toReplace;
			postfixes = postfixes[i+1 .. $];
		}
	}

	if (!getIfStoreOrTypeExp(postfixes[0].child, /*#out*/lookStore, /*#out*/lookType)) {
		return null;
	}

	// Early out on type only.
	if (lookStore is null) {
		assert(lookType !is null);
		ir.Exp toReplace = postfixes[0];
		if (typeLookup(ctx, /*#ref*/toReplace, lookType)) {
			setupArrayAndExp(toReplace, 0);
			// TODO XXX replace
			return getExpType(exp);
		}
		// We have no scope to look in.
		return null;
	}

	// Get a scope from said lookStore.
	lookScope = lookStore.myScope;
	assert(lookScope !is null || lookStore.scopes.length > 0);

	// Loop over the identifiers.
	foreach (i, postfix; postfixes) {
		// First check type.
		if (lookType !is null) {
			// Remove int.max etc.
			ir.Exp toReplace = postfixes[i];
			if (typeLookup(ctx, /*#ref*/toReplace, lookType)) {
				setupArrayAndExp(toReplace, i);
				// TODO XXX replace
				return getExpType(exp);
			}
		}

		// Do the actual lookup.
		assert(postfix.identifier !is null);
		string name = postfix.identifier.value;
		ir.Store store;
		if (lookScope is null) {
			store = lookupAsImportScopes(ctx.lp, lookStore.scopes, /*#ref*/postfix.loc, name);
		} else {
			store = lookupAsThisScope(ctx.lp, lookScope, /*#ref*/postfix.loc, name, ctx.current);
		}
		if (store is null) {
			auto asEnum = cast(ir.Enum)lookType;
			if (asEnum !is null && asEnum.name != "") {
				throw makeFailedEnumLookup(/*#ref*/postfix.loc, asEnum.name, name);
			} else {
				throw makeFailedLookup(/*#ref*/postfix.loc, name);
			}
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
		auto t = handleStore(ctx, name, /*#ref*/toReplace, store, null,
		                     parentKind, StoreSource.StaticPostfix);
		setupArrayAndExp(toReplace, i);
		return t;
	}

	assert(false);
}

void extypePostfixIndex(Context ctx, ref ir.Exp exp, ir.Postfix postfix)
{
	assert(postfix.op == ir.Postfix.Op.Index);
	assert(postfix.arguments.length == 1);

	auto errorType = getExpType(postfix.child);
	auto type = realType(errorType);
	switch (type.nodeType) with (ir.NodeType) {
	case AAType:
		auto aa = cast(ir.AAType)type;
		checkAndDoConvert(ctx, aa.key, /*#ref*/postfix.arguments[0]);
		break;
	case StaticArrayType:
	case PointerType:
	case ArrayType:
		auto sizeT = buildSizeT(/*#ref*/exp.loc, ctx.lp.target);
		auto argType = getExpType(postfix.arguments[0]);
		if (!isIntegralOrBool(realType(argType))) {
			throw makeBadImplicitCast(postfix, argType, sizeT);
		}
		break;
	default:
		throw makeInvalidIndexValue(exp, errorType);
	}
}

/*!
 * This function will check for ufcs functions on a Identifier postfix,
 * it assumes we have already looked for a field and not found anything.
 *
 * Volt does not support property ufcs functions.
 */
void postfixIdentifierUFCS(Context ctx, ref ir.Exp exp,
                           ir.Postfix postfix, Parent parent)
{
	assert(postfix.identifier !is null);

	auto invalidstore = ctx.current.getStore(postfix.identifier.value);
	if (invalidstore !is null && invalidstore.functions.length == 0) {
		/* Bypass the worktracker to look for an invalid field lookup of the same
		 * name of the variable that it's being assigned to.
		 * See test `bugs.lookup.invalidSameNameField` for more details.
		 */
		throw makeNoFieldOrPropertyOrUFCS(/*#ref*/postfix.loc, postfix.identifier.value, getExpType(postfix.child));
	}

	auto store = lookup(ctx.lp, ctx.current, /*#ref*/postfix.loc, postfix.identifier.value);
	if (store is null || store.functions.length == 0) {
		throw makeNoFieldOrPropertyOrUFCS(/*#ref*/postfix.loc, postfix.identifier.value, getExpType(postfix.child));
	}

	bool isProp;
	foreach (func; store.functions) {
		if (isProp && !func.type.isProperty) {
			throw makeUFCSAndProperty(/*#ref*/postfix.loc, postfix.identifier.value);
		}

		isProp = func.type.isProperty;
	}

	if (isProp) {
		throw makeUFCSAsProperty(/*#ref*/postfix.loc);
	}

	// This is here to so that it errors
	if (parent != Parent.Call) {
		throw makeNoFieldOrPropertyOrIsUFCSWithoutCall(/*#ref*/postfix.loc, postfix.identifier.value);
	}

	auto type = getExpType(postfix.child);
	auto set = buildSet(/*#ref*/postfix.loc, store.functions);

	exp = buildUFCS(/*#ref*/postfix.loc, type, postfix.child, store.functions);
}

ir.Type builtInField(Context ctx, ref ir.Exp exp, ir.Exp child, ir.Type type, string field)
{
	type = realType(type);

	bool isPointer;
	auto ptr = cast(ir.PointerType) type;
	if (ptr !is null) {
		isPointer = true;
		type = ptr.base;
	}

	auto clazz = cast(ir.Class)type;
	auto iface = cast(ir._Interface)type;
	if (clazz !is null || iface !is null) switch (field) {
	case "classinfo":
		auto t = copyTypeSmart(/*#ref*/exp.loc, ctx.lp.tiClassInfo);
		ir.BuiltinExp b;
		exp = b = buildClassinfo(/*#ref*/exp.loc, t, child);
		return b.type;
	default:
		return null;
	}

	auto array = cast(ir.ArrayType) type;
	auto sarray = cast(ir.StaticArrayType) type;
	if (sarray is null && array is null) {
		return null;
	}

	switch (field) {
	case "ptr":
		auto base = array is null ? sarray.base : array.base;
		assert(base !is null);

		if (isPointer) {
			child = buildDeref(/*#ref*/exp.loc, child);
		}
		ir.BuiltinExp b;
		exp = b = buildArrayPtr(/*#ref*/exp.loc, base, child);
		return b.type;
	case "length":
		if (isPointer) {
			child = buildDeref(/*#ref*/exp.loc, child);
		}
		ir.BuiltinExp b;
		exp = b = buildArrayLength(/*#ref*/exp.loc, ctx.lp.target, child);
		return b.type;
	default:
		// Error?
		return null;
	}
}

/*!
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

	foreach (func; funcs) {
		if (!func.type.isProperty) {
			continue;
		}

		if (func.type.params.length > 1) {
			throw panic(func, "property function with more than one argument.");
		} else if (func.type.params.length == 1) {
			setFns ~= func;
			continue;
		}

		// func.params.length is 0

		if (getFn !is null) {
			throw makeMultipleZeroProperties(/*#ref*/exp.loc);
		}
		getFn = func;
	}

	if (getFn is null && setFns.length == 0) {
		return false;
	}

	if (parent != Parent.AssignTarget && getFn is null) {
		throw makeNoZeroProperties(/*#ref*/exp.loc);
	}

	exp = buildProperty(/*#ref*/exp.loc, name, child, getFn, setFns);

	return true;
}

/*!
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
ir.Type extypePostfixIdentifier(Context ctx, ref ir.Exp exp,
                                ir.Postfix postfix, Parent parent)
{
	assert(postfix.op == ir.Postfix.Op.Identifier);

	string field = postfix.identifier.value;

	ir.Type oldType = getExpType(postfix.child);
	ir.Type type = realType(oldType, false);
	assert(type !is null);
	assert(type.nodeType != ir.NodeType.FunctionSetType);
	if (auto ret = builtInField(ctx, /*#ref*/exp, postfix.child, type, field)) {
		return ret;
	}

	// If we are pointing to a pointer to a class.
	dereferenceInitialClass(postfix, oldType);

	// Get store for ident on type, do not look for ufcs functions.
	ir.Store store;
	auto _scope = getScopeFromType(type);
	if (_scope !is null) {
		store = lookupAsThisScope(ctx.lp, _scope, /*#ref*/postfix.loc, field, ctx.current);
	}

	if (store is null) {
		// Check if there is a UFCS function.
		// Note that Volt doesn't not support UFCS get/set properties
		// unlike D which does, this is because we are going to
		// remove properties in favor for C# properties.

		postfixIdentifierUFCS(ctx, /*#ref*/exp, postfix, parent);

		// postfixIdentifierUFCS will error so if we get here all is good.
		// TODO XXX replace
		return getExpType(exp);
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
		ctx.lp, _scope, /*#ref*/postfix.loc, field);
	assert(store2 !is null);

	// What if store and store2 fields does not match?
	// TODO this should be handled by the handleStore functions,
	// pereferedly looking at childs type and see if they match.
	auto var = cast(ir.Variable) store.node;
	auto var2 = cast(ir.Variable) store.node;
	if (var !is null && var !is var2 &&
	    var.storage == ir.Variable.Storage.Field) {
		throw makeAccessThroughWrongType(/*#ref*/postfix.loc, field);
	}

	return handleStore(ctx, field, /*#ref*/exp, store, postfix.child, parent,
	                   StoreSource.Instance);
}

ir.Type extypePostfix(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto postfix = cast(ir.Postfix) exp;
	auto allPostfixes = collectPostfixes(postfix);

	// Process first none postfix exp, often a IdentifierExp.
	// 'ident'.field.prop
	// 'typeid(int)'.mangledName
	// 'int'.max
	{
		auto top = allPostfixes[0];
		auto parentKind = classifyRelationship(top.child, top);
		// Need to be forced to unchecked here.
		extypeUnchecked(ctx, /*#ref*/allPostfixes[0].child, parentKind);
	}

	auto ret = consumeIdentsIfScopesOrTypes(ctx, /*#ref*/allPostfixes, /*#ref*/exp, parent);
	if (ret !is null && allPostfixes.length == 0) {
		return ret;
	}

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

			return extypePostfixLeave(ctx, /*#ref*/exp, working, parent);
		} else {
			// Set the next in line as parent. This allows handling
			// of bar.ufcs(4, 5) and the like.
			auto tmp = allPostfixes[0];

			// Make sure we haven't rewritten this yet.
			assert(tmp.child is working);

			auto parentKind = classifyRelationship(working, tmp);
			extypePostfixLeave(ctx, /*#ref*/tmp.child, working, parentKind);
		}
	}

	assert(false);
}


/*
 *
 * extypeUnary code.
 *
 */

/*!
 * Stops casting to an overloaded function name, casting from null, and wires
 * up some runtime magic needed for classes.
 */
void extypeUnaryCastTo(Context ctx, ref ir.Exp exp, ir.Unary unary)
{
	assert(unary.type !is null);
	assert(unary.value !is null);

	auto type = realType(getExpType(unary.value));
	auto toType = realType(unary.type);
	if (type.nodeType == ir.NodeType.FunctionSetType) {
		auto fset = cast(ir.FunctionSetType) type;
		throw makeCannotDisambiguate(unary, fset.set.functions, null);
	}

	// Handling cast(Foo)null
	if (handleIfNull(ctx, unary.type, /*#ref*/unary.value)) {
		exp = unary.value;
		return;
	}

	if (isDelegate(toType) && isPointer(type)) {
		throw makeCannotCastPointerToDelegate(/*#ref*/exp.loc);
	}

	if (isAggregate(type) && toType.nodeType == ir.NodeType.PrimitiveType) {
		throw makeBadAggregateToPrimitive(unary, type, toType);
	}

	ir.Type to = getClass(unary.type);
	if (to is null) {
		to = cast(ir._Interface)toType;
	}
	auto from = getClass(type);

	if (to is null || from is null || to is from) {
		return;
	}

	auto tid = buildTypeidSmart(/*#ref*/unary.loc, ctx.lp.tiTypeInfo, to);
	auto val = buildCastToVoidPtr(/*#ref*/unary.loc, unary.value);
	rewriteCall(ctx, /*#ref*/unary.value, ctx.lp.castFunc, [val, cast(ir.Exp)tid]);
}

/*!
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
		_unary.type = copyTypeSmart(/*#ref*/_unary.loc, getExpType(_unary.argumentList[0]));
	}
	auto pt = cast(ir.PrimitiveType)_unary.type;
	if (pt !is null) {
		// new i32(4);
		auto loc = _unary.loc;
		if (_unary.argumentList.length != 1) {
			throw makeExpectedOneArgument(/*#ref*/loc);
		}
		auto sexp = buildStatementExp(/*#ref*/loc);
		auto ptr = buildPtrSmart(/*#ref*/loc, _unary.type);

		auto argument = _unary.argumentList[0];
		_unary.argumentList = null;
		auto ptrVar = buildVariableAnonSmart(ctx.lp.errSink, /*#ref*/loc, ctx.current, sexp, ptr, _unary);

		auto deref = buildDeref(/*#ref*/loc, buildExpReference(/*#ref*/loc, ptrVar, ptrVar.name));
		auto assign = buildAssign(/*#ref*/loc, deref, argument);
		buildExpStat(/*#ref*/loc, sexp, assign);
		sexp.exp = buildExpReference(/*#ref*/loc, ptrVar, ptrVar.name);
		exp = sexp;
		return;
	}
	auto array = cast(ir.ArrayType) _unary.type;
	if (array !is null) {
		if (_unary.argumentList.length == 0) {
			throw makeExpected(_unary, "argument(s)");
		}
		auto type = realType(getExpType(_unary.argumentList[0]));
		bool isArraySize = isIntegral(type);
		foreach (ref arg; _unary.argumentList) {
			if (isIntegral(realType(getExpType(arg)))) {
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
			auto asArray = cast(ir.ArrayType)type;
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

	auto func = selectFunction(ctx.lp.target, _class.userConstructors, _unary.argumentList, /*#ref*/_unary.loc);
	if (func.access != ir.Access.Public &&
		getModuleFromScope(/*#ref*/_unary.loc, _class.myScope) !is getModuleFromScope(/*#ref*/_unary.loc, ctx.current)) {
		throw makeBadAccess(/*#ref*/_unary.loc, "this", func.access);
	}
	_unary.ctor = func;

	ctx.lp.resolve(ctx.current, func);

	handleArgumentLabelsIfNeeded(ctx, /*#ref*/_unary.argumentList,
		/*#ref*/_unary.argumentLabels, /*#ref*/_unary.argumentTags,
		func, /*#ref*/exp);

	appendDefaultArguments(ctx, _unary.loc, /*#ref*/_unary.argumentList, func);
	if (_unary.argumentList.length > 0) {
		rewriteHomogenousVariadic(ctx, func.type, /*#ref*/_unary.argumentList);
	}

	for (size_t i = 0; i < _unary.argumentList.length; ++i) {
		checkAndDoConvert(ctx, func.type.params[i], /*#ref*/_unary.argumentList[i]);
	}
	checkCallRefOutTags(ctx, func.type, /*#ref*/_unary.argumentList, /*#ref*/_unary.argumentTags);
}

/*!
 * Lower 'new foo[0 .. $]' expressions to BuiltinExps.
 */
void extypeUnaryDup(Context ctx, ref ir.Exp exp, ir.Unary _unary)
{
	panicAssert(_unary, _unary.dupBeginning !is null);
	panicAssert(_unary, _unary.dupEnd !is null);

	auto loc = exp.loc;
	if (!ctx.isFunction) {
		throw makeExpected(/*#ref*/loc, "function context");
	}

	auto type = getExpType(_unary.value);
	auto asStatic = cast(ir.StaticArrayType)realType(type);
	if (asStatic !is null) {
		type = buildArrayTypeSmart(/*#ref*/asStatic.loc, asStatic.base);
	}

	auto rtype = realType(type);
	if (rtype.nodeType != ir.NodeType.AAType &&
	    rtype.nodeType != ir.NodeType.ArrayType) {
		throw makeCannotDup(/*#ref*/loc, rtype);
	}

	if (rtype.nodeType == ir.NodeType.AAType) {
		if (!_unary.fullShorthand) {
			// Actual indices were used, which makes no sense for AAs.
			throw makeExpected(/*#ref*/loc, "`new <exp>[..]` shorthand syntax");
		}
		auto aa = cast(ir.AAType)rtype;
		panicAssert(rtype, aa !is null);
		exp = buildAADup(/*#ref*/loc, aa, [_unary.value]);
	} else {
		exp = buildArrayDup(/*#ref*/loc, rtype, [copyExp(_unary.value), copyExp(_unary.dupBeginning), copyExp(_unary.dupEnd)]);
	}
}

ir.Type extypeUnary(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto unary = cast(ir.Unary) exp;
	assert(unary !is null);

	if (unary.type !is null) {
		if (unary.op == ir.Unary.Op.New) {
			auto tr = unary.type.toTypeReferenceChecked();
			string name;
			if (tr !is null) {
				name = tr.id.toString();
			}
		}
		resolveType(ctx, /*#ref*/unary.type);
	}
	if (unary.value !is null) {
		extype(ctx, /*#ref*/unary.value, Parent.NA);
	}
	foreach (ref arg; unary.argumentList) {
		extype(ctx, /*#ref*/arg, Parent.NA);
	}
	if (unary.dupBeginning !is null) {
		extype(ctx, /*#ref*/unary.dupBeginning, Parent.NA);
	}
	if (unary.dupEnd !is null) {
		extype(ctx, /*#ref*/unary.dupEnd, Parent.NA);
	}

	if (auto ret = opOverloadRewriteUnary(ctx, unary, /*#ref*/exp)) {
		return ret;
	}

	final switch (unary.op) with (ir.Unary.Op) {
	case Cast:
		extypeUnaryCastTo(ctx, /*#ref*/exp, unary);
		// TODO XXX replace
		return getExpType(exp);
	case New:
		extypeUnaryNew(ctx, /*#ref*/exp, unary);
		// TODO XXX replace
		return getExpType(exp);
	case Dup:
		extypeUnaryDup(ctx, /*#ref*/exp, unary);
		// TODO XXX replace
		return getExpType(exp);
	case Not:
	case Complement:
		auto t = getExpType(unary.value);
		if (!isIntegralOrBool(realType(t))) {
			throw makeExpected(exp, "integral or bool value");
		}
		return getExpType(exp);
	case Plus:
	case Minus:
		auto t = realType(getExpType(unary.value));
		if (!isIntegral(t) && !isFloatingPoint(t)) {
			throw makeExpected(exp, "integral value");
		}
		return getExpType(exp);
	case AddrOf:
	case Increment:
	case Decrement:
		if (!isLValue(unary.value)) {
			throw makeExpected(exp, "lvalue");
		}
		if (effectiveConstAccessExp(unary.value)) {
			auto utype = getExpType(unary.value);
			throw makeCannotModify(exp, utype);
		}
		return getExpType(exp);
	case Dereference:
		auto t = getExpType(unary.value);
		if (!isPointer(realType(t))) {
			throw makeExpected(exp, "pointer");
		} else {
			auto ptr = cast(ir.PointerType)realType(t);
			if (isVoid(ptr.base)) {
				throw makeExpected(exp, "non-void pointer");
			}
		}
		return getExpType(exp);
	case TypeIdent:
		// TODO XXX replace
		return getExpType(exp);
	case None:
		assert(false);
	}
}


/*
 *
 * extypeBinOp code.
 *
 */

/*!
 * Everyone's favourite: integer promotion! :D!
 * In general, converts to the largest type needed in a binary expression.
 */
ir.Type extypeBinOp(Context ctx, ir.BinOp bin, ir.PrimitiveType lprim, ir.PrimitiveType rprim)
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
				if (fitsInPrimitive(ctx.lp.target, lprim, bin.right)) {
					bin.right = buildCastSmart(lprim, bin.right);
					rightUnsigned = true;
					rightsz = leftsz;
					rprim = lprim;
				}
			} else {
				if (fitsInPrimitive(ctx.lp.target, rprim, bin.left)) {
					bin.left = buildCastSmart(rprim, bin.left);
					leftUnsigned = true;
					leftsz = rightsz;
					lprim = rprim;
				}
			}
			bool smallerUnsigned = leftsz < rightsz ? leftUnsigned : rightUnsigned;
			size_t smallersz = leftsz < rightsz ? leftsz : rightsz;
			size_t biggersz = leftsz > rightsz ? leftsz : rightsz;
			if ((leftsz <= shortsz && rightsz <= shortsz) || (smallerUnsigned && smallersz < biggersz)) {
				// Safe.
			} else if (leftUnsigned != rightUnsigned) {
				throw makeMixedSignedness(/*#ref*/bin.loc);
			}
		}
	}

	if (bin.op != ir.BinOp.Op.Assign &&
	    bin.op != ir.BinOp.Op.Is &&
	    bin.op != ir.BinOp.Op.NotIs &&
	    bin.op != ir.BinOp.Op.Equal &&
	    bin.op != ir.BinOp.Op.NotEqual) {
		if (isBool(lprim)) {
			auto i = buildInt(/*#ref*/bin.left.loc);
			lprim = i;
			bin.left = buildCastSmart(i, bin.left);
		}
		if (isBool(rprim)) {
			auto i = buildInt(/*#ref*/bin.right.loc);
			rprim = i;
			bin.right = buildCastSmart(i, bin.right);
		}
	}

	size_t largestsz;
	ir.PrimitiveType largestType;
	ir.PrimitiveType ret;

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
			largestType = buildInt(/*#ref*/bin.loc);
		}

		if (leftsz < largestsz) {
			bin.left = buildCastSmart(largestType, bin.left);
		}

		if (rightsz < largestsz) {
			bin.right = buildCastSmart(largestType, bin.right);
		}

		ret = largestType;
	} else {
		if (isFloatingPoint(lprim) && isIntegral(rprim)) {
			bin.right = buildCastSmart(lprim, bin.right);
			ret = lprim;
		} else {
			bin.left = buildCastSmart(rprim, bin.left);
			ret = rprim;
		}
	}

	final switch (bin.op) with (ir.BinOp.Op) {
	case Equal, NotEqual, Less, LessEqual, Greater, GreaterEqual:
	case Is, NotIs, In, NotIn:
	case OrOr, AndAnd:
		return buildBool(/*#ref*/bin.loc);
	case AddAssign, SubAssign, MulAssign, DivAssign, ModAssign, PowAssign:
	case LSAssign, SRSAssign, RSAssign:
	case OrAssign, XorAssign, AndAssign:
	case Assign:
		return lprim;
	case Or, Xor, And:
	case Add, Sub, Mul, Div, Mod, Pow:
	case LS, SRS, RS:
		return charToInteger(ret);
	case Cat, CatAssign:
	case None:
		throw panic(bin, "unhandled case");
	}
}

void rewriteCall(Context ctx, ref ir.Exp exp, ir.Function func, ir.Exp[] args, ir.Exp left = null)
{
	auto loc = exp.loc;
	ir.ExpReference eref = buildExpReference(/*#ref*/loc, func, func.name);
	ir.Exp child = eref;
	if (left !is null) {
		child = buildCreateDelegate(/*#ref*/loc, left, eref);
	}
	auto call = buildCall(/*#ref*/loc, child, args);
	exp = call;
	auto tags = new ir.Postfix.TagKind[](args.length);
	foreach (i; 0 .. args.length) {
		tags[i] = ir.Postfix.TagKind.None;
		if (func.type.isArgRef[i]) {
			tags[i] = ir.Postfix.TagKind.Ref;
		} else if (func.type.isArgOut[i]) {
			tags[i] = ir.Postfix.TagKind.Out;
		}
	}
	call.argumentTags = tags;
	extypePostfixCall(ctx, /*#ref*/exp, call);
}

/*!
 * Given the name of an overloaded operator, rewrite it to a function call..
 * extypePostfixCall is called on the rewritten expression.
 * 'left' is an expression of which the function will be a member.
 * Returns the function that was called, or null if nothing was rewritten.
 */
ir.Function rewriteOperator(Context ctx, ref ir.Exp exp, string overloadName,
	ir.Exp left, ir.Exp[] args)
{
	auto loc = exp.loc;
	auto agg = opOverloadableOrNull(getExpType(left));
	if (agg is null) {
		return null;
	}
	auto store = lookupAsThisScope(ctx.lp, agg.myScope, /*#ref*/loc, overloadName,
		ctx.current);
	if (store is null || store.functions.length == 0) {
		throw makeAggregateDoesNotDefineOverload(/*#ref*/exp.loc, agg, overloadName);
	}
	auto func = selectFunction(ctx.lp.target, store.functions, args, /*#ref*/loc);
	rewriteCall(ctx, /*#ref*/exp, func, args, left);
	return func;
}

ir.BinOp.Op maybeInvertCmp(ir.BinOp.Op op, bool invert)
{
	if (!invert) {
		return op;
	}
	switch (op) with (ir.BinOp.Op) {
	case Greater: return Less;
	case GreaterEqual: return LessEqual;
	case Less: return Greater;
	case LessEqual: return GreaterEqual;
	default:
		return op;
	}
}

/*!
 * If the given binop is working on an aggregate
 * that overloads that operator, rewrite a call to that overload.
 */
ir.Type opOverloadRewrite(Context ctx, ir.BinOp binop, ref ir.Exp exp)
{
	auto loc = exp.loc;
	bool neg = binop.op == ir.BinOp.Op.NotEqual;
	string overfn = overloadName(neg ? ir.BinOp.Op.Equal : binop.op);
	if (overfn.length == 0) {
		return null;
	}
	auto func = rewriteOperator(ctx, /*#ref*/exp, overfn, binop.left, [binop.right]);
	auto flipped = false;
	if (func is null) {
		func = rewriteOperator(ctx, /*#ref*/exp, overfn, binop.right, [binop.left]);
		flipped = true;
		if (func is null) {
			return null;
		}
	}

	if (binop.op == ir.BinOp.Op.Greater || binop.op == ir.BinOp.Op.GreaterEqual ||
		binop.op == ir.BinOp.Op.Less || binop.op == ir.BinOp.Op.LessEqual) {
		exp = buildBinOp(/*#ref*/binop.loc, maybeInvertCmp(binop.op, flipped),
			exp, buildConstantInt(/*#ref*/binop.loc, 0));
		return buildBool(/*#ref*/binop.loc);
	}

	if (flipped && (binop.op != ir.BinOp.Op.Equal &&
		binop.op != ir.BinOp.Op.Add && binop.op != ir.BinOp.Op.Mul)) {
		return null;
	}

	if (neg) {
		exp = buildNot(/*#ref*/loc, exp);
		return buildBool(/*#ref*/binop.loc);
	} else {
		return func.type.ret;
	}
}

/*!
 * If this postfix operates on an aggregate with a postfix
 * operator overload, rewrite it.
 */
ir.Type opOverloadRewritePostfix(Context ctx, ir.Postfix pfix, ref ir.Exp exp)
{
	auto name = overloadPostfixName(pfix.op);
	if (pfix.op == ir.Postfix.Op.Slice && pfix.arguments.length == 2) {
		auto func = rewriteOperator(ctx, /*#ref*/exp, name, pfix.child, pfix.arguments);
		if (func is null) {
			return null;
		}
		return func.type.ret;
	}
	if (pfix.op != ir.Postfix.Op.Index || pfix.arguments.length != 1) {
		return null;
	}
	auto func = rewriteOperator(ctx, /*#ref*/exp, name, pfix.child, [pfix.arguments[0]]);
	if (func is null) {
		return null;
	}
	return func.type.ret;
}

/*! If this unary is a Minus, and it's operating on an aggregate
 *  that has opNeg, rewrite it.
 */
ir.Type opOverloadRewriteUnary(Context ctx, ir.Unary unary, ref ir.Exp exp)
{
	if (unary.op != ir.Unary.Op.Minus) {
		return null;
	}
	auto func = rewriteOperator(ctx, /*#ref*/exp, overloadUnaryMinusName(), unary.value, null);
	if (func is null) {
		return null;
	}
	return func.type.ret;
}

ir.Type extypeBinOpPropertyAssign(Context ctx, ir.BinOp binop, ref ir.Exp exp)
{
	if (binop.op != ir.BinOp.Op.Assign) {
		return null;
	}
	auto p = cast(ir.PropertyExp) binop.left;
	if (p is null || p.setFns.length == 0) {
		return null;
	}

	auto args = [binop.right];
	auto func = selectFunction(
		ctx.lp.target, p.setFns, args,
		/*#ref*/binop.loc, DoNotThrow);
	if (func is null) {
		if (p.setFns.length == 0) {
			return null;
		}
		throw makeNoValidFunction(/*#ref*/exp.loc, p.setFns[0].name,
			expsToTypes(args));
	}

	rewriteCall(ctx, /*#ref*/exp, func, args, p.child);

	return func.type.ret;
}

/*!
 * Ensure concatentation is sound.
 */
void extypeCat(Context ctx, ref ir.Exp lexp, ref ir.Exp rexp,
               ir.ArrayType left, ir.Type right)
{
	if (isString(left)) {
		warningStringCat(/*#ref*/lexp.loc, ctx.lp.warningsEnabled);
	}

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

	ir.Type buildDeepArraySmart(ref in Location loc, int depth, ir.Type base)
	{
		ir.ArrayType array = new ir.ArrayType();
		array.loc = loc;
		auto firstArray = array;
		for (size_t i = 1; i < cast(size_t) depth; ++i) {
			array.base = new ir.ArrayType();
			array.base.loc = loc;
			array = cast(ir.ArrayType)array.base;
		}
		array.base = copyTypeSmart(/*#ref*/loc, base);
		return firstArray;
	}

	ir.Class lclass, rclass;
	int ldepth, rdepth;
	getClass(left, /*#ref*/ldepth, /*#ref*/lclass);
	getClass(right, /*#ref*/rdepth, /*#ref*/rclass);
	if (lclass !is null && rclass !is null) {
		auto _class = commonParent(lclass, rclass);
		if (_class !is lclass && _class !is rclass) {
			throw makeBadImplicitCast(lexp, lclass, rclass);
		}
		if (ldepth >= 1 && ldepth == rdepth) {
			auto loc = lexp.loc;
			if (lclass !is _class) {
				lexp = buildCastSmart(buildDeepArraySmart(/*#ref*/loc, ldepth, _class), lexp);
			}
			if (rclass !is _class) {
				rexp = buildCastSmart(buildDeepArraySmart(/*#ref*/loc, rdepth, _class), rexp);
			}
			return;
		} else if (ldepth == 0 || rdepth == 0) {
			if (ldepth == 0 && lclass !is _class) {
				if (!isOrInheritsFrom(lclass, rclass)) {
					throw makeBadImplicitCast(lexp, lclass, rclass);
				}
				lexp = buildCastSmart(_class, lexp);
				return;
			} else if (rdepth == 0 && rclass !is _class) {
				if (!isOrInheritsFrom(rclass, lclass)) {
					throw makeBadImplicitCast(rexp, rclass, lclass);
				}
				rexp = buildCastSmart(_class, rexp);
				return;
			}
		}
	}

	auto rarray = cast(ir.ArrayType) realType(right);
	if (rarray !is null && isImplicitlyConvertable(rarray.base, left.base)) {
		return;
	}

	checkAndDoConvert(ctx, rarray is null ? left.base : left, /*#ref*/rexp);
	rexp = buildCastSmart(rarray is null ? left.base : left, rexp);
}

bool rewriteOpIndexAssign(Context ctx, ir.BinOp binop, ref ir.Exp exp)
{
	if (!isAssign(binop)) {
		return false;
	}
	auto postfix = binop.left.toPostfixChecked();
	if (postfix is null || postfix.op != ir.Postfix.Op.Call ||
		postfix.arguments.length < 1 || postfix.arguments.length > 2) {
		return false;
	}
	auto child = postfix.child.toPostfixChecked();
	if (child is null || child.memberFunction is null) {
		return false;
	}
	auto func = child.memberFunction.decl.toFunctionFast();
	auto eref = child.child.toExpReferenceChecked();
	if (eref is null) {
		return false;
	}
	auto var = eref.decl.toVariableChecked();
	if (var is null) {
		return false;
	}

	auto assignOverload   = overloadPostfixAssignName(func.name);
	if (assignOverload == "") {
		return false;
	}

	ir.Exp rhs;
	switch (binop.op) with (ir.BinOp.Op) {
	case Assign:
		rhs = binop.right;
		break;
	case AddAssign:
		rhs = buildAdd(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case MulAssign:
		rhs = buildMul(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case DivAssign:
		rhs = buildDiv(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case SubAssign:
		rhs = buildSub(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case ModAssign:
		rhs = buildMod(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case AndAssign:
		rhs = buildAnd(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case OrAssign:
		rhs = buildOr(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case XorAssign:
		rhs = buildXor(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case CatAssign:
		rhs = buildCat(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case LSAssign:
		rhs = buildLS(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case SRSAssign:
		rhs = buildSRS(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case RSAssign:
		rhs = buildRS(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	case PowAssign:
		rhs = buildPow(/*#ref*/binop.right.loc, copyExp(postfix), binop.right);
		break;
	default: return false;
	}

	auto newfunc = rewriteOperator(ctx, /*#ref*/exp, assignOverload,
		eref, postfix.arguments ~ rhs);
	if (!typesEqual(func.type.ret, newfunc.type.ret)) {
		throw makeExpected(/*#ref*/newfunc.loc,
			format("\"%s\" to have same return type as \"%s\"",
			newfunc.name, func.name));
	}
	return true;
}

/*!
 * If exp is an AccessExp that is effectively const,
 * or an AccessExp with an effectively const AccessExp
 * ancestor, return true. Otherwise, return false.
 */
bool effectiveConstAccessExp(ir.Exp exp)
{
	auto current = exp.toAccessExpChecked();
	while (current !is null) {
		if (effectivelyConst(getExpType(current.child))) {
			return true;
		}
		current = current.child.toAccessExpChecked();
	}
	return false;
}

/*!
 * Handles logical operators (making a && b result in a bool),
 * binary of storage types, otherwise forwards to assign or primitive
 * specific functions.
 */
ir.Type extypeBinOp(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto binop = cast(ir.BinOp) exp;
	assert(binop !is null);
	bool isAssign = .isAssign(binop.op);

	ir.Type ltype, rtype;
	{
		auto lparentKind = classifyRelationship(binop.left, binop);
		auto lraw = extype(ctx, /*#ref*/binop.left, lparentKind);
		auto rparentKind = classifyRelationship(binop.right, binop);
		auto rraw = extype(ctx, /*#ref*/binop.right, rparentKind);

		ltype = realType(lraw);
		rtype = realType(rraw);
	}

	if (auto ret = extypeBinOpPropertyAssign(ctx, binop, /*#ref*/exp)) {
		return ret;
	}

	// If assign and left is effectively const, throw an error.
	/* Prevent simple assignment modification of const aggregates. Proof-of-concept.
	 * @todo:
	 * Taking the address of an effectively const lvalue should lead to an effectively const pointer.
	 * Same goes for indexing operations etc.
	 * Calling non-const functions. Do we have a concept of that in the IR, or language?
	 */
	if (isAssign && (effectiveConstAccessExp(binop.left) || effectivelyConst(ltype))) {
		throw makeCannotModify(binop, ltype);
	}

	bool hasDeclaration(ir.Exp e)
	{
		return e.nodeType == ir.NodeType.ExpReference || e.nodeType == ir.NodeType.AccessExp;
	}

	if (isAssign && hasDeclaration(binop.left) && hasDeclaration(binop.right)) {
		ir.Variable getVariable(ir.Exp e, ref ir.Declaration child)
		{
			auto eref = e.toExpReferenceChecked();
			if (eref !is null) {
				return eref.decl.toVariableChecked();
			}
			auto aexp = e.toAccessExpChecked();
			if (aexp !is null) {
				if (aexp.child !is null) {
					auto ceref = aexp.child.toExpReferenceChecked();
					if (ceref !is null) {
						child = ceref.decl;
					}
				}
				return aexp.field;
			}
			return null;
		}
		ir.Declaration lchild, rchild;
		auto lvar = getVariable(binop.left, /*#ref*/lchild);
		auto rvar = getVariable(binop.right, /*#ref*/rchild);
		if (lvar !is null && lvar is rvar && lchild is rchild) {
			warningAssignToSelf(/*#ref*/exp.loc, lvar.name, ctx.lp.warningsEnabled);
		}
	}

	if (handleIfNull(ctx, rtype, /*#ref*/binop.left)) {
		ltype = rtype; // Update the type.
	}
	if (handleIfNull(ctx, ltype, /*#ref*/binop.right)) {
		rtype = ltype; // Update the type.
	}

	if (auto ret = opOverloadRewrite(ctx, binop, /*#ref*/exp)) {
		return ret;
	}

	auto lclass = cast(ir.Class)ltype;
	auto rclass = cast(ir.Class)rtype;
	if (lclass !is null && rclass !is null && !typesEqual(lclass, rclass)) {
		auto common = commonParent(lclass, rclass);
		if (lclass !is common) {
			binop.left = buildCastSmart(/*#ref*/exp.loc, common, binop.left);
			rtype = ltype;
		}
		if (rclass !is common) {
			binop.right = buildCastSmart(/*#ref*/exp.loc, common, binop.right);
			rtype = ltype;
		}
	}

	// key in aa => some_vrt_call(aa, key)
	if (binop.op == ir.BinOp.Op.In) {
		auto asAA = cast(ir.AAType) rtype;
		if (asAA is null) {
			throw makeExpected(/*#ref*/binop.right.loc, "associative array");
		}
		checkAndDoConvert(ctx, asAA.key, /*#ref*/binop.left);
		auto loc = binop.loc;
		ir.Exp rtFn, key;
		if (isArray(ltype)) {
			key = buildCast(/*#ref*/loc, buildArrayType(/*#ref*/loc, buildVoid(/*#ref*/loc)), binop.left);
		} else {
			key = buildCast(/*#ref*/loc, buildUlong(/*#ref*/loc), binop.left);
		}
		assert(key !is null);
		exp = buildAAIn(/*#ref*/loc, asAA, [binop.right, binop.left]);
		auto retptr = buildPtrSmart(/*#ref*/loc, asAA.value);
		return retptr;
	}

	// Check for lvalue and touch up aa[key] = 'left'.
	if (isAssign) {
		if (!isAssignable(binop.left)) {
			if (!rewriteOpIndexAssign(ctx, binop, /*#ref*/exp)) {
				throw makeExpected(/*#ref*/binop.left.loc, "lvalue");
			} else {
				return getExpType(exp);
			}
		}

		if (isVoid(getExpType(binop.right))) {
			throw makeAssigningVoid(/*#ref*/binop.right.loc);
		}

		auto asPostfix = cast(ir.Postfix)binop.left;
		if (asPostfix !is null) {
			auto postfixLeft = getExpType(asPostfix.child);
			if (postfixLeft !is null &&
			    postfixLeft.nodeType == ir.NodeType.AAType &&
			    asPostfix.op == ir.Postfix.Op.Index) {
				auto aa = cast(ir.AAType)postfixLeft;

				checkAndDoConvert(ctx, aa.value, /*#ref*/binop.right);
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
		throw makeNoEscapeScope(/*#ref*/exp.loc);
	}

	auto lprim = cast(ir.PrimitiveType)ltype;
	auto rprim = cast(ir.PrimitiveType)rtype;
	if ((lprim !is null && rprim !is null && .isAssign(binop.op)) || binop.op == ir.BinOp.Op.Assign) {
		if (effectivelyConst(ltype)) {
			throw makeCannotModify(binop, ltype);
		}

		auto postfixl = cast(ir.Postfix)binop.left;
		auto postfixr = cast(ir.Postfix)binop.right;
		bool copying = postfixl !is null && postfixl.op == ir.Postfix.Op.Slice;
		tagLiteralType(binop.right, ltype);
		if (copying) {
			if (!typesEqual(ltype, rtype, IgnoreStorage)) {
				throw makeExpectedTypeMatch(/*#ref*/binop.loc, ltype);
			}
		} else {
			checkAndDoConvert(ctx, ltype, /*#ref*/binop.right);
		}

		// Always returns the left type.
		return ltype;
	}

	if (binop.op == ir.BinOp.Op.AndAnd || binop.op == ir.BinOp.Op.OrOr) {
		auto boolType = buildBool(/*#ref*/exp.loc);
		if (!typesEqual(ltype, boolType)) {
			binop.left = buildCastSmart(boolType, binop.left);
		}
		if (!typesEqual(rtype, boolType)) {
			binop.right = buildCastSmart(boolType, binop.right);
		}
		// Always returns bool.
		return boolType;
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
			extypeCat(ctx, /*#ref*/binop.right, /*#ref*/binop.left, rarray, ltype);
		} else {
			extypeCat(ctx, /*#ref*/binop.left, /*#ref*/binop.right, larray, rtype);
		}
		// Returns the array.
		return swapped ? rarray : larray;
	}

	// We only get here if op != Cat && op != CatAssign.
	if ((larray is null && rarray !is null) ||
	    (larray !is null && rarray is null)) {
	    throw makeArrayNonArrayNotCat(/*#ref*/binop.loc);
	}

	if (ltype.nodeType == ir.NodeType.PrimitiveType &&
	    rtype.nodeType == ir.NodeType.PrimitiveType) {
		lprim = cast(ir.PrimitiveType) ltype;
		rprim = cast(ir.PrimitiveType) rtype;
		assert(lprim !is null && rprim !is null);
		return extypeBinOp(ctx, binop, lprim, rprim);
	}

	// Handle 'exp' is 'exp', types must match.
	// This needs to come after the primitive type check,
	// But before the pointer arithmetic check.
	if (binop.op == ir.BinOp.Op.NotIs ||
	    binop.op == ir.BinOp.Op.Is) {
		if (!typesEqual(ltype, rtype)) {
			throw makeError(binop, "types must match for 'is'.");
		}
		// Always returns bool.
		return buildBool(/*#ref*/binop.loc);
	}

	// Handle pointer arithmetics.
	if (ltype.nodeType == ir.NodeType.PointerType) {
		switch (binop.op) with (ir.BinOp.Op) {
		case AddAssign, SubAssign, Add, Sub:
			break;
		case Equal:
			throw makeError(binop, "use 'is' for pointer equality.");
		default:
			throw makeError(binop, "illegal pointer arithmetic.");
		}
		rprim = cast(ir.PrimitiveType) rtype;
		if (rprim is null || !isOkayForPointerArithmetic(rprim.type)) {
			throw makeError(binop, "illegal pointer arithmetic invalid type.");
		}
		// Returns a pointer type.
		return ltype;
	}

	final switch (binop.op) with (ir.BinOp.Op) {
	case Equal, NotEqual, Less, LessEqual, Greater, GreaterEqual:
		if (!willConvert(ltype, rtype, IgnoreConst)) {
			throw makeError(binop, "mismatched types.");
		}
		return buildBool(/*#ref*/binop.loc);
	case Is, NotIs, In, NotIn:
	case Add, Sub, Mul, Div, Mod, Pow:
	case AddAssign, SubAssign, MulAssign, DivAssign, ModAssign, PowAssign:
	case LS, SRS, RS:
	case LSAssign, SRSAssign, RSAssign:
	case OrOr, AndAnd:
	case Or, Xor, And:
	case OrAssign, XorAssign, AndAssign:
	case Cat:
	case CatAssign:
	case Assign:
		throw makeBadBinOp(binop, ltype, rtype);
	case None:
		assert(false);
	}
}

/*
 *
 * extypeIsExp code.
 *
 */

ir.Constant evaluateIsExp(Context ctx, ir.IsExp isExp)
{
	ir.Type type = isExp.type;
	switch (isExp.traitsModifier) {
	case "elementOf":
		if (!isArray(type) && !isStaticArray(type)) {
			return buildConstantBool(/*#ref*/isExp.loc, false);
		}
		if (type.nodeType == ir.NodeType.StaticArrayType) {
			auto arr = type.toStaticArrayTypeFast();
			type = arr.base;
		} else {
			auto arr = type.toArrayTypeFast();
			type = arr.base;
		}
		break;
	case "keyOf":
		if (type.nodeType != ir.NodeType.AAType) {
			return buildConstantBool(/*#ref*/isExp.loc, false);
		}
		auto aa = type.toAATypeFast();
		type = aa.key;
		break;
	case "valueOf":
		if (type.nodeType != ir.NodeType.AAType) {
			return buildConstantBool(/*#ref*/isExp.loc, false);
		}
		auto aa = type.toAATypeFast();
		type = aa.value;
		break;
	case "baseOf":
		if (type.nodeType != ir.NodeType.PointerType) {
			return buildConstantBool(/*#ref*/isExp.loc, false);
		}
		auto ptr = type.toPointerTypeFast();
		type = ptr.base;
		break;
	case "":
		break;
	default:
		throw makeInvalidTraitsModifier(/*#ref*/isExp.loc, isExp.traitsModifier, isExp.traitsModifier);
	}

	if (isExp.compType == ir.IsExp.Comparison.TraitsWord) {
		return evaluateTraitsWord(ctx, isExp, type);
	}
	if (isExp.specialisation != ir.IsExp.Specialisation.Type ||
	    isExp.compType != ir.IsExp.Comparison.Exact ||
	    isExp.specType is null) {
		throw makeNotAvailableInCTFE(isExp, isExp);
	}
	return buildConstantBool(/*#ref*/isExp.loc, typesEqual(type, isExp.specType));
}

ir.Constant evaluateTraitsWord(Context ctx, ir.IsExp isExp, ir.Type type)
{
	/* If you're adding something new here, make sure
	 * you update the documentation and the makeInvalidTraits*
	 * error(s).
	 */

	switch (isExp.traitsWord) {
	case "isBitsType":
		return buildConstantBool(/*#ref*/isExp.loc, isBitsType(type));
	case "isArray":
		return buildConstantBool(/*#ref*/isExp.loc, isArray(type) || isStaticArray(type));
	case "isConst":
		return buildConstantBool(/*#ref*/isExp.loc, type.isConst);
	case "isImmutable":
		return buildConstantBool(/*#ref*/isExp.loc, type.isImmutable);
	case "isScope":
		return buildConstantBool(/*#ref*/isExp.loc, type.isScope);
	default:
		throw makeInvalidTraitsWord(/*#ref*/isExp.loc, isExp.traitsWord);
	}
}

ir.Type extypeIsExp(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto isExp = cast(ir.IsExp) exp;
	assert(isExp !is null);
	assert(isExp.type !is null);

	// We need to remove replace TypeOf, but we need
	// to preserve extra type info like enum.
	resolveType(ctx, /*#ref*/isExp.type);

	if (isExp.specType !is null) {
		resolveType(ctx, /*#ref*/isExp.specType);
	}

	ir.Constant c;
	exp = c = evaluateIsExp(ctx, isExp);
	return c.type;
}


/*
 *
 * Other extype code.
 *
 */

ir.Type extypeTernary(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto ternary = cast(ir.Ternary) exp;
	assert(ternary !is null);

	auto condRaw = extype(ctx, /*#ref*/ternary.condition, Parent.NA);
	auto trueRaw = extype(ctx, /*#ref*/ternary.ifTrue, Parent.NA);
	auto falseRaw = extype(ctx, /*#ref*/ternary.ifFalse, Parent.NA);
	auto condType = realType(condRaw);
	auto trueType = realType(trueRaw);
	auto falseType = realType(falseRaw);

	if (!isBool(condType)) {
		ternary.condition = buildCastToBool(/*#ref*/ternary.condition.loc, ternary.condition);
	}

	ir.Type ret;
	auto aClass = cast(ir.Class) trueType;
	auto bClass = cast(ir.Class) falseType;

	if (aClass !is null && bClass !is null) {
		auto common = commonParent(aClass, bClass);
		checkAndDoConvert(ctx, common, /*#ref*/ternary.ifTrue);
		checkAndDoConvert(ctx, common, /*#ref*/ternary.ifFalse);
		return removeStorageFields(common);
	} else {
		// matchLevel lives in volt.semantic.overload.
		int trueMatchLevel = trueType.nodeType == ir.NodeType.NullType ? 0 : matchLevel(ctx.lp.target, false, trueType, falseType);
		int falseMatchLevel = falseType.nodeType == ir.NodeType.NullType ? 0 : matchLevel(ctx.lp.target, false, falseType, trueType);

		if (trueMatchLevel > falseMatchLevel) {
			assert(trueRaw.nodeType != ir.NodeType.NullType);
			checkAndDoConvert(ctx, trueRaw, /*#ref*/ternary.ifFalse);
			return removeStorageFields(trueRaw);
		} else {
			assert(falseRaw.nodeType != ir.NodeType.NullType);
			checkAndDoConvert(ctx, falseRaw, /*#ref*/ternary.ifTrue);
			return removeStorageFields(falseRaw);
		}
	}
}

ir.Type extypeStructLiteral(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto sl = cast(ir.StructLiteral) exp;
	assert(sl !is null);

	foreach (ref child; sl.exps) {
		extype(ctx, /*#ref*/child, Parent.NA);
	}

	if (sl.type is null) {
		throw makeCannotDeduceStructLiteralType(/*#ref*/sl.loc);
	}

	auto asStruct = cast(ir.Struct) realType(sl.type);
	assert(asStruct !is null);
	ir.Type[] types = getStructFieldTypes(asStruct);

	// @TODO fill out with T.init
	if (types.length != sl.exps.length) {
		throw makeWrongNumberOfArgumentsToStructLiteral(/*#ref*/sl.loc);
	}

	foreach (i, ref sexp; sl.exps) {

		if (ctx.isFunction || isBackendConstant(sexp)) {
			checkAndDoConvert(ctx, types[i], /*#ref*/sexp);
			continue;
		}

		auto n = evaluateOrNull(ctx.lp, ctx.current, sexp);
		if (n is null) {
			throw makeNonConstantStructLiteral(/*#ref*/sexp.loc);
		}

		sexp = n;
		checkAndDoConvert(ctx, types[i], /*#ref*/sexp);
	}

	return sl.type;
}

ir.Type extypeConstant(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto constant = cast(ir.Constant) exp;
	assert(constant !is null);
	assert(constant.type !is null);

	resolveType(ctx, /*#ref*/constant.type);

	if (constant._string == "$" && isIntegral(constant.type)) {
		if (ctx.lastIndexChild is null) {
			throw makeDollarOutsideOfIndex(constant);
		}
		auto loc = constant.loc;
		// Rewrite $ to (arrayName.length).
		exp = buildArrayLength(/*#ref*/loc, ctx.lp.target, copyExp(ctx.lastIndexChild));

		auto func = rewriteOperator(ctx, /*#ref*/exp, overloadDollarName(), copyExp(ctx.lastIndexChild), null);
		if (func !is null) {
			return func.type.ret;
		}

		// The parser sets the wrong type, correct it.
		constant.type = buildSizeT(/*#ref*/constant.loc, ctx.lp.target);
	}

	return constant.type;
}

ir.Type extypeTypeExp(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto te = cast(ir.TypeExp) exp;
	assert(te !is null);
	assert(te.type !is null);

	resolveType(ctx, /*#ref*/te.type);

	return te.type;
}

ir.Type extypeAssocArray(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto aa = cast(ir.AssocArray) exp;

	ir.Type base;
	if (aa.pairs.length > 0) {
		auto first = aa.pairs[0];
		auto firstKey = extype(ctx, /*#ref*/first.key, Parent.NA);
		auto firstValue = extype(ctx, /*#ref*/first.value, Parent.NA);

		base = buildAATypeSmart(/*#ref*/aa.loc, firstKey, firstValue);

		foreach (ref pair; aa.pairs[1 .. $]) {
			extype(ctx, /*#ref*/pair.key, Parent.NA);
			extype(ctx, /*#ref*/pair.value, Parent.NA);
		}
	} else {
		base = aa.type;
	}

	if (base is null) {
		// [:]
		aa.type = buildNullType(/*#ref*/exp.loc);//buildArrayType(exp.loc, buildVoid(exp.loc));
		return aa.type;
	}

	panicAssert(exp, base !is null);
	auto aaType = buildAATypeSmart(/*#ref*/exp.loc,
		(cast(ir.AAType)base).key,
		(cast(ir.AAType)base).value);
	aa.type = aaType;

	return aaType;
}

// Verify va_arg expressions and emit a BuiltinExp for them.
ir.Type extypeVaArgExp(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto vaexp = cast(ir.VaArgExp) exp;

	resolveType(ctx, /*#ref*/vaexp.type);

	auto t = extype(ctx, /*#ref*/vaexp.arg, Parent.NA);

	if (!isLValue(vaexp.arg)) {
		throw makeVaFooMustBeLValue(/*#ref*/vaexp.arg.loc, "va_exp");
	}
	exp = buildVaArg(/*#ref*/vaexp.loc, vaexp);
	if (ctx.currentFunction.type.linkage == ir.Linkage.C) {
		if (vaexp.type.nodeType != ir.NodeType.PrimitiveType &&
				vaexp.type.nodeType != ir.NodeType.PointerType) {
			throw makeCVaArgsOnlyOperateOnSimpleTypes(/*#ref*/vaexp.loc);
		}
		vaexp.arg = buildAddrOf(/*#ref*/vaexp.loc, vaexp.arg);
	} else {
		exp = buildVaArg(/*#ref*/vaexp.loc, vaexp);
	}

	return vaexp.type;
}

ir.Type extypeExpReference(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto eref = cast(ir.ExpReference) exp;
	panicAssert(eref, eref.decl !is null);

	ctx.lp.resolve(ctx.current, eref);

	switch (eref.decl.nodeType) with (ir.NodeType) {
	case Variable:
		auto var = cast(ir.Variable) eref.decl;
		return var.type;
	case Function:
		auto func = cast(ir.Function) eref.decl;
		return func.type;
	case EnumDeclaration:
		auto ed = cast(ir.EnumDeclaration) eref.decl;
		return ed.type;
	case FunctionParam:
		auto fp = cast(ir.FunctionParam) eref.decl;
		return fp.type;
	case FunctionSet:
		auto set = cast(ir.FunctionSet) eref.decl;
		return set.type;
	default:
		throw panicUnhandled(eref, "ExpReference case");
	}
}

ir.Type extypeArrayLiteral(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto al = cast(ir.ArrayLiteral) exp;
	ir.Type base;

	if (al.exps.length > 0) {
		auto types = new ir.Type[](al.exps.length);

		foreach (i, ref e; al.exps) {
			types[i] = extype(ctx, /*#ref*/e, Parent.NA);
		}

		base = getCommonSubtype(/*#ref*/al.loc, types);
	} else {
		throw makeUnsupported(/*#ref*/al.loc, "empty array literals");
	}

	if (al.type !is null) {
		resolveType(ctx, /*#ref*/al.type);
	}

	auto asClass = cast(ir.Class) realType(base);
	if (al.type is null || asClass !is null) {
		al.type = buildArrayTypeSmart(/*#ref*/al.loc, base);
	}

	panicAssert(al, al.type !is null);

	auto at = cast(ir.ArrayType) realType(al.type);
	if (at is null) {
		return al.type;
	}

	foreach (ref e; al.exps) {
		auto c = cast(ir.Constant)e;
		if (c is null) {
			continue;
		}
		auto et = getExpType(e);
		auto prim = cast(ir.PrimitiveType)realType(et);
		if (prim is null) {
			continue;
		}
		if (!typesEqual(et, at.base) && willConvert(ctx, at.base, e)) {
			e = buildCastSmart(/*#ref*/exp.loc, at.base, e);
		}
	}

	return al.type;
}

ir.Type extypeTypeid(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto _typeid = cast(ir.Typeid) exp;

	// Already extype:d this exp?
	if (_typeid.tinfoType !is null) {
		assert(_typeid.exp is null);
		assert(_typeid.tinfoType !is null);
		return _typeid.tinfoType;
	}

	if (_typeid.type !is null) {
		resolveType(ctx, /*#ref*/_typeid.type);
	}
	if (_typeid.exp !is null) {
		_typeid.type = extype(ctx, /*#ref*/_typeid.exp, Parent.NA);

		if ((cast(ir.Aggregate) _typeid.type) !is null) {
			_typeid.type = buildTypeReference(/*#ref*/_typeid.type.loc, _typeid.type);
		} else {
			_typeid.type = copyType(_typeid.type);
		}

		_typeid.exp = null;
	}

	resolveType(ctx, /*#ref*/_typeid.type);

	auto clazz = cast(ir.Class) realType(_typeid.type);
	if (clazz is null) {
		_typeid.tinfoType = ctx.lp.tiTypeInfo;
	} else {
		_typeid.tinfoType = ctx.lp.tiClassInfo;
	}

	return _typeid.tinfoType;
}

ir.Type extypeTokenExp(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto fexp = cast(ir.TokenExp) exp;

	string getFname() {
		string fname = fexp.loc.filename;
		bool windowsCompiler = false;
		version (Windows) {
			windowsCompiler = true;
		}
		if (windowsCompiler ||
			ctx.lp.target.platform == Platform.MSVC ||
		    ctx.lp.target.platform == Platform.MinGW) {
			fname = fname.replace("\\", "/");
		}
		return fname;
	}

	if (fexp.type == ir.TokenExp.Type.File) {
		string fname = getFname();
		ir.Constant c;
		exp = c = buildConstantString(ctx.lp.errSink, /*#ref*/fexp.loc, fname);
		return c.type;
	} else if (fexp.type == ir.TokenExp.Type.Line) {
		ir.Constant c;
		exp = c = buildConstantInt(/*#ref*/fexp.loc, cast(int) fexp.loc.line);
		return c.type;
	} else if (fexp.type == ir.TokenExp.Type.Location) {
		string fname = getFname();
		ir.Constant c;
		auto str = format("%s:%s", fname, toString(cast(int)fexp.loc.line));
		exp = c = buildConstantString(ctx.lp.errSink, /*#ref*/fexp.loc, str);
		return c.type;
	}

	StringSink buf;
	version (Volt) {
		auto pp = new PrettyPrinter("\t", buf.sink);
	} else {
		auto pp = new PrettyPrinter("\t", &buf.sink);
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
		buf.sink(" ");
	}

	foreach_reverse (i, name; names) {
		buf.sink(name);
		if (i > 0) {
			buf.sink(".");
		}
	}

	if (fexp.type == ir.TokenExp.Type.PrettyFunction) {
		buf.sink("(");
		foreach (i, ptype; ctx.currentFunction.type.params) {
			pp.transformType(ptype);
			if (i < ctx.currentFunction.type.params.length - 1) {
				buf.sink(", ");
			}
		}
		buf.sink(")");
	}

	ir.Constant c;
	exp = c = buildConstantString(ctx.lp.errSink, /*#ref*/fexp.loc, buf.toString());
	return c.type;
}

ir.Type extypeStringImport(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto str = cast(ir.StringImport) exp;

	extype(ctx, /*#ref*/str.filename, Parent.NA);

	auto constant = evaluateOrNull(ctx.lp, ctx.current, str.filename);
	if (constant is null || !isString(constant.type) ||
	    constant._string.length < 3) {
		throw makeStringImportWrongConstant(/*#ref*/exp.loc);
	}
	str.filename = constant;

	return constant.type;
}

ir.Type extypeStoreExp(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto se = cast(ir.StoreExp) exp;
	auto t = cast(ir.Type) se.store.node;
	if (t !is null) {
		return t;
	}

	return buildNoType(/*#ref*/exp.loc);
}

ir.Type extypeRunExp(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto runexp = cast(ir.RunExp)exp;
	panicAssert(exp, runexp !is null);
	panicAssert(exp, runexp.child !is null);
	auto type = extype(ctx, /*#ref*/runexp.child, Parent.NA);
	auto pfix = cast(ir.Postfix)runexp.child;
	if (pfix is null || pfix.op != ir.Postfix.Op.Call) {
		throw makeExpectedCall(runexp);
	}
	auto eref = cast(ir.ExpReference)pfix.child;
	if (eref is null) {
		throw makeExpectedCall(runexp);
	}
	auto func = cast(ir.Function)eref.decl;
	if (func is null) {
		throw makeExpectedCall(runexp);
	}
	auto lifter = new CTFELifter(ctx.lp);
	auto liftfn = lifter.lift(func);
	auto liftmod = lifter.completeModule();
	ir.Constant[] args;
	foreach (arg; pfix.arguments) {
		ir.Exp dummy = arg;
		args ~= fold(/*#ref*/dummy, ctx.lp.target);
		if (args[$-1] is null) {
			throw makeNotAvailableInCTFE(arg, arg);
		}
	}
	auto result = ctx.lp.driver.hostCompile(liftmod);
	assert(result !is null);
	auto dgt = result.getFunction(liftfn);
	assert(dgt !is null);
	exp = dgt(args);
	return liftfn.type.ret;
}

//! Check the types of a composable string, error if bad.
ir.Type extypeComposableString(Context ctx, ref ir.Exp exp, Parent parent)
{
	auto cs = cast(ir.ComposableString)exp;
	foreach (ref component; cs.components) {
		ir.Enum _enum;
		auto type = realType(extype(ctx, /*#ref*/component, Parent.NA), false);
		switch (type.nodeType) with (ir.NodeType) {
		case ArrayType:
		case AAType:
		case Union:
		case Struct:
		case Class:
			break;
		case Enum:
			_enum = type.toEnumFast();
			break;
		case PrimitiveType:
			break;
		case PointerType:
			break;
		default:
			throw makeBadComposableType(/*#ref*/component.loc, type);
		}
		if (cs.compileTimeOnly) {
			auto loc = component.loc;
			ir.Constant constant;
			component = constant = evaluateOrNull(ctx.lp, ctx.current, component);
			if (component is null) {
				throw makeNonConstantCompileTimeComposable(/*#ref*/loc);
			}
			constant.fromEnum = _enum;
		}
	}
	return buildString(/*#ref*/exp.loc);
}

/*
 *
 * Shallow functions.
 *
 */

ir.Type extypePropertyExp(Context ctx, ref ir.Exp exp, Parent parent)
{
	// No need to go deeper, assume already extyped.
	auto prop = cast(ir.PropertyExp) exp;

	if (prop.getFn is null) {
		return buildNoType(/*#ref*/prop.loc);
	} else {
		return prop.getFn.type.ret;
	}
}

ir.Type extypeBuiltinExp(Context ctx, ref ir.Exp exp, Parent parent)
{
	// No need to go deeper, assume already extyped.
	auto be = cast(ir.BuiltinExp) exp;
	return be.type;
}

ir.Type extypeAccessExp(Context ctx, ref ir.Exp exp, Parent parent)
{
	// No need to go deeper, assume already extyped.
	auto access = cast(ir.AccessExp) exp;
	return access.field.type;
}

/*
 *
 * Unhandled exps.
 *
 */

ir.Type extypeAssert(Context ctx, ref ir.Exp exp, Parent parent)
{
	throw panicUnhandled(exp, "Assert (exp)");
}

ir.Type extypeStatementExp(Context ctx, ref ir.Exp exp, Parent parent)
{
	throw panicUnhandled(exp, "StatementExp");
}

ir.Type extypeFunctionLiteral(Context ctx, ref ir.Exp exp, Parent parent)
{
	throw panicUnhandled(exp, "FunctionLiteral");
}

ir.Type extypeUnionLiteral(Context ctx, ref ir.Exp exp, Parent parent)
{
	throw panicUnhandled(exp, "UnionLiteral");
}

ir.Type extypeClassLiteral(Context ctx, ref ir.Exp exp, Parent parent)
{
	throw panicUnhandled(exp, "ClassLiteral");
}


/*
 *
 * Dispatch.
 *
 */

version (all) {
	ir.Type extype(Context ctx, ref ir.Exp exp, Parent parent)
	{
		auto r = extypeUnchecked(ctx, /*#ref*/exp, parent);
		auto o = getExpType(exp);
		if (r is null) {
			throw panic(exp, "extype returned null");
		}
		if (o is null) {
			throw panic(exp, "getExtType returned null");
		}
		if (!typesEqual(r, o)) {
			hackTypeWarning(exp, r, o);
			assert(typesEqual(r, o));
			return o;
		}
		return r;
	}
} else {
	alias extype = extypeUnchecked;
}

ir.Type extypeUnchecked(Context ctx, ref ir.Exp exp, Parent parent)
{
	switch (exp.nodeType) with (ir.NodeType) {
	case Constant:
		return extypeConstant(ctx, /*#ref*/exp, parent);
	case BinOp:
		return extypeBinOp(ctx, /*#ref*/exp, parent);
	case Ternary:
		return extypeTernary(ctx, /*#ref*/exp, parent);
	case Unary:
		return extypeUnary(ctx, /*#ref*/exp, parent);
	case Postfix:
		return extypePostfix(ctx, /*#ref*/exp, parent);
	case ArrayLiteral:
		return extypeArrayLiteral(ctx, /*#ref*/exp, parent);
	case AssocArray:
		return extypeAssocArray(ctx, /*#ref*/exp, parent);
	case IdentifierExp:
		return extypeIdentifierExp(ctx, /*#ref*/exp, parent);
	case Assert:
		return extypeAssert(ctx, /*#ref*/exp, parent);
	case StringImport:
		return extypeStringImport(ctx, /*#ref*/exp, parent);
	case Typeid:
		return extypeTypeid(ctx, /*#ref*/exp, parent);
	case IsExp:
		return extypeIsExp(ctx, /*#ref*/exp, parent);
	case FunctionLiteral:
		return extypeFunctionLiteral(ctx, /*#ref*/exp, parent);
	case ExpReference:
		return extypeExpReference(ctx, /*#ref*/exp, parent);
	case StructLiteral:
		return extypeStructLiteral(ctx, /*#ref*/exp, parent);
	case UnionLiteral:
		return extypeUnionLiteral(ctx, /*#ref*/exp, parent);
	case ClassLiteral:
		return extypeClassLiteral(ctx, /*#ref*/exp, parent);
	case TypeExp:
		return extypeTypeExp(ctx, /*#ref*/exp, parent);
	case StoreExp:
		return extypeStoreExp(ctx, /*#ref*/exp, parent);
	case StatementExp:
		return extypeStatementExp(ctx, /*#ref*/exp, parent);
	case TokenExp:
		return extypeTokenExp(ctx, /*#ref*/exp, parent);
	case VaArgExp:
		return extypeVaArgExp(ctx, /*#ref*/exp, parent);
	case PropertyExp:
		return extypePropertyExp(ctx, /*#ref*/exp, parent);
	case BuiltinExp:
		return extypeBuiltinExp(ctx, /*#ref*/exp, parent);
	case AccessExp:
		return extypeAccessExp(ctx, /*#ref*/exp, parent);
	case RunExp:
		return extypeRunExp(ctx, /*#ref*/exp, parent);
	case ComposableString:
		return extypeComposableString(ctx, /*#ref*/exp, parent);
	default:
		assert(false, "unknown exp");
	}
}


/*
 *
 * Statement extype code.
 *
 */

void extypeBlockStatement(Context ctx, ir.BlockStatement bs)
{
	ctx.enter(bs);

	foreach (ref stat; bs.statements) {
		switch (stat.nodeType) with (ir.NodeType) {
		// True form (non-casting)
		case BreakStatement: break;
		case ContinueStatement: break;
		case DoStatement: extypeDoStatement(ctx, /*#ref*/stat); break;
		case IfStatement: extypeIfStatement(ctx, /*#ref*/stat); break;
		case TryStatement: extypeTryStatement(ctx, /*#ref*/stat); break;
		case ForStatement: extypeForStatement(ctx, /*#ref*/stat); break;
		case WithStatement: extypeWithStatement(ctx, /*#ref*/stat); break;
		case GotoStatement: extypeGotoStatement(ctx, /*#ref*/stat); break;
		case ThrowStatement: extypeThrowStatement(ctx, /*#ref*/stat); break;
		case WhileStatement: extypeWhileStatement(ctx, /*#ref*/stat); break;
		case ReturnStatement: extypeReturnStatement(ctx, /*#ref*/stat); break;
		case AssertStatement: extypeAssertStatement(ctx, /*#ref*/stat); break;
		case SwitchStatement: extypeSwitchStatement(ctx, /*#ref*/stat); break;
		case ForeachStatement: extypeForeachStatement(ctx, /*#ref*/stat); break;
		case ConditionStatement: extypeConditionStatement(ctx, /*#ref*/stat); break;
		// False form (casting)
		case BlockStatement:
			auto s = cast(ir.BlockStatement) stat;
			extypeBlockStatement(ctx, s);
			break;
		case ExpStatement:
			auto es = cast(ir.ExpStatement) stat;
			extype(ctx, /*#ref*/es.exp, Parent.NA);
			break;
		case Function:
			auto func = cast(ir.Function) stat;
			actualizeFunction(ctx, func);
			break;
		case Variable:
			auto var = cast(ir.Variable) stat;
			resolveVariable(ctx, var);
			break;
		// Shows up but doesn't need to be visited.
		// Nested structs for functions.
		case Struct:
			auto s = cast(ir.Struct) stat;
			panicAssert(s, s.isActualized);
			break;
		case TemplateInstance:
			throw makeError(/*#ref*/stat.loc, "non top level template function");
		default:
			throw panicUnhandled(stat, ir.nodeToString(stat));
		}
	}

	ctx.leave(bs);
}

/*!
 * Ensure that a thrown type inherits from Throwable.
 */
void extypeThrowStatement(Context ctx, ref ir.Node n)
{
	auto t = cast(ir.ThrowStatement) n;
	auto throwable = ctx.lp.exceptThrowable;
	assert(throwable !is null);

	auto rawType = extype(ctx, /*#ref*/t.exp, Parent.NA);
	auto type = realType(rawType, false);
	auto asClass = cast(ir.Class) type;
	if (asClass is null) {
		throw makeThrowOnlyThrowable(t.exp, type);
	}

	if (!asClass.isOrInheritsFrom(throwable)) {
		throw makeThrowNoInherits(t.exp, asClass);
	}

	if (asClass !is throwable) {
		t.exp = buildCastSmart(/*#ref*/t.exp.loc, throwable, t.exp);
	}
}

void extypeTemplateInstance(Context ctx, ir.TemplateInstance ti)
{
	auto tlifter = new TemplateLifter();
	tlifter.templateLift(ctx.current, ctx.lp, ti);
}

// Moved here for now.
struct ArrayCase
{
	ir.Exp[] originalExps;
	ir.SwitchCase _case;
	ir.IfStatement lastIf;
	size_t lastI;
}

//! Some extypeSwitchStatment utility functions.
//! @{

void addExp(Context ctx, ir.SwitchStatement ss, ir.Exp element, ref ir.Exp exp, ref size_t sz,
            ref uint[] intArrayData, ref ulong[] longArrayData)
{
	auto constant = cast(ir.Constant) element;
	if (constant !is null) {
		if (sz == 0) {
			sz = size(ctx.lp.target, constant.type);
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
	auto cexp = cast(ir.Unary) element;
	if (cexp !is null) {
		assert(cexp.op == ir.Unary.Op.Cast);
		auto tmpsz = size(ctx.lp.target, cexp.type);
		// If there were previous casts, they should be to the same type.
		assert(sz == 0 || tmpsz == sz);
		sz = tmpsz;
		assert(sz == 8);
		addExp(ctx, ss, cexp.value, /*#ref*/exp, /*#ref*/sz, /*#ref*/intArrayData, /*#ref*/longArrayData);
		return;
	}
	auto type = getExpType(exp);
	throw makeSwitchBadType(ss, type);
}

uint getExpHash(Context ctx, ir.SwitchStatement ss, ir.Exp exp)
{
	auto etype = realType(getExpType(exp));
	panicAssert(ss, isArray(etype));
	uint h;
	bool dummy;
	auto constant = cast(ir.Constant) stripEnumIfEnum(/*#ref*/exp, /*#out*/dummy);
	if (constant !is null) {
		assert(isString(etype));
		assert(constant._string[0] == '\"');
		assert(constant._string[$-1] == '\"');
		auto str = constant._string[1..$-1];
		h = hash(cast(ubyte[]) str);
	} else {
		auto alit = cast(ir.ArrayLiteral) exp;
		if (alit is null) {
			throw makeExpected(/*#ref*/exp.loc, "constant or array literal");
		}
		auto atype = cast(ir.ArrayType) etype;
		assert(atype !is null);
		uint[] intArrayData;
		ulong[] longArrayData;
		size_t sz;

		foreach (e; alit.exps) {
			addExp(ctx, ss, e, /*#ref*/exp, /*#ref*/sz, /*#ref*/intArrayData, /*#ref*/longArrayData);
		}
		if (sz == 8) {
			h = hash(cast(ubyte[]) longArrayData);
		} else {
			h = hash(cast(ubyte[]) intArrayData);
		}
	}
	return h;
}

void replaceWithHashIfNeeded(Context ctx, ir.SwitchStatement ss, ir.SwitchCase _case,
                             ref ArrayCase[uint] arrayCases, size_t i,
                             ir.Variable condVar, ref size_t[] toRemove, ref ir.Exp exp)
{
	if (exp is null) {
		return;
	}

	if (!isArray(realType(getExpType(exp)))) {
		return;
	}

	uint h = getExpHash(ctx, ss, exp);

	if (auto p = h in arrayCases) {
		assert(_case.statements.statements.length > 0);
		auto loc = exp.loc;
		ir.BlockStatement elseBlock;
		auto newSwitchBlock = buildBlockStat(/*#ref*/loc, null, _case.statements.myScope.parent);
		if (p.lastIf !is null) {
			elseBlock = buildBlockStat(/*#ref*/loc, null, newSwitchBlock.myScope);
			elseBlock.statements ~= p.lastIf;
		}
		auto cref = buildExpReference(/*#ref*/condVar.loc, condVar, condVar.name);
		auto cmp = buildBinOp(/*#ref*/loc, ir.BinOp.Op.Equal, exp, cref);
		auto ifs = buildIfStat(/*#ref*/loc, cmp, _case.statements, elseBlock);
		_case.statements.myScope.parent = newSwitchBlock.myScope;
		newSwitchBlock.statements ~= ifs;
		newSwitchBlock.statements ~= buildGotoDefault(/*#ref*/exp.loc);
		_case.statements = newSwitchBlock;
		if (p.lastIf !is null) {
			p.lastIf.thenState.myScope.parent = ifs.elseState.myScope;
			if (p.lastIf.elseState !is null) {
				p.lastIf.elseState.myScope.parent = ifs.elseState.myScope;
			}
		}
		p.lastIf = ifs;
		toRemove ~= p.lastI;
		p.lastI = i;
		if (p.originalExps.length > 1) {
			bool[uint] hashes;
			foreach (e; p.originalExps) {
				auto hash = getExpHash(ctx, ss, e);
				auto pp = hash in hashes;
				if (pp is null) {
					hashes[hash] = true;
				}
			}
			exp = null;
			_case.exps = new ir.Exp[](hashes.length);
			foreach (ii, hash; hashes.keys) {
				_case.exps[ii] = buildConstantUint(/*#ref*/loc, hash);
				auto conditionType = realType(extype(ctx, /*#ref*/ss.condition, Parent.NA));
				checkAndDoConvert(ctx, conditionType, /*#ref*/_case.exps[ii]);
			}
			return;
		}
	} else {
		auto loc = exp.loc;
		auto newSwitchBlock = buildBlockStat(/*#ref*/loc, null, _case.statements.myScope.parent);
		auto cref = buildExpReference(/*#ref*/condVar.loc, condVar, condVar.name);
		auto cmp = buildBinOp(/*#ref*/loc, ir.BinOp.Op.Equal, copyExp(exp), cref);
		auto ifs = buildIfStat(/*#ref*/loc, cmp, _case.statements, null);
		_case.statements.myScope.parent = newSwitchBlock.myScope;
		newSwitchBlock.statements ~= ifs;
		newSwitchBlock.statements ~= buildGotoDefault(/*#ref*/exp.loc);
		_case.statements = newSwitchBlock;
		ArrayCase ac = {[exp], _case, ifs, i};
		arrayCases[h] = ac;
	}
	exp = buildConstantUint(/*#ref*/exp.loc, h);
}

//! @}

//! Same as the above function, but handle the multi-case case.
void replaceExpsWithHashIfNeeded(Context ctx, ir.SwitchStatement ss, ir.SwitchCase _case,
                                 ref ArrayCase[uint] arrayCases,
                                 size_t i, ir.Variable condVar, ref ir.Exp[] exps)
{
	auto loc = exps[0].loc;
	panicAssert(ss, exps.length > 1);

	if (!isArray(getExpType(exps[0]))) {
		return;
	}

	ir.Exp[] cmps;
	foreach (e; exps) {
		panicAssert(ss, isArray(getExpType(e)));
		auto cref = buildExpReference(/*#ref*/condVar.loc, condVar, condVar.name);
		cmps ~= buildBinOp(/*#ref*/loc, ir.BinOp.Op.Equal, copyExp(e), cref);
	}
	auto cmp = buildBinOp(/*#ref*/loc, ir.BinOp.Op.OrOr, cmps[0], null);
	auto baseCmp = cmp;
	cmps = cmps[1 .. $];
	while (cmps.length > 0) {
		if (cmps.length > 1) {
			cmp.right = buildBinOp(/*#ref*/loc, ir.BinOp.Op.Or, cmps[0], null);
		} else {
			cmp.right = cmps[0];
		}
		cmp = cast(ir.BinOp)cmp.right;
		cmps = cmps[1 .. $];
	}

	auto newSwitchBlock = buildBlockStat(/*#ref*/loc, null, _case.statements.myScope.parent);
	auto ifs = buildIfStat(/*#ref*/loc, baseCmp, _case.statements, null);
	_case.statements.myScope.parent = newSwitchBlock.myScope;
	newSwitchBlock.statements ~= ifs;
	newSwitchBlock.statements ~= buildGotoDefault(/*#ref*/loc);
	_case.statements = newSwitchBlock;
	auto originalExps = new ir.Exp[](exps.length);
	foreach (ii, ref e; exps) {
		originalExps[ii] = copyExp(e);
	}
	foreach (ref e; exps) {
		auto h = getExpHash(ctx, ss, e);
		e = buildConstantUint(/*#ref*/loc, h);
		ArrayCase ac = {originalExps, _case, ifs, i};
		arrayCases[h] = ac;
	}
}

/*!
 * Ensure that a given switch statement is semantically sound.
 * Errors on bad final switches (doesn't cover all enum members, not on an enum at all),
 * and checks for doubled up cases.
 *
 * oldCondition is the switches condition prior to the extyper being run on it.
 * It's a bit of a hack, but we need the unprocessed enum to evaluate final switches.
 */
void extypeSwitchStatement(Context ctx, ref ir.Node n)
{
	auto ss = cast(ir.SwitchStatement) n;
	auto conditionType = extype(ctx, /*#ref*/ss.condition, Parent.NA);
	auto originalCondition = ss.condition;
	conditionType = realType(conditionType);
	auto originalConditionType = conditionType;

	foreach (ref wexp; ss.withs) {
		extype(ctx, /*#ref*/wexp, Parent.NA);
		if (!isValidWithExp(wexp)) {
			throw makeExpected(wexp, "qualified identifier");
		}
		ctx.pushWith(wexp);
	}

	auto arraySwitch = isArray(conditionType);
	auto stringSwitch = isString(conditionType);
	bool[string] stringCases;
	ir.Exp[] caseArrayCases;

	/* Check that we don't double up on array cases.
	 * The backend handles the integer case, but it
	 * can't see if we've folded them into the same
	 * hash.
	 */
	void caseDoubleUpCheck(ir.Exp exp, ir.SwitchCase _case)
	{
		if (!arraySwitch) {
			return;
		}
		if (stringSwitch) {
			auto constant = exp.toConstantChecked();
			if (constant is null) {
				return;
			}
			auto ptr = constant._string in stringCases;
			if (ptr !is null) {
				throw makeSwitchDuplicateCase(constant);
			}
			stringCases[constant._string] = true;
		} else {
			if (exp.nodeType != ir.NodeType.ArrayLiteral) {
				return;
			}
			extypeArrayLiteral(ctx, /*#ref*/exp, Parent.NA);
			foreach (arrayCase; caseArrayCases) {
				if (areEqualConstantArrays(arrayCase, exp, ctx.lp.target)) {
					throw makeSwitchDuplicateCase(arrayCase);
				}
			}
			caseArrayCases ~= exp;
		}
	}

	foreach (_case; ss.cases) {
		if (_case.firstExp !is null) {
			caseDoubleUpCheck(_case.firstExp, _case);
			extype(ctx, /*#ref*/_case.firstExp, Parent.NA);
		}
		if (_case.secondExp !is null) {
			// Arrays and strings invalid for arrays anyway, no need to double up check.
			extype(ctx, /*#ref*/_case.secondExp, Parent.NA);
		}
		foreach (ref exp; _case.exps) {
			caseDoubleUpCheck(exp, _case);
			extype(ctx, /*#ref*/exp, Parent.NA);
		}
		extypeBlockStatement(ctx, _case.statements);
	}

	ir.Variable condVar;
	if (arraySwitch) {
		auto asArray = cast(ir.ArrayType) conditionType;
		panicAssert(ss, asArray !is null);

		/* If we're switching on array, turn
		 *    switch("hello") {
		 * into
		 *    auto __anon0 = "hello";
		 *    switch(vrt_hash(__anon0)) {
		 * The hash is so we can use the normal switch backend for performance,
		 * and the anonymous variable is so we can refer to the condition if we
		 * have multiple cases matching the same hash.
		 */
		auto loc = ss.loc;
		condVar = buildVariable(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, conditionType),
		                             ir.Variable.Storage.Function,
		                             ctx.current.genAnonIdent(), ss.condition);
		condVar.type.mangledName = mangle(conditionType);
		ss.condVar = condVar;

		/* The only place we can put this variable safely is right before this
		 * SwitchStatement, so scan the parent BlockStatement for it.
		 */
		auto bs = cast(ir.BlockStatement)ctx.current.node;
		panicAssert(ss, bs !is null);
		size_t i;
		for (i = 0; i < bs.statements.length; ++i) {
			if (bs.statements[i] is ss) {
				break;
			}
		}
		panicAssert(ss, i < bs.statements.length);
		bs.statements = bs.statements[0 .. i] ~ condVar ~ bs.statements[i .. $];

		// Turn the condition into vrt_hash(__anon).
		auto condRef = buildExpReference(/*#ref*/loc, condVar, condVar.name);
		ir.Exp ptr = buildCastSmart(buildVoidPtr(/*#ref*/loc), buildArrayPtr(/*#ref*/loc, asArray.base, condRef));
		ir.Exp length = buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul,
			buildArrayLength(/*#ref*/loc, ctx.lp.target, copyExp(ss.condition)),
				getSizeOf(/*#ref*/loc, ctx.lp, asArray.base));
		rewriteCall(ctx, /*#ref*/ss.condition, ctx.lp.hashFunc, [ptr, length]);
		conditionType = buildUint(/*#ref*/ss.condition.loc);
	}
	ArrayCase[uint] arrayCases;
	size_t[] toRemove;  // Indices of cases that have been folded into a collision case.
	ir.SwitchCase[] emptyCases;

	int defaultCount;
	foreach (i, _case; ss.cases) {
		if (_case.isDefault) {
			defaultCount++;
		}
		if (condVar is null) {
			continue;
		}
		if (_case.secondExp !is null) {
			throw makeError(/*#ref*/_case.loc, "non-primitive type for range case.");
		}
		if (_case.statements.statements.length == 0 && !_case.isDefault) {
			emptyCases ~= _case;
			toRemove ~= i;
			continue;
		} else if (emptyCases.length > 0) {
			if (_case.firstExp !is null) {
				_case.exps ~= _case.firstExp;
				_case.firstExp = null;
			}
			foreach (emptyCase; emptyCases) {
				if (emptyCase.firstExp !is null) {
					_case.exps ~= emptyCase.firstExp;
				} else {
					_case.exps ~= emptyCase.exps;
				}
			}
			emptyCases = null;
		}

		if (_case.firstExp !is null) {
			_case.originalFirstExp = _case.firstExp;
			replaceWithHashIfNeeded(ctx, ss, _case, /*#ref*/arrayCases, i, condVar, /*#ref*/toRemove, /*#ref*/_case.firstExp);
		}
		if (_case.secondExp !is null) {
			_case.originalSecondExp = _case.secondExp;
			replaceWithHashIfNeeded(ctx, ss, _case, /*#ref*/arrayCases, i, condVar, /*#ref*/toRemove, /*#ref*/_case.secondExp);
		}
		if (_case.exps.length > 0) {
			_case.originalExps = _case.exps.dup();
			replaceExpsWithHashIfNeeded(ctx, ss, _case, /*#ref*/arrayCases, i, condVar, /*#ref*/_case.exps);
		}
	}

	if (!ss.isFinal && defaultCount == 0) {
		throw makeNoDefaultCase(/*#ref*/ss.loc);
	}
	if (ss.isFinal && defaultCount > 0) {
		throw makeFinalSwitchWithDefault(/*#ref*/ss.loc);
	}
	if (defaultCount > 1) {
		throw makeMultipleDefaults(/*#ref*/ss.loc);
	}

	for (int i = cast(int) toRemove.length - 1; i >= 0; i--) {
		size_t rmi = toRemove[i];
		ss.cases = ss.cases[0 .. rmi] ~ ss.cases[rmi+1 .. $];
	}

	auto asEnum = cast(ir.Enum) conditionType;
	if (asEnum is null && ss.isFinal) {
		asEnum = cast(ir.Enum)realType(getExpType(ss.condition), false);
		if (asEnum is null) {
			throw makeExpected(ss, "enum type for final switch");
		}
	}
	size_t caseCount;
	foreach (_case; ss.cases) {
		/* If we've turned an array into a hash, make sure the original
		 * case matches the original condition.
		 */
		void checkOriginal(ir.Exp imitator, ir.Exp original)
		{
			if (conditionType !is originalConditionType && imitator !is original) {
				if (!willConvert(ctx, originalConditionType, original, IgnoreConst)) {
					auto rtype = getExpType(original);
					throw makeBadImplicitCast(original, rtype, originalConditionType);
				}
			}
		}
	
		if (_case.firstExp !is null) {
			caseCount++;
			checkAndDoConvert(ctx, conditionType, /*#ref*/_case.firstExp);
			checkOriginal(_case.firstExp, _case.originalFirstExp);
		}
		if (_case.secondExp !is null) {
			caseCount++;
			checkAndDoConvert(ctx, conditionType, /*#ref*/_case.secondExp);
			checkOriginal(_case.secondExp, _case.originalSecondExp);
		}
		foreach (i, ref exp; _case.exps) {
			checkAndDoConvert(ctx, conditionType, /*#ref*/exp);
			if (_case.originalExps !is null) {
				checkOriginal(exp, _case.originalExps[i]);
			}
		}
		caseCount += _case.exps.length;
	}

	if (ss.isFinal && caseCount != asEnum.members.length) {
		throw makeFinalSwitchBadCoverage(ss);
	}

	replaceGotoCase(ctx, ss, arraySwitch);

	foreach_reverse(wexp; ss.withs) {
		ctx.popWith(wexp);
	}
}

void extypeConditionStatement(Context ctx, ref ir.Node n)
{
	auto cs = n.toConditionStatementFast();
	extype(ctx, /*#ref*/cs.condition.exp, Parent.NA);

	auto constant = evaluate(ctx.lp, ctx.current, cs.condition.exp);
	if (constant is null || !isBool(getExpType(constant))) {
		throw makeExpected(/*#ref*/n.loc, "constant expression that evaluates to a bool");
	}

	if (constant.u._bool) {
		extypeBlockStatement(ctx, cs.block);
		n = cs.block;
	} else if (cs._else !is null) {
		extypeBlockStatement(ctx, cs._else);
		n = cs._else;
	} else {
		n = buildBlockStat(/*#ref*/n.loc, n, ctx.current);
	}
}

/*!
 * Merge with below function.
 */
void extypeForeachStatement(Context ctx, ref ir.Node n)
{
	auto fes = cast(ir.ForeachStatement) n;

	if (fes.beginIntegerRange !is null) {
		assert(fes.endIntegerRange !is null);
		extype(ctx, /*#ref*/fes.beginIntegerRange, Parent.NA);
		extype(ctx, /*#ref*/fes.endIntegerRange, Parent.NA);
	}

	ctx.enter(fes.block);

	processForeach(ctx, fes);

	foreach (ivar; fes.itervars) {
		resolveVariable(ctx, ivar);
	}

	if (fes.aggregate !is null) {
		auto aggType = realType(getExpType(fes.aggregate));
		if (fes.itervars.length == 2 &&
			(aggType.nodeType == ir.NodeType.StaticArrayType ||
			aggType.nodeType == ir.NodeType.ArrayType)) {
			auto keysz = size(ctx.lp.target, fes.itervars[0].type);
			auto sizetsz = size(ctx.lp.target, buildSizeT(/*#ref*/fes.loc, ctx.lp.target));
			if (keysz < sizetsz) {
				throw makeIndexVarTooSmall(/*#ref*/fes.loc, fes.itervars[0].name);
			}
		}
	}

	// fes.aggregate is visited by extypeForeach
	ctx.leave(fes.block);

	extypeBlockStatement(ctx, fes.block);
}

/*!
 * Process the types and expressions on a foreach.
 * Foreaches become for loops before the backend sees them,
 * but they still need to be made valid by the extyper.
 */
void processForeach(Context ctx, ir.ForeachStatement fes)
{
	if (fes.itervars.length == 0) {
		if (fes.beginIntegerRange is null || fes.endIntegerRange is null) {
			throw makeExpected(/*#ref*/fes.loc, "variable");
		}
		fes.itervars ~= buildVariable(/*#ref*/fes.loc, buildAutoType(/*#ref*/fes.loc),
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
		fes.itervars[i].type = copyTypeSmart(/*#ref*/fes.itervars[i].loc, t);
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
		auto a = cast(ir.PrimitiveType) getExpType(fes.beginIntegerRange);
		auto b = cast(ir.PrimitiveType) getExpType(fes.endIntegerRange);
		if (a is null || b is null) {
			throw makeExpected(/*#ref*/fes.beginIntegerRange.loc, "primitive types");
		}
		if (!typesEqual(a, b)) {
			auto asz = size(ctx.lp.target, a);
			auto bsz = size(ctx.lp.target, b);
			if (bsz > asz) {
				checkAndDoConvert(ctx, b, /*#ref*/fes.beginIntegerRange);
				fillBlankVariable(0, b);
			} else if (asz > bsz) {
				checkAndDoConvert(ctx, a, /*#ref*/fes.endIntegerRange);
				fillBlankVariable(0, a);
			} else {
				auto ac = evaluateOrNull(ctx.lp, ctx.current, fes.beginIntegerRange);
				auto bc = evaluateOrNull(ctx.lp, ctx.current, fes.endIntegerRange);
				if (ac !is null) {
					checkAndDoConvert(ctx, b, /*#ref*/fes.beginIntegerRange);
					fillBlankVariable(0, b);
				} else if (bc !is null) {
					checkAndDoConvert(ctx, a, /*#ref*/fes.endIntegerRange);
					fillBlankVariable(0, a);
				}
			}
		}
		fillBlankVariable(0, a);
		return;
	}

	extype(ctx, /*#ref*/fes.aggregate, Parent.NA);

	auto aggType = realType(getExpType(fes.aggregate));

	if (!isString(aggType)) foreach (i, ivar; fes.itervars) {
		if (!isBlankVariable(i)) {
			throw makeDoNotSpecifyForeachType(/*#ref*/fes.itervars[i].loc, fes.itervars[i].name);
		}
	} else  {
		if (fes.itervars.length != 1 && fes.itervars.length != 2) {
			throw makeExpected(/*#ref*/fes.loc, "one or two iteration variables");
		}
		size_t charIndex = fes.itervars.length == 2 ? 1 : 0;
		foreach (i, ivar; fes.itervars) {// isString(aggType)
			if (i == charIndex && !isChar(fes.itervars[i].type)) {
				throw makeExpected(/*#ref*/fes.itervars[i].loc, "index variable of type 'char', 'wchar', or 'dchar' for string foreach");
			} else if (i != charIndex && !isBlankVariable(i)) {
				throw makeDoNotSpecifyForeachType(/*#ref*/fes.itervars[i].loc, fes.itervars[i].name);
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
				throw panic(/*#ref*/fes.loc, "only char to dchar foreach decoding is currently supported.");
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
		value = copyTypeSmart(/*#ref*/fes.aggregate.loc, asArray.base);
		key = buildSizeT(/*#ref*/fes.loc, ctx.lp.target);
		break;
	case ir.NodeType.StaticArrayType:
		auto asArray = cast(ir.StaticArrayType) aggType;
		value = copyTypeSmart(/*#ref*/fes.aggregate.loc, asArray.base);
		key = buildSizeT(/*#ref*/fes.loc, ctx.lp.target);
		break;
	case ir.NodeType.AAType:
		auto asArray = cast(ir.AAType) aggType;
		value = copyTypeSmart(/*#ref*/fes.aggregate.loc, asArray.value);
		key = copyTypeSmart(/*#ref*/fes.aggregate.loc, asArray.key);
		break;
	default:
		throw makeExpected(/*#ref*/fes.aggregate.loc, "array, static array, or associative array.");
	}


	if (fes.itervars.length == 2) {
		fillBlankVariable(0, key);
		fillBlankVariable(1, value);
	} else if (fes.itervars.length == 1) {
		fillBlankVariable(0, value);
	} else {
		throw makeExpected(/*#ref*/fes.loc, "one or two variables after foreach");
	}
}

void extypeWithStatement(Context ctx, ref ir.Node n)
{
	auto ws = cast(ir.WithStatement) n;

	extype(ctx, /*#ref*/ws.exp, Parent.NA);

	if (!isValidWithExp(ws.exp)) {
		throw makeExpected(ws.exp, "qualified identifier");
	}

	ctx.pushWith(ws.exp);
	extypeBlockStatement(ctx, ws.block);
	ctx.popWith(ws.exp);
}

void extypeReturnStatement(Context ctx, ref ir.Node n)
{
	auto ret = cast(ir.ReturnStatement) n;

	auto func = getParentFunction(ctx.current);
	if (func is null) {
		throw panic(ret, "return statement outside of function.");
	}

	if (ret.exp !is null) {
		extype(ctx, /*#ref*/ret.exp, Parent.NA);
		auto retType = getExpType(ret.exp);
		if (func.isAutoReturn) {
			func.type.ret = copyTypeSmart(/*#ref*/retType.loc, getExpType(ret.exp));
			if (cast(ir.NullType)func.type.ret !is null) {
				func.type.ret = buildVoidPtr(/*#ref*/ret.loc);
			}
		}
		if (retType.isScope && mutableIndirection(retType)) {
			throw makeNoReturnScope(/*#ref*/ret.loc);
		}
		checkAndDoConvert(ctx, func.type.ret, /*#ref*/ret.exp);
	} else if (!isVoid(realType(func.type.ret))) {
		// No return expression on function returning a value.
		throw makeReturnValueExpected(/*#ref*/ret.loc, func.type.ret);
	}
}

void extypeIfStatement(Context ctx, ref ir.Node n)
{
	auto ifs = cast(ir.IfStatement) n;
	auto loc = ifs.loc;
	if (ifs.exp !is null) {
		extype(ctx, /*#ref*/ifs.exp, Parent.NA);
		if (isAssign(ifs.exp)) {
			warningAssignInCondition(/*#ref*/ifs.exp.loc, ctx.lp.warningsEnabled);
		}
	}

	if (ifs.autoName.length > 0) {
		assert(ifs.exp !is null);
		assert(ifs.thenState !is null);

		auto t = getExpType(ifs.exp);
		auto var = buildVariable(/*#ref*/loc,
				copyTypeSmart(/*#ref*/loc, t),
				ir.Variable.Storage.Function,
				ifs.autoName);

		// Resolve the variable making it propper and usable.
		resolveVariable(ctx, var);

		// A hack to work around exp getting resolved twice.
		var.assign = ifs.exp;

		auto eref = buildExpReference(/*#ref*/loc, var);
		ir.Node[] vars = [cast(ir.Node)var];
		ifs.exp = buildStatementExp(/*#ref*/loc, vars, eref);

		// Add it to its proper scope.
		ir.Status status;
		ifs.thenState.myScope.addValue(var, var.name, /*#out*/status);
		if (status != ir.Status.Success) {
			throw panic(/*#ref*/loc, "value redefinition");
		}
	}

	// Need to do this after any autoName rewriting.
	if (ifs.exp !is null) {
		implicitlyCastToBool(ctx, /*#ref*/ifs.exp);
	}

	if (ifs.thenState !is null) {
		extypeBlockStatement(ctx, ifs.thenState);
	}

	if (ifs.elseState !is null) {
		extypeBlockStatement(ctx, ifs.elseState);
	}
}

void extypeForStatement(Context ctx, ref ir.Node n)
{
	auto fs = cast(ir.ForStatement) n;

	ctx.enter(fs.block);

	foreach (ivar; fs.initVars) {
		resolveVariable(ctx, ivar);
	}
	foreach (ref i; fs.initExps) {
		extype(ctx, /*#ref*/i, Parent.NA);
	}

	if (fs.test !is null) {
		extype(ctx, /*#ref*/fs.test, Parent.NA);
		if (isAssign(fs.test)) {
			warningAssignInCondition(/*#ref*/fs.test.loc, ctx.lp.warningsEnabled);
		}
		implicitlyCastToBool(ctx, /*#ref*/fs.test);
	}
	foreach (ref increment; fs.increments) {
		extype(ctx, /*#ref*/increment, Parent.NA);
	}

	ctx.leave(fs.block);

	extypeBlockStatement(ctx, fs.block);
}

void extypeWhileStatement(Context ctx, ref ir.Node n)
{
	auto ws = cast(ir.WhileStatement) n;

	if (ws.condition !is null) {
		extype(ctx, /*#ref*/ws.condition, Parent.NA);
		if (isAssign(ws.condition)) {
			warningAssignInCondition(/*#ref*/ws.condition.loc, ctx.lp.warningsEnabled);
		}
		implicitlyCastToBool(ctx, /*#ref*/ws.condition);
	}

	extypeBlockStatement(ctx, ws.block);
}

void extypeDoStatement(Context ctx, ref ir.Node n)
{
	auto ds = cast(ir.DoStatement) n;

	extypeBlockStatement(ctx, ds.block);

	if (ds.condition !is null) {
		extype(ctx, /*#ref*/ds.condition, Parent.NA);
		if (isAssign(ds.condition)) {
			warningAssignInCondition(/*#ref*/ds.condition.loc, ctx.lp.warningsEnabled);
		}
		implicitlyCastToBool(ctx, /*#ref*/ds.condition);
	}
}

void extypeAssertStatement(Context ctx, ref ir.Node n)
{
	auto as = cast(ir.AssertStatement) n;

	extype(ctx, /*#ref*/as.condition, Parent.NA);

	if (as.message !is null) {
		extype(ctx, /*#ref*/as.message, Parent.NA);
	}

	if (!as.isStatic) {
		return;
	}

	if (as.message !is null) {
		as.message = evaluate(ctx.lp, ctx.current, as.message);
	}

	as.condition = evaluate(ctx.lp, ctx.current, as.condition);
	auto cond = cast(ir.Constant) as.condition;
	ir.Constant msg;
	if (as.message !is null) {
		msg = cast(ir.Constant) as.message;
	} else {
		msg = buildConstantStringNoEscape(/*#ref*/as.loc, "");
	}
	if ((cond is null || msg is null) || (!isBool(cond.type) || !isString(msg.type))) {
		throw panicUnhandled(as, "non simple static asserts (bool and string literal only).");
	}
	if (!cond.u._bool) {
		throw makeStaticAssert(as, msg._string);
	}
}

void extypeTryStatement(Context ctx, ref ir.Node n)
{
	auto t = cast(ir.TryStatement) n;

	extypeBlockStatement(ctx, t.tryBlock);

	foreach (i, v; t.catchVars) {
		extypeBlockStatement(ctx, t.catchBlocks[i]);
	}

	if (t.finallyBlock !is null) {
		extypeBlockStatement(ctx, t.finallyBlock);
	}
}

void extypeGotoStatement(Context ctx, ref ir.Node n)
{
	auto gs = cast(ir.GotoStatement) n;

	if (gs.exp !is null) {
		extype(ctx, /*#ref*/gs.exp, Parent.NA);
	}
}

/*
 *
 * Actualize functions.
 *
 */

void actualizeFunction(Context ctx, ir.Function func)
{
	if (func.isActualized) {
		return;
	}

	// Ensured that function is resolved
	resolveFunction(ctx, func);

	auto done = ctx.lp.startActualizing(func);
	scope (success) {
		done();
	}

	// Error checking
	if (ctx.functionDepth >= 2) {
		throw makeNestedNested(/*#ref*/func.loc);
	} else if (ctx.functionDepth == 1) {
		nestExtyperFunction(ctx.parentFunction, func);
	}

	// Visiting children.
	ctx.enter(func);

	{
		lazyParseBlock(ctx, func.myScope, /*#ref*/func.tokensIn, /*#ref*/func.parsedIn);
		lazyParseBlock(ctx, func.myScope, /*#ref*/func.tokensOut, /*#ref*/func.parsedOut);
		lazyParseBlock(ctx, func.myScope, /*#ref*/func.tokensBody, /*#ref*/func.parsedBody);

		if (func.tokensIn !is null || func.tokensOut !is null || func.tokensBody !is null) {
			ctx.lp.postParse.transformChildBlocks(func);
		}

		if (func.templateType !is null && func.templateName !is null) {
			/* If the function is in a template named S (say), make sure S resolves to the instantiated
			 * (e.g. S!i32) and not the raw template instance.
			 */
			ir.Status status;
			if (func.parsedBody !is null) func.parsedBody.myScope.addType(func.templateType, func.templateName, /*#out*/status);
			if (func.parsedOut !is null) func.parsedOut.myScope.addType(func.templateType, func.templateName, /*#out*/status);
			if (func.parsedIn !is null) func.parsedIn.myScope.addType(func.templateType, func.templateName, /*#out*/status);
		}
	}

	addVarArgsVarsIfNeeded(ctx.lp, func);

	if (func.outParameter.length > 0) {
		assert(func.parsedOut !is null);
		auto loc = func.parsedOut.loc;
		auto var = buildVariableSmart(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, func.type.ret), ir.Variable.Storage.Function, func.outParameter);
		func.parsedOut.statements = var ~ func.parsedOut.statements;
		ir.Status status;
		func.parsedOut.myScope.addValue(var, var.name, /*#out*/status);
		if (status != ir.Status.Success) {
			throw panic(/*#ref*/loc, "value redefinition");
		}
	}

	if (func.hasInContract) {
		extypeBlockStatement(ctx, func.parsedIn);
	}

	if (func.hasOutContract) {
		extypeBlockStatement(ctx, func.parsedOut);
	}

	if (func.hasBody) {
		extypeBlockStatement(ctx, func.parsedBody);
	}

	assert(func !is null);

	ctx.leave(func);

	func.isActualized = true;
}


/*
 *
 * Resolver functions.
 *
 */

/*
 * These function do the actual resolving of various types
 * and constructs in the Volt Langauge. They should only be
 * used by the LanguagePass, and as such is not intended for
 * use of other code, that could should call the resolve
 * functions on the language pass instead.
 */

/*!
 * Helper function to call into the ExTyper version.
 */
ir.Type resolveType(LanguagePass lp, ir.Scope current, ref ir.Type type)
{
	auto extyper = new ExTyper(lp);
	auto ctx = new Context(lp, extyper);
	ctx.setupFromScope(current);
	doResolveType(ctx, /*#ref*/type, null, 0);
	return resolveType(ctx, /*#ref*/type);
}

/*!
 * Flattens storage types, ensure that there are no unresolved TypeRefences in
 * the given type and in general ensures that the type is ready to be consumed.
 *
 * Stops when encountering the first resolved TypeReference.
 */
ir.Type resolveType(Context ctx, ref ir.Type type)
{
	doResolveType(ctx, /*#ref*/type, null, 0);
	return type;
}

void doResolveType(Context ctx, ref ir.Type type,
                   ir.CallableType ct, size_t ctIndex)
{
	switch (type.nodeType) with (ir.NodeType) {
	case NoType:
	case NullType:
	case PrimitiveType:
		return; // Nothing to do.
	case PointerType:
		auto pt = cast(ir.PointerType)type;
		doResolveType(ctx, /*#ref*/pt.base, null, 0);
		propagateStorage(pt);
		return;
	case ArrayType:
		auto at = cast(ir.ArrayType)type;
		doResolveType(ctx, /*#ref*/at.base, null, 0);
		propagateStorage(at);
		return;
	case AmbiguousArrayType:
		return doResolveAmbiguousArrayType(ctx, /*#ref*/type);
	case StaticArrayType:
		auto sat = cast(ir.StaticArrayType)type;
		doResolveType(ctx, /*#ref*/sat.base, null, 0);
		propagateStorage(sat);
		return;
	case AAType:
		doResolveAA(ctx, /*#ref*/type);
		propagateStorage(type);
		return;
	case StorageType:
		auto st = cast(ir.StorageType)type;
		// For auto and friends.
		if (st.base is null) {
			st.base = buildAutoType(/*#ref*/type.loc);
		}
		flattenOneStorage(st, st.base, ct, ctIndex);
		type = st.base;
		doResolveType(ctx, /*#ref*/type, ct, ctIndex);
		return;
	case AutoType:
		auto at = cast(ir.AutoType)type;
		if (at.explicitType is null) {
			return;
		}
		type = at.explicitType;
		return doResolveType(ctx, /*#ref*/type, null, 0);
	case FunctionType:
		auto ft = cast(ir.FunctionType)type;
		foreach (i, ref p; ft.params) {
			doResolveType(ctx, /*#ref*/p, ft, i);
		}
		return doResolveType(ctx, /*#ref*/ft.ret, ft, 0);
	case DelegateType:
		auto dt = cast(ir.DelegateType)type;
		foreach (i, ref p; dt.params) {
			doResolveType(ctx, /*#ref*/p, dt, i);
		}
		return doResolveType(ctx, /*#ref*/dt.ret, dt, 0);
	case TypeReference:
		auto tr = cast(ir.TypeReference)type;

		if (tr.type is null) {
			auto store = lookup(ctx.lp, ctx.current, tr.id);
			if (store !is null && store.kind == ir.Store.Kind.TemplateInstance) {
				foreach (ti; store.templateInstances) {
					extypeTemplateInstance(ctx, ti);
				}
				tr.type = lookupType(ctx.lp, ctx.current, tr.id);
			} else {
				tr.type = lookupType(ctx.lp, ctx.current, tr.id, store);
			}
		}
		assert(tr.type !is null);

		if (type.glossedName is null) {
			type.glossedName = tr.id.toString();
		}

		if (auto n = cast(ir.Named) tr.type) {
			return;
		}

		// Assume tr.type is resolved.
		type = copyTypeSmart(/*#ref*/tr.loc, tr.type);
		type.glossedName = tr.glossedName;
		addStorage(type, tr);
		return;
	case TypeOf:
		auto to = cast(ir.TypeOf) type;
		type = extype(ctx, /*#ref*/to.exp, Parent.NA);
		if (type.nodeType == ir.NodeType.NoType) {
			throw makeError(to.exp, "expression has no type.");
		}
		type = copyTypeSmart(/*#ref*/to.loc, type);
		return;
	case Enum:
	case Class:
	case Struct:
	case Union:
	case Interface:
		throw panic(type, "didn't not expect direct reference to Named type");
	default:
		throw panicUnhandled(type, ir.nodeToString(type));
	}
}

void doResolveAmbiguousArrayType(Context ctx, ref ir.Type type)
{
	auto aat = cast(ir.AmbiguousArrayType)type;
	doResolveType(ctx, /*#ref*/aat.base, null, 0);

	auto iexp = aat.child.toIdentifierExpChecked();
	string childName;
	if (iexp !is null) {
		childName = iexp.value;
	}
	auto childType = extype(ctx, /*#ref*/aat.child, Parent.NA);
	auto constant = fold(/*#ref*/aat.child, ctx.lp.target);
	if (constant is null && aat.child.nodeType == ir.NodeType.ExpReference) {
		auto eref = cast(ir.ExpReference)aat.child;
		if (eref.decl.nodeType == ir.NodeType.EnumDeclaration) {
			auto ed = cast(ir.EnumDeclaration)eref.decl;
			constant = fold(/*#ref*/ed.assign, ctx.lp.target);
		}
	}

	if (constant !is null && isIntegral(constant.type)) {
		auto sat = cast(ir.StaticArrayType)buildStaticArrayTypeSmart(/*#ref*/type.loc, cast(size_t)constant.u._ulong, aat.base);
		sat.base.glossedName = aat.base.glossedName;
		type = sat;
		return doResolveType(ctx, /*#ref*/sat.base, null, 0);
	}
	if (aat.child.nodeType == ir.NodeType.TypeExp || aat.child.nodeType == ir.NodeType.StoreExp) {
		auto aa = cast(ir.AAType)buildAATypeSmart(/*#ref*/type.loc, childType, aat.base);
		aa.value.glossedName = aat.base.glossedName;
		aa.key.glossedName = childName;
		type = aa;
		return doResolveAA(ctx, /*#ref*/type);
	}
	throw makeExpected(/*#ref*/type.loc, "type or expression after array base");
}

void doResolveAA(Context ctx, ref ir.Type type)
{
	auto at = cast(ir.AAType) type;

	doResolveType(ctx, /*#ref*/at.key, null, 0);
	doResolveType(ctx, /*#ref*/at.value, null, 0);

	auto base = at.key;

	auto tr = cast(ir.TypeReference)base;
	if (tr !is null) {
		base = tr.type;
	}

	if (base.nodeType == ir.NodeType.Class) {
		throw makeClassAsAAKey(/*#ref*/at.loc);
	}

	if (base.nodeType == ir.NodeType.Struct) {
		if (mutableIndirection(base)) {
			throw makeMutableStructAAKey(/*#ref*/at.loc);
		}
		return;
	}

	bool needsConstness;
	if (base.nodeType == ir.NodeType.ArrayType) {
		base = (cast(ir.ArrayType)base).base;
		needsConstness = true;
	} else if (base.nodeType == ir.NodeType.StaticArrayType) {
		base = (cast(ir.StaticArrayType)base).base;
		needsConstness = true;
	}

	auto prim = cast(ir.PrimitiveType)realType(base);
	if (prim !is null &&
	    (!needsConstness || (prim.isConst || prim.isImmutable))) {
		return;
	}

	throw makeInvalidAAKey(at);
}

/*!
 * Resolves an alias, either setting the myalias field
 * or turning it into a type.
 */
void resolveAlias(LanguagePass lp, ir.Alias a)
{
	auto s = a.store;
	scope (success) {
		a.isResolved = true;
	}

	if (a.type !is null) {
		assert(a.lookModule is null);
		resolveType(lp, a.lookScope, /*#ref*/a.type);
		return s.markAliasResolved(a.type);
	}

	ir.Store ret;
	if (a.lookModule is null) {
		if (a.staticIf !is null) {
			ir.Type foundType;
			foreach (i, condition; a.staticIf.conditions) {
				auto constant = evaluate(lp, a.lookScope, condition);
				if (constant is null || !isBool(getExpType(constant))) {
					assert(constant !is null);
					throw makeExpected(/*#ref*/condition.loc, "constant expression that evaluates to a bool");
				}
				if (constant.u._bool) {
					foundType = a.staticIf.types[i];
					break;
				}
			}
			if (foundType is null &&
				a.staticIf.types.length > a.staticIf.conditions.length) {
				foundType = a.staticIf.types[$-1];
			}
			if (foundType !is null) {
				a.type = foundType;
				resolveType(lp, a.lookScope, /*#ref*/a.type);
				return s.markAliasResolved(a.type);
			}
			throw makeError(/*#ref*/a.staticIf.loc, "no valid condition for alias static if.");
		} else {
			// Normal alias.
			ret = lookup(lp, a.lookScope, a.id);
		}
	} else {
		// Import alias.
		assert(a.lookScope is null);
		assert(a.lookModule.myScope !is null);
		assert(a.id.identifiers.length == 1);
		auto look = a.lookModule.myScope;
		auto ident =  a.id.identifiers[0].value;
		ret = lookupAsImportScope(lp, look, /*#ref*/a.loc, ident);
		if (ret !is null) {
			ret.importAlias = true;
		}
	}

	if (ret is null) {
		throw makeFailedLookup(a, a.id.toString());
	}

	s.markAliasResolved(ret);
}

/*!
 * Will make sure that the Enum's type is set, and
 * as such will resolve the first member since it
 * decides the type of the rest of the enum.
 */
void resolveEnum(LanguagePass lp, ir.Enum e)
{
	e.isResolved = true;

	resolveType(lp, e.myScope, /*#ref*/e.base);

	// Do some extra error checking on out.
	scope (success) {
		if (!isIntegral(e.base)) {
			checkNonIntegralEnum(lp, e);
		}
	}

	// If the base type isn't auto then we are done here.
	if (!isAuto(e.base)) {
		return;
	}

	// Need to resolve the first member to set the type of the Enum.
	auto first = e.members[0];
	lp.resolve(e.myScope, first);

	assert(first !is null && first.assign !is null);
	auto type = getExpType(first.assign);
	e.base = realType(copyTypeSmart(/*#ref*/e.loc, type));
}

/*!
 * Check that a non integral enum is valid.
 *
 * A non integral enum is an enum with a base that is
 * not integral. It is only valid if:
 *   - Every member of the enum has an explicit assign set.
 * If that condition is not met, this function
 * will generate an error.
 */
void checkNonIntegralEnum(LanguagePass lp, ir.Enum e)
{
	panicAssert(e, !isIntegral(e.base));

	foreach (member; e.members) {
		if (member.assign is null) {
			throw makeNonIntegralEnumNullAssign(/*#ref*/member.loc);
		}
	}
}

/*!
 * Resolves a Variable.
 */
void resolveVariable(Context ctx, ir.Variable v)
{
	/* We may have been called out-of-band, which clears this flag.
	 * Always set it so we can detect out-of-order declarations.
	 */
	v.hasBeenDeclared = true;

	if (v.isResolved) {
		return;
	}

	auto done = ctx.lp.startResolving(v);
	ctx.isVarAssign = true;
	scope (success) {
		ctx.isVarAssign = false;
		done();
	}

	// Fix up type as best as possible.
	resolveType(ctx, /*#ref*/v.type);

	bool inAggregate = (cast(ir.Aggregate) ctx.current.node) !is null;
	if (inAggregate && v.assign !is null &&
	    ctx.current.node.nodeType != ir.NodeType.Class &&
            (v.storage != ir.Variable.Storage.Global &&
             v.storage != ir.Variable.Storage.Local)) {
		throw makeAssignToNonStaticField(v);
	}
	bool inNestedStruct;
	auto func = ctx.currentFunction;
	if (func !is null) {
		inNestedStruct = func.nestStruct is ctx.current.node;
	}

	if (inAggregate && !inNestedStruct &&
		(v.type.isConst || v.type.isImmutable) &&
		(v.storage != ir.Variable.Storage.Global &&
		 v.storage != ir.Variable.Storage.Local)) {
		throw makeConstField(v);
	}

	if (v.assign !is null) {
		if (!isAuto(v.type)) {
			tagLiteralType(v.assign, v.type);
		}

		auto rtype = extype(ctx, /*#ref*/v.assign, Parent.NA);
		if (isVoid(rtype)) {
			throw makeAssigningVoid(/*#ref*/v.assign.loc);
		}
		if (isAuto(v.type)) {
			auto atype = cast(ir.AutoType) v.type;
			if (rtype.nodeType == ir.NodeType.FunctionSetType || atype is null) {
				throw makeCannotInfer(/*#ref*/v.assign.loc);
			}
			v.type = flattenAuto(atype, rtype);
		} else {
			if (!willConvert(ctx, v.type, v.assign)) {
				throw makeBadImplicitCast(v, rtype, v.type);
			}
		}
		bool assigningOutsideFunction = v.storage != ir.Variable.Storage.Function;
		if (assigningOutsideFunction && v.type.isScope && mutableIndirection(v.type)) {
			throw makeNoEscapeScope(/*#ref*/v.loc);
		}
		doConvert(ctx, v.type, /*#ref*/v.assign);
	}

	v.isResolved = true;
}

void lazyParseBlock(Context ctx, ir.Scope current, ref ir.Token[] tokens, ref ir.BlockStatement blockStatement)
{
	if (tokens.length == 0 || blockStatement !is null) {
		return;
	}
	auto mod = getModuleFromScope(/*#ref*/tokens[0].loc, current);
	blockStatement = ctx.lp.frontend.parseBlockStatement(/*#ref*/tokens, mod.magicFlagD);
}

void resolveFunction(Context ctx, ir.Function func)
{
	if (func.isResolved) {
		return;
	}


	auto done = ctx.lp.startResolving(func);
	scope (success) done();

	if (func.isAutoReturn) {
		func.type.ret = buildVoid(/*#ref*/func.type.ret.loc);
	}

	if (func.access == ir.Access.Private) {
		func.isFinal = true;
	}

	if (func.type.isProperty &&
	    func.type.params.length == 0 &&
	    isVoid(func.type.ret)) {
		throw makeVoidReturnMarkedProperty(/*#ref*/func.loc, func.name);
	} else if (func.type.isProperty &&
	           func.type.params.length > 1) {
		throw makeWrongNumberOfArguments(func, func, func.type.params.length, isVoid(func.type.ret) ? 0U : 1U);
	}
	if (func.type.hasVarArgs && func.type.linkage == ir.Linkage.C && func.hasBody) {
		throw makeUnsupported(/*#ref*/func.loc, "extern (C) variadic function with body defined");
	}

	// Ctx points the context surrounding the Function
	ir.Type refType = func.type;
	resolveType(ctx, /*#ref*/refType);
	func.type = cast(ir.FunctionType) refType;
	func.type.typeInfo = ctx.lp.tiTypeInfo;

	if (func.name == "main" && func.type.linkage == ir.Linkage.Volt) {

		if (func.params.length == 0) {
			addParam(ctx.lp.errSink, /*#ref*/func.loc, func, buildStringArray(/*#ref*/func.loc), "");
		} else if (func.params.length > 1) {
			throw makeInvalidMainSignature(func);
		}

		auto arr = cast(ir.ArrayType) func.type.params[0];
		if (arr is null ||
		    !isString(realType(arr.base)) ||
		    (!isVoid(func.type.ret) && !isInt(func.type.ret))) {
			throw makeInvalidMainSignature(func);
		}
	}

	if ((func.kind == ir.Function.Kind.Function ||
	     (cast(ir.Class) func.myScope.parent.node) is null) &&
	    func.isMarkedOverride) {
		throw makeMarkedOverrideDoesNotOverride(func, func);
	}

	if (func.type.homogenousVariadic && !isArray(realType(func.type.params[$-1]))) {
		throw makeExpected(/*#ref*/func.params[$-1].loc, "array type");
	}

	foreach (i, ref param; func.params) {
		if (param.assign is null) {
			continue;
		}
		auto texp = cast(ir.TokenExp) param.assign;
		if (texp !is null) {
			continue;
		}

		// We don't extype TokenExp because we want it to be resolved
		// at the call site not where it was defined.
		extype(ctx, /*#ref*/param.assign, Parent.NA);
		param.assign = evaluate(ctx.lp, ctx.current, param.assign);
	}

	if (func.loadDynamic && func.hasBody) {
		throw makeCannotLoadDynamic(func, func);
	}

	func.isResolved = true;
}

void resolveStruct(LanguagePass lp, ir.Struct s)
{
	if (s.isActualized) {
		return;
	}

	auto done = lp.startResolving(s);
	scope (success) done();

	s.isResolved = true;

	// Resolve fields.
	foreach (n; s.members.nodes) {
		auto _t = cast(ir.Type)n;
		if (_t !is null) {
			resolveChildStructsAndUnions(lp, realType(_t, false));
		}
		if (n.nodeType != ir.NodeType.Variable) {
			continue;
		}

		auto field = cast(ir.Variable)n;
		assert(field !is null);
		if (field.storage != ir.Variable.Storage.Field) {
			continue;
		}
		lp.resolve(s.myScope, field);
		resolveChildStructsAndUnions(lp, realType(field.type, false));
	}

	s.isActualized = true;

	if (s.loweredNode is null) {
		createAggregateVar(lp, s);
		fillInAggregateVar(lp, s);
	}
}

void resolveUnion(LanguagePass lp, ir.Union u)
{
	if (u.isActualized) {
		return;
	}


	auto done = lp.startResolving(u);
	scope (success) done();

	u.isResolved = true;

	// Resolve fields.
	size_t accum;
	foreach (n; u.members.nodes) {
		auto _t = cast(ir.Type)n;
		if (_t !is null) {
			resolveChildStructsAndUnions(lp, realType(_t, false));
		}
		if (n.nodeType == ir.NodeType.Function) {
			auto func = cast(ir.Function)n;
			if (func.kind == ir.Function.Kind.Constructor ||
			    func.kind == ir.Function.Kind.Destructor) {
				continue;
			}
			throw makeExpected(n, "field");
		}

		if (n.nodeType != ir.NodeType.Variable) {
			continue;
		}

		auto field = cast(ir.Variable)n;
		assert(field !is null);
		if (field.storage != ir.Variable.Storage.Field) {
			continue;
		}
		lp.resolve(u.myScope, field);
		auto s = size(lp.target, field.type);
		if (s > accum) {
			accum = s;
		}
	}

	u.totalSize = accum;
	u.isActualized = true;

	createAggregateVar(lp, u);
	fillInAggregateVar(lp, u);
}


/*
 *
 * Misc helper functions.
 *
 */
/*!
 * Check a if a given aggregate contains an erroneous
 * default constructor or destructor.
 */
void checkDefaultFootors(Context ctx, ir.Aggregate agg)
{
	foreach (node; agg.members.nodes) {
		auto func = cast(ir.Function)node;
		if (func is null) {
			continue;
		}
		auto ctor = ir.Function.Kind.Constructor;
		auto dtor = ir.Function.Kind.Destructor;
		if (func.kind == ctor && func.params.length == 0) {
			throw makeStructDefaultCtor(/*#ref*/func.loc);
		}
		if (func.kind == dtor) {
			throw makeStructDestructor(/*#ref*/func.loc);
		}
	}
}

/*!
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
		auto func = cast(ir.Function) n;
		string name;
		if (var !is null) {
			name = var.name;
		} else if (func !is null) {
			name = func.name;
		} else {
			continue;
		}
		if ((name in names) !is null) {
			throw makeAnonymousAggregateRedefines(anonAgg, name);
		}
		auto store = lookupAsThisScope(ctx.lp, agg.myScope, /*#ref*/agg.loc, name, ctx.current);
		if (store !is null) {
			throw makeAnonymousAggregateRedefines(anonAgg, name);
		}
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
			auto eref = buildExpReference(/*#ref*/ctor.thisHiddenParameter.loc, ctor.thisHiddenParameter, ctor.thisHiddenParameter.name);
			auto assign = buildAssign(/*#ref*/ctor.loc, buildAccessExp(/*#ref*/ctor.loc, eref, v), v.assign);
			auto stat = new ir.ExpStatement();
			stat.loc = ctor.loc;
			stat.exp = copyExp(assign);
			assert(ctor.parsedBody !is null);
			ctor.parsedBody.statements = stat ~ ctor.parsedBody.statements;
		}
		v.assign = null;
		if (v.type.isConst || v.type.isImmutable) {
			throw makeConstField(v);
		}
	}
}

/*!
 * Given a expression and a type, if the expression is a literal,
 * tag it (and its subexpressions) with the type.
 */
void tagLiteralType(ir.Exp exp, ir.Type type)
{
	auto literal = cast(ir.LiteralExp)exp;
	if (literal is null) {
		return;
	}
	literal.type = copyTypeSmart(/*#ref*/exp.loc, type);

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
			throw makeUnexpected(/*#ref*/exp.loc, "array literal");
		}

		auto alit = cast(ir.ArrayLiteral)exp;
		panicAssert(exp, alit !is null);
		foreach (val; alit.exps) {
			if (aatype !is null) {
				auto aapair = cast(ir.AAPair)val;
				if (aapair is null) {
					throw makeExpected(/*#ref*/exp.loc, "associative array pair");
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
			throw panic(/*#ref*/exp.loc, "tagging struct literal as not a struct.");
		}
		auto vars = getAggregateFieldVars(stype);
		if (slit.exps.length > vars.length) {
			throw makeWrongNumberOfArgumentsToStructLiteral(/*#ref*/exp.loc);
		}
		foreach (i, val; slit.exps) {
			tagLiteralType(val, vars[i].type);
		}
		break;
	case UnionLiteral:
		auto utype = cast(ir.Union)realType(type);
		auto ulit = exp.toUnionLiteralFast();
		if (utype is null || ulit is null) {
			throw panic(/*#ref*/exp.loc, "tagging union literal as not a union");
		}
		auto vars = getAggregateFieldVars(utype);
		if (ulit.exps.length > vars.length) {
			// @TODO: Union literals that can just take the largest field.
			throw makeWrongNumberOfArgumentsToStructLiteral(/*#ref*/exp.loc);
		}
		foreach (i, val; ulit.exps) {
			tagLiteralType(val, vars[i].type);
		}
		break;
	default:
		throw panicUnhandled(/*#ref*/exp.loc, "literal type");
	}
}

/*
 *
 * Nested code.
 *
 */



/*
 *
 * Goto replacement code.
 *
 */

class GotoReplacer : NullVisitor
{
public:
	this(Context ctx, ir.SwitchStatement ss, bool isArraySwitch)
	{
		this.ctx = ctx;
		this.ss = ss;
		this.isArraySwitch = isArraySwitch;
	}

	override Status enter(ir.GotoStatement gs)
	{
		if (gs.isCase && gs.exp is null && exp !is null) {
			gs.exp = copyExp(exp);
		}
		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		foreach (ref node; bs.statements) {
			if (node.nodeType != ir.NodeType.GotoStatement) {
				continue;
			}
			auto gs = node.toGotoStatementFast();
			auto theExp = gs.exp;
			if (theExp is null) {
				theExp = originalExp;
			}
			if (!gs.isCase || theExp is null || !isArraySwitch) {
				continue;
			}
			auto cv = buildExpReference(/*#ref*/ss.condVar.loc, ss.condVar, ss.condVar.name);
			auto assign = buildExpStat(/*#ref*/node.loc, buildAssign(/*#ref*/node.loc, cv, copyExp(theExp)));
			gs.exp = buildConstantUint(/*#ref*/theExp.loc, getExpHash(ctx, ss, theExp));
			node = buildBlockStat(/*#ref*/node.loc, gs, bs.myScope, assign, gs);
			return ContinueParent;
		}
		return Continue;
	}

public:
	ir.Exp exp;  // The next case (processed).
	ir.Exp originalExp;  // The next case (unprocessed).
	Context ctx;
	ir.SwitchStatement ss;
	bool isArraySwitch;
}

/*!
 * Given a switch statement, replace 'goto case' with an explicit
 * jump to the next case, or hash the expression if needed.
 */
void replaceGotoCase(Context ctx, ir.SwitchStatement ss, bool arraySwitch)
{
	auto gr = new GotoReplacer(ctx, ss, arraySwitch);
	foreach_reverse (sc; ss.cases) {
		accept(sc.statements, gr);
		gr.originalExp = sc.originalExps.length > 0 ? sc.originalExps[0] : sc.originalFirstExp;
		gr.exp = sc.exps.length > 0 ? sc.exps[0] : sc.firstExp;
	}
}

/*!
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
 *
 * @ingroup passes passLang passSem
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

	/*!
	 * For out of band checking of Variables.
	 */
	void resolve(ir.Scope current, ir.Variable v)
	{
		assert(!v.isResolved);

		ctx.setupFromScope(current);
		scope (success) ctx.reset();

		auto oldHasBeenDeclared = v.hasBeenDeclared;
		resolveVariable(ctx, v);
		v.hasBeenDeclared = oldHasBeenDeclared;
	}

	/*!
	 * For out of band checking of Functions.
	 */
	void resolve(ir.Scope current, ir.Function func)
	{
		assert(!func.isResolved);

		ctx.setupFromScope(current);
		scope (success) ctx.reset();

		resolveFunction(ctx, func);
	}

	void transform(ir.Scope current, ir.TemplateInstance ti)
	{
		ctx.setupFromScope(current);
		scope (success) ctx.reset();
		extypeTemplateInstance(ctx, ti);
	}

	void transform(ir.Scope current, ir.Attribute a)
	{
		ctx.setupFromScope(current);
		scope (success) ctx.reset();

		foreach (i, ref arg; a.arguments) {
			extype(ctx, /*#ref*/a.arguments[i], Parent.NA);
		}
	}

	void transform(ir.Scope current, ir.EnumDeclaration ed)
	{
		ctx.setupFromScope(current);
		scope (success) ctx.reset();

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

	void resolve(ir.EnumDeclaration ed, ir.Exp prevExp)
	{
		resolveType(ctx, /*#ref*/ed.type);

		ir.Type rtype;
		if (ed.assign is null) {
			if (prevExp is null) {
				ir.Constant c;
				ed.assign = c = buildConstantInt(/*#ref*/ed.loc, 0);
				rtype = c.type;
			} else {
				auto loc = ed.loc;
				rtype = getExpType(prevExp);
				auto prevType = realType(rtype);
				if (!isIntegral(prevType)) {
					throw makeTypeIsNot(ed, prevType, buildInt(/*#ref*/ed.loc));
				}

				ir.Exp add = buildAdd(/*#ref*/loc, copyExp(prevExp), buildConstantInt(/*#ref*/loc, 1));
				extype(ctx, /*#ref*/add, Parent.NA);
				ed.assign = evaluate(ctx.lp, ctx.current, add);
			}
		} else {
			rtype = extype(ctx, /*#ref*/ed.assign, Parent.NA);
			if (needsEvaluation(ed.assign)) {
				ed.assign = evaluate(ctx.lp, ctx.current, ed.assign);
			}
		}

		auto e = cast(ir.Enum) realType(ed.type, false);
		if (e !is null && isAuto(realType(e.base))) {
			e.base = realType(e.base);
			auto atype = cast(ir.AutoType) e.base;
			auto t = realType(copyTypeSmart(/*#ref*/ed.assign.loc, rtype));
			e.base = flattenAuto(atype, t);
		}
		if (isAuto(realType(ed.type))) {
			ed.type = realType(ed.type);
			auto atype = cast(ir.AutoType) ed.type;
			auto t = realType(copyTypeSmart(/*#ref*/ed.assign.loc, rtype));
			ed.type = flattenAuto(atype, t);
		}
		checkAndDoConvert(ctx, ed.type, /*#ref*/ed.assign);

		ed.resolved = true;
	}


	/*
	 *
	 * Visitor
	 *
	 */

	override Status enter(ir.TopLevelBlock tlb)
	{
		// We do this to ensure that tlb.nodes doesn't change.
		auto old = tlb.nodes;
		foreach (n; tlb.nodes) {
			accept(n, this);
			panicAssert(n, old is tlb.nodes);
		}

		return ContinueParent;
	}

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
		if (a.staticIf !is null) {
			foreach (ref condition; a.staticIf.conditions) {
				extype(ctx, /*#ref*/condition, Parent.NA);
			}
		}
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
		checkDefaultFootors(ctx, s);
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
		checkDefaultFootors(ctx, u);
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

	override Status enter(ir.EnumDeclaration ed)
	{
		ctx.lp.resolve(ctx.current, ed);
		return ContinueParent;
	}

	override Status enter(ir.Variable v)
	{
		if (!v.isResolved) {
			resolveVariable(ctx, v);
		}
		return ContinueParent;
	}

	override Status enter(ir.Function func)
	{
		actualizeFunction(ctx, func);
		return ContinueParent;
	}

	override Status enter(ir.AssertStatement n)
	{
		panicAssert(n, n.isStatic);
		ir.Node nd = n;
		extypeAssertStatement(ctx, /*#ref*/nd);
		return ContinueParent;
	}

	override Status enter(ir.TemplateInstance ti)
	{
		ctx.enter(ti);
		if (ti._struct is null && ti._function is null) {
			extypeTemplateInstance(ctx, ti);
			final switch (ti.kind) with (ir.TemplateKind) {
			case Struct:
				accept(ti._struct, ctx.extyper);
				break;
			case Function:
				accept(ti._function, ctx.extyper);
				break;
			case Class:
				accept(ti._class, ctx.extyper);
				break;
			case Union:
				accept(ti._union, ctx.extyper);
				break;
			case Interface:
				accept(ti._interface, ctx.extyper);
				break;
			}
		}
		return Continue;
	}

	override Status leave(ir.TemplateInstance ti)
	{
		ctx.leave(ti);
		ti.myScope.parent = ti.oldParent;
		return Continue;
	}

	/*
	 *
	 * Error checking.
	 *
	 */

	override Status leave(ir.Function n) { throw panic(n, "visitor"); }
	override Status enter(ir.FunctionParam n) { throw panic(n, "visitor"); }
	override Status leave(ir.FunctionParam n) { throw panic(n, "visitor"); }

	override Status enter(ir.TypeOf n) { throw panic(n, "visitor"); }
	override Status leave(ir.TypeOf n) { throw panic(n, "visitor"); }

	override Status enter(ir.IfStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.IfStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.DoStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.DoStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.ForStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.ForStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.TryStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.TryStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.ExpStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.ExpStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.WithStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.WithStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.GotoStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.GotoStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.ThrowStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.ThrowStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.BlockStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.BlockStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.WhileStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.WhileStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.SwitchStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.SwitchStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.AssertStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.ReturnStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.ReturnStatement n) { throw panic(n, "visitor"); }
	override Status enter(ir.ForeachStatement n) { throw panic(n, "visitor"); }
	override Status leave(ir.ForeachStatement n) { throw panic(n, "visitor"); }

	override Status visit(ir.BreakStatement n) { throw panic(n, "visitor"); }
	override Status visit(ir.ContinueStatement n) { throw panic(n, "visitor"); }

	override Status enter(ref ir.Exp exp, ir.IsExp) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.IsExp) { throw panic(exp, "visitor"); }
	override Status enter(ref ir.Exp exp, ir.BinOp) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.BinOp) { throw panic(exp, "visitor"); }
	override Status enter(ref ir.Exp exp, ir.Unary) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.Unary) { throw panic(exp, "visitor"); }
	override Status enter(ref ir.Exp exp, ir.Typeid) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.Typeid) { throw panic(exp, "visitor"); }
	override Status enter(ref ir.Exp exp, ir.Postfix) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.Postfix) { throw panic(exp, "visitor"); }
	override Status enter(ref ir.Exp exp, ir.Ternary) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.Ternary) { throw panic(exp, "visitor"); }
	override Status enter(ref ir.Exp exp, ir.TypeExp) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.TypeExp) { throw panic(exp, "visitor"); }
	override Status enter(ref ir.Exp exp, ir.VaArgExp) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.VaArgExp) { throw panic(exp, "visitor"); }
	override Status enter(ref ir.Exp exp, ir.Constant) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.Constant) { throw panic(exp, "visitor"); }
	override Status enter(ref ir.Exp exp, ir.AssocArray) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.AssocArray) { throw panic(exp, "visitor"); }
	override Status enter(ref ir.Exp exp, ir.ArrayLiteral) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.ArrayLiteral) { throw panic(exp, "visitor"); }
	override Status enter(ref ir.Exp exp, ir.StructLiteral) { throw panic(exp, "visitor"); }
	override Status leave(ref ir.Exp exp, ir.StructLiteral) { throw panic(exp, "visitor"); }

	override Status visit(ref ir.Exp exp, ir.TokenExp) { throw panic(exp, "visitor"); }
	override Status visit(ref ir.Exp exp, ir.ExpReference) { throw panic(exp, "visitor"); }
	override Status visit(ref ir.Exp exp, ir.IdentifierExp) { throw panic(exp, "visitor"); }
}
