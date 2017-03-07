// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.util;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.util.string : unescapeString;
import volt.ir.copy;


/**
 * Builds an identifier exp from a string.
 */
ir.IdentifierExp buildIdentifierExp(ref in Location loc, string value, bool isGlobal = false)
{
	auto iexp = new ir.IdentifierExp(value);
	iexp.loc = loc;
	iexp.globalLookup = isGlobal;
	return iexp;
}

/**
 * Builds a QualifiedName from a string.
 */
ir.QualifiedName buildQualifiedName(ref in Location loc, string value)
{
	auto i = new ir.Identifier(value);
	i.loc = loc;
	auto q = new ir.QualifiedName();
	q.identifiers = [i];
	q.loc = loc;
	return q;
}

/**
 * Builds a QualifiedName from an array.
 */
ir.QualifiedName buildQualifiedName(ref in Location loc, string[] value...)
{
	version (Volt) {
		auto idents = new ir.Identifier[](value.length);
	} else {
		auto idents = new ir.Identifier[value.length];
	}
	foreach (i, val; value) {
		idents[i] = new ir.Identifier(val);
		idents[i].loc = loc;
	}

	auto q = new ir.QualifiedName();
	q.identifiers = idents;
	q.loc = loc;
	return q;
}

/**
 * Builds a QualifiedName from a Identifier.
 */
ir.QualifiedName buildQualifiedNameSmart(ir.Identifier i)
{
	auto q = new ir.QualifiedName();
	q.identifiers = [new ir.Identifier(i)];
	q.loc = i.loc;
	return q;
}

/**
 * Return the scope from the given type if it is,
 * a aggregate or a derivative from one.
 */
ir.Scope getScopeFromType(ir.Type type)
{
	switch (type.nodeType) with (ir.NodeType) {
	case TypeReference:
		auto asTypeRef = cast(ir.TypeReference) type;
		assert(asTypeRef !is null);
		assert(asTypeRef.type !is null);
		return getScopeFromType(asTypeRef.type);
	case ArrayType:
		auto asArray = cast(ir.ArrayType) type;
		assert(asArray !is null);
		return getScopeFromType(asArray.base);
	case PointerType:
		auto asPointer = cast(ir.PointerType) type;
		assert(asPointer !is null);
		return getScopeFromType(asPointer.base);
	case Struct:
		auto asStruct = cast(ir.Struct) type;
		assert(asStruct !is null);
		return asStruct.myScope;
	case Union:
		auto asUnion = cast(ir.Union) type;
		assert(asUnion !is null);
		return asUnion.myScope;
	case Class:
		auto asClass = cast(ir.Class) type;
		assert(asClass !is null);
		return asClass.myScope;
	case Interface:
		auto asInterface = cast(ir._Interface) type;
		assert(asInterface !is null);
		return asInterface.myScope;
	case Enum:
		auto asEnum = cast(ir.Enum) type;
		assert(asEnum !is null);
		return asEnum.myScope;
	default:
		return null;
	}
}

/**
 * For the given store get the scope that it introduces.
 *
 * Returns null for Values and non-scope types.
 */
ir.Scope getScopeFromStore(ir.Store store)
{
	final switch(store.kind) with (ir.Store.Kind) {
	case Scope:
		return store.myScope;
	case Type:
		auto type = cast(ir.Type)store.node;
		assert(type !is null);
		return getScopeFromType(type);
	case Value:
	case Function:
	case FunctionParam:
	case Template:
	case EnumDeclaration:
		return null;
	case Merge:
	case Alias:
		throw panic(store.node.loc, "unresolved alias");
	case Reserved:
		throw panic(store.node, "reserved ident '%s' found.", store.name);
	}
}

/**
 * Does a smart copy of a type.
 *
 * Meaning that well copy all types, but skipping
 * TypeReferences, but inserting one when it comes
 * across a named type.
 */
ir.Type copyTypeSmart(ref in Location loc, ir.Type type)
{
	ir.Type outType;
	switch (type.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto pt = cast(ir.PrimitiveType)type;
		pt = new ir.PrimitiveType(pt.type);
		pt.loc = loc;
		outType = pt;
		break;
	case PointerType:
		auto pt = cast(ir.PointerType)type;
		pt = new ir.PointerType(copyTypeSmart(loc, pt.base));
		pt.loc = loc;
		outType = pt;
		break;
	case ArrayType:
		auto at = cast(ir.ArrayType)type;
		at = new ir.ArrayType(copyTypeSmart(loc, at.base));
		at.loc = loc;
		outType = at;
		break;
	case StaticArrayType:
		auto asSat = cast(ir.StaticArrayType)type;
		auto sat = new ir.StaticArrayType();
		sat.loc = loc;
		sat.base = copyTypeSmart(loc, asSat.base);
		sat.length = asSat.length;
		outType = sat;
		break;
	case AAType:
		auto asAA = cast(ir.AAType)type;
		auto aa = new ir.AAType();
		aa.loc = loc;
		aa.value = copyTypeSmart(loc, asAA.value);
		aa.key = copyTypeSmart(loc, asAA.key);
		outType = aa;
		break;
	case FunctionType:
		auto asFt = cast(ir.FunctionType)type;
		auto ft = new ir.FunctionType(asFt);
		ft.loc = loc;
		ft.ret = copyTypeSmart(loc, ft.ret);
		foreach (i, ref t; ft.params) {
			t = copyTypeSmart(loc, t);
		}
		outType = ft;
		break;
	case FunctionSetType:
		auto asFset = cast(ir.FunctionSetType)type;
		auto fset = new ir.FunctionSetType();
		fset.loc = loc;
		fset.set = asFset.set;
		fset.isFromCreateDelegate = asFset.isFromCreateDelegate;
		outType = fset;
		break;
	case DelegateType:
		auto asDg = cast(ir.DelegateType)type;
		auto dgt = new ir.DelegateType(asDg);
		dgt.loc = loc;
		dgt.ret = copyTypeSmart(loc, dgt.ret);
		foreach (i, ref t; dgt.params) {
			t = copyTypeSmart(loc, t);
		}
		outType = dgt;
		break;
	case StorageType:
		auto asSt = cast(ir.StorageType)type;
		auto st = new ir.StorageType();
		st.loc = loc;
		if (asSt.base !is null) st.base = copyTypeSmart(loc, asSt.base);
		st.type = asSt.type;
		outType = st;
		break;
	case AutoType:
		auto asAt = cast(ir.AutoType)type;
		auto at = new ir.AutoType();
		at.loc = loc;
		if (asAt.explicitType !is null) {
			at.explicitType = copyTypeSmart(loc, asAt.explicitType);
		}
		outType = at;
		break;
	case TypeReference:
		auto tr = cast(ir.TypeReference)type;
		assert(tr.type !is null);
		outType = copyTypeSmart(loc, tr.type);
		break;
	case NullType:
		auto nt = new ir.NullType();
		nt.loc = type.loc;
		outType = nt;
		break;
	case Interface:
	case Struct:
	case Class:
	case Union:
	case Enum:
		auto s = getScopeFromType(type);
		// @todo Get fully qualified name for type.
		outType = buildTypeReference(loc, type, s !is null ? s.name : null);
		break;
	default:
		throw panicUnhandled(type, ir.nodeToString(type));
	}
	addStorage(outType, type);
	return outType;
}

ir.TypeReference buildTypeReference(ref in Location loc, ir.Type type, string[] names...)
{
	auto tr = new ir.TypeReference();
	tr.loc = loc;
	tr.type = type;
	tr.id = buildQualifiedName(loc, names);
	return tr;
}

ir.StorageType buildStorageType(ref in Location loc, ir.StorageType.Kind kind, ir.Type base)
{
	auto storage = new ir.StorageType();
	storage.loc = loc;
	storage.type = kind;
	storage.base = base;
	return storage;
}

/**
 * Build a PrimitiveType.
 */
ir.PrimitiveType buildPrimitiveType(ref in Location loc, ir.PrimitiveType.Kind kind)
{
	auto pt = new ir.PrimitiveType(kind);
	pt.loc = loc;
	return pt;
}

ir.ArrayType buildArrayType(ref in Location loc, ir.Type base)
{
	auto array = new ir.ArrayType();
	array.loc = loc;
	array.base = base;
	return array;
}

ir.ArrayType buildArrayTypeSmart(ref in Location loc, ir.Type base)
{
	auto array = new ir.ArrayType();
	array.loc = loc;
	array.base = copyTypeSmart(loc, base);
	return array;
}

ir.PrimitiveType buildVoid(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Void); }
ir.PrimitiveType buildBool(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Bool); }
ir.PrimitiveType buildChar(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Char); }
ir.PrimitiveType buildDchar(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Dchar); }
ir.PrimitiveType buildWchar(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Wchar); }
ir.PrimitiveType buildByte(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Byte); }
ir.PrimitiveType buildUbyte(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Ubyte); }
ir.PrimitiveType buildShort(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Short); }
ir.PrimitiveType buildUshort(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Ushort); }
ir.PrimitiveType buildInt(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Int); }
ir.PrimitiveType buildUint(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Uint); }
ir.PrimitiveType buildLong(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Long); }
ir.PrimitiveType buildUlong(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Ulong); }
ir.PrimitiveType buildFloat(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Float); }
ir.PrimitiveType buildDouble(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Double); }
ir.PrimitiveType buildReal(ref in Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Real); }

ir.PrimitiveType buildSizeT(ref in Location loc, TargetInfo target)
{
	ir.PrimitiveType pt;
	if (target.isP64) {
		pt = new ir.PrimitiveType(ir.PrimitiveType.Kind.Ulong);
	} else {
		pt = new ir.PrimitiveType(ir.PrimitiveType.Kind.Uint);
	}
	pt.loc = loc;
	return pt;
}

/**
 * Build a string (immutable(char)[]) type.
 */
ir.ArrayType buildString(ref in Location loc)
{
	auto c = buildChar(loc);
	c.isImmutable = true;
	c.glossedName = "string"; // For readability.
	return buildArrayType(loc, c);
}

ir.ArrayType buildStringArray(ref in Location loc)
{
	return buildArrayType(loc, buildString(loc));
}


/**
 * Build a void* type.
 */
ir.PointerType buildVoidPtr(ref in Location loc)
{
	auto pt = new ir.PointerType(buildVoid(loc));
	pt.loc = loc;

	return pt;
}

ir.PointerType buildPtrSmart(ref in Location loc, ir.Type base)
{
	auto pt = new ir.PointerType(copyTypeSmart(loc, base));
	pt.loc = loc;

	return pt;
}

ir.PointerType buildPtr(ref in Location loc, ir.Type base)
{
	auto pt = new ir.PointerType(base);
	pt.loc = loc;

	return pt;
}

ir.ArrayLiteral buildArrayLiteralSmart(ref in Location loc, ir.Type type, ir.Exp[] exps...)
{
	auto literal = new ir.ArrayLiteral();
	literal.loc = loc;
	literal.type = copyTypeSmart(loc, type);
	version (Volt) {
		literal.exps = new exps[0 .. $];
	} else {
		literal.exps = exps.dup;
	}
	return literal;
}

ir.StructLiteral buildStructLiteralSmart(ref in Location loc, ir.Type type, ir.Exp[] exps)
{
	auto literal = new ir.StructLiteral();
	literal.loc = loc;
	literal.type = copyTypeSmart(loc, type);
	version (Volt) {
		literal.exps = new exps[0 .. $];
	} else {
		literal.exps = exps.dup;
	}
	return literal;
}

ir.UnionLiteral buildUnionLiteralSmart(ref in Location loc, ir.Type type, ir.Exp[] exps)
{
	auto literal = new ir.UnionLiteral();
	literal.loc = loc;
	literal.type = copyTypeSmart(loc, type);
	version (Volt) {
		literal.exps = new exps[0 .. $];
	} else {
		literal.exps = exps.dup;
	}
	return literal;
}

/**
 * Add a Variable to the BlockStatement scope and either to
 * its statement or if StatementExp given to it instead.
 */
void addVariable(ir.BlockStatement b, ir.StatementExp statExp, ir.Variable var)
{
	b.myScope.addValue(var, var.name);
	if (statExp !is null) {
		statExp.statements ~= var;
	} else {
		b.statements ~= var;
	}
}

/**
 * Build a Variable, while not being smart about its type.
 */
ir.Variable buildVariable(ref in Location loc, ir.Type type, ir.Variable.Storage st, string name, ir.Exp assign = null)
{
	auto var = new ir.Variable();
	var.loc = loc;
	var.name = name;
	var.type = type;
	var.storage = st;
	var.assign = assign;

	return var;
}

/**
 * Build a Variable with an anon. name and insert it into the BlockStatement
 * or StatementExp if given. Note even if you want the Variable to end up in
 * the StatementExp you must give it the BlockStatement that the StatementExp
 * lives in as the variable will be added to its scope and generated a uniqe
 * name from its context.
 */
ir.Variable buildVariableAnonSmart(ref in Location loc, ir.BlockStatement b,
                                   ir.StatementExp statExp,
                                   ir.Type type, ir.Exp assign)
{
	assert(b !is null);
	assert(b.myScope !is null);
	auto name = b.myScope.genAnonIdent();
	auto var = buildVariable(loc, copyTypeSmart(loc, type), ir.Variable.Storage.Function, name, assign);
	addVariable(b, statExp, var);
	return var;
}

/// Build a variable and add it to the top of a block statement.
ir.Variable buildVariableAnonSmartAtTop(ref in Location loc, ir.BlockStatement b,
                                   ir.Type type, ir.Exp assign)
{
	assert(b !is null);
	assert(b.myScope !is null);
	auto name = b.myScope.genAnonIdent();
	auto var = buildVariable(loc, copyTypeSmart(loc, type), ir.Variable.Storage.Function, name, assign);
	b.statements = var ~ b.statements;
	b.myScope.addValue(var, var.name);
	return var;
}


/**
 * Create an anonymous variable for a statementexp without a block statement.
 */
ir.Variable buildVariableAnonSmart(ref in Location loc, ir.Scope current,
                                   ir.StatementExp statExp,
                                   ir.Type type, ir.Exp assign)
{
	auto name = current.genAnonIdent();
	auto var = buildVariable(loc, copyTypeSmart(loc, type), ir.Variable.Storage.Function, name, assign);
	current.addValue(var, var.name);
	statExp.statements ~= var;
	return var;
}

/**
 * Copy a Variable, while being smart about its type, does
 * not copy the the assign exp on the Variable.
 */
ir.Variable copyVariableSmart(ref in Location loc, ir.Variable right)
{
	return buildVariable(loc, copyTypeSmart(loc, right.type), right.storage, right.name);
}

ir.Variable[] copyVariablesSmart(ref in Location loc, ir.Variable[] vars)
{
	version (Volt) {
		auto outVars = new ir.Variable[](vars.length);
	} else {
		auto outVars = new ir.Variable[vars.length];
	}
	foreach (i, var; vars) {
		outVars[i] = copyVariableSmart(loc, var);
	}
	return outVars;
}

/**
 * Get ExpReferences from a list of variables.
 */
ir.Exp[] getExpRefs(ref in Location loc, ir.FunctionParam[] vars)
{
	version (Volt) {
		auto erefs = new ir.Exp[](vars.length);
	} else {
		auto erefs = new ir.Exp[vars.length];
	}
	foreach (i, var; vars) {
		erefs[i] = buildExpReference(loc, var, var.name);
	}
	return erefs;
}

/**
 * Build a Variable, while being smart about its type.
 */
ir.Variable buildVariableSmart(ref in Location loc, ir.Type type, ir.Variable.Storage st, string name)
{
	return buildVariable(loc, copyTypeSmart(loc, type), st, name);
}

/**
 * Builds a usable ExpReference.
 */
ir.ExpReference buildExpReference(ref in Location loc, ir.Declaration decl, string[] names...)
{
	auto varRef = new ir.ExpReference();
	varRef.loc = loc;
	varRef.decl = decl;
	varRef.idents ~= names;

	return varRef;
}

ir.ExpReference buildExpReference(ref in Location loc, ir.Function func)
{
	return buildExpReference(loc, func, func.name);
}

/**
 * Builds a constant double.
 */
ir.Constant buildConstantDouble(ref in Location loc, double value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._double = value;
	c.type = buildDouble(loc);

	return c;
}

/**
 * Builds a constant float.
 */
ir.Constant buildConstantFloat(ref in Location loc, float value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._float = value;
	c.type = buildFloat(loc);

	return c;
}

/**
 * Builds a constant int.
 */
ir.Constant buildConstantInt(ref in Location loc, int value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._int = value;
	c.type = buildInt(loc);

	return c;
}

ir.Constant buildConstantUint(ref in Location loc, uint value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._uint = value;
	c.type = buildUint(loc);

	return c;
}

ir.Constant buildConstantLong(ref in Location loc, long value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._long = value;
	c.type = buildLong(loc);

	return c;
}

ir.Constant buildConstantUlong(ref in Location loc, ulong value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._ulong = value;
	c.type = buildUlong(loc);

	return c;
}

ir.Constant buildConstantByte(ref in Location loc, byte value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._byte = value;
	c.type = buildByte(loc);

	return c;
}

ir.Constant buildConstantUbyte(ref in Location loc, ubyte value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._ubyte = value;
	c.type = buildUbyte(loc);

	return c;
}

ir.Constant buildConstantShort(ref in Location loc, short value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._short = value;
	c.type = buildShort(loc);

	return c;
}

ir.Constant buildConstantUshort(ref in Location loc, ushort value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._ushort = value;
	c.type = buildUshort(loc);

	return c;
}
/**
 * Builds a constant bool.
 */
ir.Constant buildConstantBool(ref in Location loc, bool val)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._bool = val;
	c.type = buildBool(loc);

	return c;
}

ir.Constant buildConstantNull(ref in Location loc, ir.Type base)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._pointer = null;
	c.type = copyTypeSmart(loc, base);
	c.type.loc = loc;
	c.isNull = true;
	return c;
}

/**
 * Gets a size_t Constant and fills it with a value.
 */
ir.Constant buildConstantSizeT(ref in Location loc, TargetInfo target, size_t val)
{
	auto c = new ir.Constant();
	c.loc = loc;
	auto prim = buildSizeT(loc, target);
	// Uh, I assume just c._uint = val would work, but I can't test it here, so just be safe.
	if (prim.type == ir.PrimitiveType.Kind.Ulong) {
		c.u._ulong = cast(ulong)val;
	} else {
		c.u._uint = cast(uint)val;
	}
	c.type = prim;
	return c;
}

/**
 * Builds a constant string.
 */
ir.Constant buildConstantString(ref in Location loc, string val, bool escape = true)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c._string = val;
	auto atype = buildArrayType(loc, buildChar(loc));
	atype.base.isImmutable = true;
	c.type = atype;
	if (escape) {
		c.arrayData = unescapeString(loc, c._string);
	} else {
		c.arrayData = cast(immutable(void)[]) c._string;
	}
	return c;
}

/**
 * Builds a constant 'c' string.
 */
ir.Exp buildConstantCString(ref in Location loc, string val, bool escape = true)
{
	return buildArrayPtr(loc, buildChar(loc),
	                     buildConstantString(loc, val, escape));
}

/**
 * Build a constant to insert to the IR from a resolved EnumDeclaration.
 */
ir.Constant buildConstantEnum(ref in Location loc, ir.EnumDeclaration ed)
{
	auto cnst = cast(ir.Constant) ed.assign;
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._ulong = cnst.u._ulong;
	c._string = cnst._string;
	c.arrayData = cnst.arrayData;
	c.type = copyTypeSmart(loc, ed.type);

	return c;
}

ir.Constant buildConstantTrue(ref in Location loc) { return buildConstantBool(loc, true); }
ir.Constant buildConstantFalse(ref in Location loc) { return buildConstantBool(loc, false); }

/**
 * Build a cast and sets the loc, does not call copyTypeSmart.
 */
ir.Unary buildCast(ref in Location loc, ir.Type type, ir.Exp exp)
{
	auto cst = new ir.Unary(type, exp);
	cst.loc = loc;
	return cst;
}

/**
 * Build a cast, sets the loc and calling copyTypeSmart
 * on the type, to avoid duplicate nodes.
 */
ir.Unary buildCastSmart(ref in Location loc, ir.Type type, ir.Exp exp)
{
	return buildCast(loc, copyTypeSmart(loc, type), exp);
}

ir.Unary buildCastToBool(ref in Location loc, ir.Exp exp) { return buildCast(loc, buildBool(loc), exp); }
ir.Unary buildCastToVoidPtr(ref in Location loc, ir.Exp exp) { return buildCast(loc, buildVoidPtr(loc), exp); }

/**
 * Builds a not expression.
 */
ir.Unary buildNot(ref in Location loc, ir.Exp exp)
{
	auto unot = new ir.Unary();
	unot.loc = loc;
	unot.op = ir.Unary.Op.Not;
	unot.value = exp;
	return unot;
}

/**
 * Builds an AddrOf expression.
 */
ir.Unary buildAddrOf(ref in Location loc, ir.Exp exp)
{
	auto addr = new ir.Unary();
	addr.loc = loc;
	addr.op = ir.Unary.Op.AddrOf;
	addr.value = exp;
	return addr;
}

/**
 * Builds a ExpReference and a AddrOf from a Variable.
 */
ir.Unary buildAddrOf(ref in Location loc, ir.Variable var, string[] names...)
{
	return buildAddrOf(loc, buildExpReference(loc, var, names));
}

/**
 * Builds a dereference expression.
 */
ir.Unary buildDeref(ref in Location loc, ir.Exp exp)
{
	auto deref = new ir.Unary();
	deref.loc = loc;
	deref.op = ir.Unary.Op.Dereference;
	deref.value = exp;
	return deref;
}

/**
 * Builds an expression that dereferences a variable.
 */
ir.Unary buildDeref(ref in Location loc, ir.Variable var)
{
	auto eref = buildExpReference(loc, var, var.name);
	return buildDeref(loc, eref);
}

/**
 * Builds a New expression.
 */
ir.Unary buildNew(ref in Location loc, ir.Type type, string name, ir.Exp[] arguments...)
{
	auto new_ = new ir.Unary();
	new_.loc = loc;
	new_.op = ir.Unary.Op.New;
	new_.type = buildTypeReference(loc, type, name);
	new_.hasArgumentList = arguments.length > 0;
	version (Volt) {
		new_.argumentList = new arguments[0 .. $];
	} else {
		new_.argumentList = arguments.dup;
	}
	return new_;
}

ir.Unary buildNewSmart(ref in Location loc, ir.Type type, ir.Exp[] arguments...)
{
	auto new_ = new ir.Unary();
	new_.loc = loc;
	new_.op = ir.Unary.Op.New;
 	new_.type = copyTypeSmart(loc, type);
	new_.hasArgumentList = arguments.length > 0;
	version (Volt) {
		new_.argumentList = new arguments[0 .. $];
	} else {
		new_.argumentList = arguments.dup;
	}
	return new_;
}

/**
 * Builds a typeid with type smartly.
 */
ir.Typeid buildTypeidSmart(ref in Location loc, ir.Type type)
{
	auto t = new ir.Typeid();
	t.loc = loc;
	t.type = copyTypeSmart(loc, type);
	return t;
}

/**
 * Build a typeid casting if needed.
 */
ir.Exp buildTypeidSmart(ref in Location loc, LanguagePass lp, ir.Type type)
{
	return buildCastSmart(loc, lp.tiTypeInfo, buildTypeidSmart(loc, type));
}

/**
 * Builds a BuiltinExp of ArrayPtr type. Make sure the type you
 * pass in is the base of the array and that the child exp is
 * not a pointer to an array.
 */
ir.BuiltinExp buildArrayPtr(ref in Location loc, ir.Type base, ir.Exp child)
{
	auto ptr = buildPtrSmart(loc, base);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.ArrayPtr, ptr, [child]);
	builtin.loc = loc;

	return builtin;
}

/**
 * Builds a BuiltinExp of ArrayLength type. Make sure the child exp is
 * not a pointer to an array.
 */
ir.BuiltinExp buildArrayLength(ref in Location loc, TargetInfo target, ir.Exp child)
{
	auto st = buildSizeT(loc, target);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.ArrayLength, st, [child]);
	builtin.loc = loc;

	return builtin;
}

/**
 * Builds an ArrayDup BuiltinExp.
 */
ir.BuiltinExp buildArrayDup(ref in Location loc, ir.Type t, ir.Exp[] children)
{
	auto bi = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.ArrayDup, copyTypeSmart(loc, t), children);
	bi.loc = loc;
	return bi;
}

/**
 * Builds a BuiltinExp of AALength type.
 */
ir.BuiltinExp buildAALength(ref in Location loc, TargetInfo target, ir.Exp[] child)
{
	auto st = buildSizeT(loc, target);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AALength, st, child);
	builtin.loc = loc;

	return builtin;
}

/**
 * Builds a BuiltinExp of AAKeys type.
 */
ir.BuiltinExp buildAAKeys(ref in Location loc, ir.AAType aa, ir.Exp[] child)
{
	auto st = buildArrayTypeSmart(loc, aa.key);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AAKeys, st, child);
	builtin.loc = loc;

	return builtin;
}

/**
 * Builds a BuiltinExp of AAValues type.
 */
ir.BuiltinExp buildAAValues(ref in Location loc, ir.AAType aa, ir.Exp[] child)
{
	auto st = buildArrayTypeSmart(loc, aa.value);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AAValues, st, child);
	builtin.loc = loc;

	return builtin;
}

/**
 * Builds a BuiltinExp of AARehash type.
 */
ir.BuiltinExp buildAARehash(ref in Location loc, ir.Exp[] child)
{
	auto st = buildVoid(loc);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AAValues, st, child);
	builtin.loc = loc;

	return builtin;
}

/**
 * Builds a BuiltinExp of AAGet type.
 */
ir.BuiltinExp buildAAGet(ref in Location loc, ir.AAType aa, ir.Exp[] child)
{
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AAGet, copyTypeSmart(loc, aa.value), child);
	builtin.loc = loc;
	return builtin;
}

/**
 * Builds a BuiltinExp of AARemove type.
 */
ir.BuiltinExp buildAARemove(ref in Location loc, ir.Exp[] child)
{
	auto st = buildBool(loc);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AARemove, st, child);
	builtin.loc = loc;

	return builtin;
}


/**
 * Builds a BuiltinExp of AARemove type.
 */
ir.BuiltinExp buildUFCS(ref in Location loc, ir.Type type, ir.Exp child,
                        ir.Function[] funcs)
{
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.UFCS, type, [child]);
	builtin.loc = loc;
	builtin.functions = funcs;

	return builtin;
}


/**
 * Builds a BuiltinExp of Classinfo type.
 */
ir.BuiltinExp buildClassinfo(ref in Location loc, ir.Type type, ir.Exp child)
{
	auto kind = ir.BuiltinExp.Kind.Classinfo;
	auto builtin = new ir.BuiltinExp(kind, type, [child]);
	builtin.loc = loc;
	return builtin;
}


/**
 * Builds a BuiltinExp of AARemove type.
 */
ir.BuiltinExp buildAAIn(ref in Location loc, ir.AAType aa, ir.Exp[] child)
{
	auto p = buildPtrSmart(loc, aa.value);
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.AAIn, p, child);
	bi.loc = loc;
	return bi;
}

/**
 * Builds a BuiltinExp of AADup type.
 */
ir.BuiltinExp buildAADup(ref in Location loc, ir.AAType aa, ir.Exp[] child)
{
	auto p = copyTypeSmart(loc, aa);
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.AADup, p, child);
	bi.loc = loc;
	return bi;
}

/**
 * Builds a BuiltinExp of PODCtor type.
 */
ir.BuiltinExp buildPODCtor(ref in Location loc, ir.PODAggregate pod, ir.Postfix postfix, ir.Function ctor)
{
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.PODCtor, copyTypeSmart(loc, pod), [cast(ir.Exp)postfix]);
	bi.functions ~= ctor;
	bi.loc = loc;
	return bi;
}

/**
 * Build a postfix Identifier expression.
 */
ir.Postfix buildPostfixIdentifier(ref in Location loc, ir.Exp exp, string name)
{
	auto access = new ir.Postfix();
	access.loc = loc;
	access.op = ir.Postfix.Op.Identifier;
	access.child = exp;
	access.identifier = new ir.Identifier();
	access.identifier.loc = loc;
	access.identifier.value = name;

	return access;
}

ir.AccessExp buildAccessExp(ref in Location loc, ir.Exp child, ir.Variable field)
{
	auto ae = new ir.AccessExp();
	ae.loc = loc;
	ae.child = child;
	ae.field = field;

	return ae;
}

/**
 * Builds a chain of postfix lookups from a QualifiedName.
 * These are only useful before the extyper runs.
 */
ir.Postfix buildPostfixIdentifier(ref in Location loc, ir.QualifiedName qname, string name)
{
	ir.Exp current = buildIdentifierExp(loc, qname.identifiers[0].value);
	foreach (ident; qname.identifiers[1 .. $]) {
		auto pfix = new ir.Postfix();
		pfix.loc = loc;
		pfix.child = current;
		pfix.op = ir.Postfix.Op.Identifier;
		pfix.identifier = new ir.Identifier();
		pfix.identifier.loc = loc;
		pfix.identifier.value = ident.value;
		current = pfix;
	}
	return buildPostfixIdentifier(loc, current, name);
}

/**
 * Builds a postfix slice.
 */
ir.Postfix buildSlice(ref in Location loc, ir.Exp child, ir.Exp[] args...)
{
	auto slice = new ir.Postfix();
	slice.loc = loc;
	slice.op = ir.Postfix.Op.Slice;
	slice.child = child;
	version (Volt) {
		slice.arguments = new args[0 .. $];
	} else {
		slice.arguments = args.dup;
	}

	return slice;
}

/**
 * Builds a postfix increment.
 */
ir.Postfix buildIncrement(ref in Location loc, ir.Exp child)
{
	auto inc = new ir.Postfix();
	inc.loc = loc;
	inc.op = ir.Postfix.Op.Increment;
	inc.child = child;

	return inc;
}

/**
 * Builds a postfix decrement.
 */
ir.Postfix buildDecrement(ref in Location loc, ir.Exp child)
{
	auto inc = new ir.Postfix();
	inc.loc = loc;
	inc.op = ir.Postfix.Op.Decrement;
	inc.child = child;

	return inc;
}

/**
 * Builds a postfix index.
 */
ir.Postfix buildIndex(ref in Location loc, ir.Exp child, ir.Exp arg)
{
	auto slice = new ir.Postfix();
	slice.loc = loc;
	slice.op = ir.Postfix.Op.Index;
	slice.child = child;
	slice.arguments ~= arg;

	return slice;
}

/**
 * Builds a postfix call.
 */
ir.Postfix buildCall(ref in Location loc, ir.Exp child, ir.Exp[] args)
{
	auto call = new ir.Postfix();
	call.loc = loc;
	call.op = ir.Postfix.Op.Call;
	call.child = child;
	version (Volt) {
		call.arguments = new args[0 .. $];
	} else {
		call.arguments = args.dup;
	}

	return call;
}

/**
 * Builds a call to a function.
 */
ir.Postfix buildCall(ref in Location loc, ir.Function func, ir.Exp[] args)
{
	auto eref = buildExpReference(loc, func, func.name);
	return buildCall(loc, eref, args);
}

ir.Postfix buildMemberCall(ref in Location loc, ir.Exp child, ir.ExpReference func, string name, ir.Exp[] args)
{
	auto lookup = new ir.Postfix();
	lookup.loc = loc;
	lookup.op = ir.Postfix.Op.CreateDelegate;
	lookup.child = child;
	lookup.identifier = new ir.Identifier();
	lookup.identifier.loc = loc;
	lookup.identifier.value = name;
	lookup.memberFunction = func;

	auto call = new ir.Postfix();
	call.loc = loc;
	call.op = ir.Postfix.Op.Call;
	call.child = lookup;
	call.arguments = args;

	return call;
}

ir.Postfix buildCreateDelegate(ref in Location loc, ir.Exp child, ir.ExpReference func)
{
	auto postfix = new ir.Postfix();
	postfix.loc = loc;
	postfix.op = ir.Postfix.Op.CreateDelegate;
	postfix.child = child;
	postfix.memberFunction = func;
	return postfix;
}

ir.PropertyExp buildProperty(ref in Location loc, string name, ir.Exp child,
                             ir.Function getFn, ir.Function[] setFns)
{
	auto prop = new ir.PropertyExp();
	prop.loc = loc;
	prop.child = child;
	prop.identifier = new ir.Identifier(name);
	prop.identifier.loc = loc;
	prop.getFn  = getFn;
	prop.setFns = setFns;
	return prop;
}

/**
 * Builds a postfix call.
 */
ir.Postfix buildCall(ref in Location loc, ir.Declaration decl, ir.Exp[] args, string[] names...)
{
	return buildCall(loc, buildExpReference(loc, decl, names), args);
}

/**
 * Builds an add BinOp.
 */
ir.BinOp buildAdd(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(loc, ir.BinOp.Op.Add, left, right);
}

/**
 * Builds a subtraction BinOp.
 */
ir.BinOp buildSub(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(loc, ir.BinOp.Op.Sub, left, right);
}

/**
 * Builds an assign BinOp.
 */
ir.BinOp buildAssign(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(loc, ir.BinOp.Op.Assign, left, right);
}

/**
 * Builds an assign BinOp to a given variable.
 */
ir.BinOp buildAssign(ref in Location loc, ir.Variable left, ir.Exp right)
{
	auto eref = buildExpReference(loc, left, left.name);
	return buildAssign(loc, eref, right);
}

/**
 * Builds an assign BinOp to a given variable from a given variable.
 */
ir.BinOp buildAssign(ref in Location loc, ir.Variable left, ir.Variable right)
{
	auto lref = buildExpReference(loc, left, left.name);
	auto rref = buildExpReference(loc, right, right.name);
	return buildAssign(loc, lref, rref);
}

/**
 * Builds an add-assign BinOp.
 */
ir.BinOp buildAddAssign(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(loc, ir.BinOp.Op.AddAssign, left, right);
}

/**
 * Builds a cat-assign BinOp.
 */
ir.BinOp buildCatAssign(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(loc, ir.BinOp.Op.CatAssign, left, right);
}

/**
 * Builds an BinOp.
 */
ir.BinOp buildBinOp(ref in Location loc, ir.BinOp.Op op, ir.Exp left, ir.Exp right)
{
	auto binop = new ir.BinOp();
	binop.loc = loc;
	binop.op = op;
	binop.left = left;
	binop.right = right;
	return binop;
}

ir.StatementExp buildStatementExp(ref in Location loc)
{
	auto stateExp = new ir.StatementExp();
	stateExp.loc = loc;
	return stateExp;
}

ir.StatementExp buildStatementExp(ref in Location loc, ir.Node[] stats, ir.Exp exp)
{
	auto stateExp = buildStatementExp(loc);
	stateExp.statements = stats;
	stateExp.exp = exp;
	return stateExp;
}

ir.FunctionParam buildFunctionParam(ref in Location loc, size_t index, string name, ir.Function func)
{
	auto fparam = new ir.FunctionParam();
	fparam.loc = loc;
	fparam.index = index;
	fparam.name = name;
	fparam.func = func;
	return fparam;
}

/**
 * Adds a variable argument to a function, also adds it to the scope.
 */
ir.FunctionParam addParam(ref in Location loc, ir.Function func, ir.Type type, string name)
{
	auto var = buildFunctionParam(loc, func.type.params.length, name, func);

	func.type.params ~= type;
	func.type.isArgOut ~= false;
	func.type.isArgRef ~= false;

	func.params ~= var;
	func.myScope.addValue(var, name);

	return var;
}

/**
 * Adds a variable argument to a function, also adds it to the scope.
 */
ir.FunctionParam addParamSmart(ref in Location loc, ir.Function func, ir.Type type, string name)
{
	return addParam(loc, func, copyTypeSmart(loc, type), name);
}

/**
 * Builds a variable statement smartly, inserting at the end of the
 * block statements and inserting it in the scope.
 */
ir.Variable buildVarStatSmart(ref in Location loc, ir.BlockStatement block, ir.Scope _scope, ir.Type type, string name)
{
	auto var = buildVariableSmart(loc, type, ir.Variable.Storage.Function, name);
	block.statements ~= var;
	_scope.addValue(var, name);
	return var;
}

/**
 * Add an Exp to a StatementExp.
 */
ir.ExpStatement buildExpStat(ref in Location loc, ir.StatementExp stat, ir.Exp exp)
{
	auto ret = new ir.ExpStatement();
	ret.loc = loc;
	ret.exp = exp;

	stat.statements ~= ret;

	return ret;
}

ir.ThrowStatement buildThrowStatement(ref in Location loc, ir.Exp exp)
{
	auto ts = new ir.ThrowStatement();
	ts.loc = loc;
	ts.exp = exp;
	return ts;
}

ir.BuiltinExp buildVaArgStart(ref in Location loc, ir.Exp vlexp, ir.Exp argexp)
{
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.VaStart, buildVoid(loc), [vlexp, argexp]);
	bi.loc = loc;
	return bi;
}

ir.BuiltinExp buildVaArgEnd(ref in Location loc, ir.Exp vlexp)
{
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.VaEnd, buildVoid(loc), [vlexp]);
	bi.loc = loc;
	return bi;
}

ir.BuiltinExp buildVaArg(ref in Location loc, ir.VaArgExp vaexp)
{
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.VaArg, copyType(vaexp.type), [cast(ir.Exp)vaexp]);
	bi.loc = loc;
	return bi;
}

ir.StatementExp buildInternalArrayLiteralSmart(ref in Location loc, ir.Type atype, ir.Exp[] exps)
{
	if (atype.nodeType != ir.NodeType.ArrayType) {
		throw panic(atype, "must be array type");
	}
	auto arr = cast(ir.ArrayType) atype;
	panicAssert(atype, arr !is null);

	auto sexp = new ir.StatementExp();
	sexp.loc = loc;
	auto var = buildVariableSmart(loc, copyTypeSmart(loc, atype), ir.Variable.Storage.Function, "array");
	sexp.statements ~= var;
	auto _new = buildNewSmart(loc, atype, buildConstantUint(loc, cast(uint) exps.length));
	auto vassign = buildAssign(loc, buildExpReference(loc, var), _new);
	buildExpStat(loc, sexp, vassign);
	foreach (i, exp; exps) {
		auto slice = buildIndex(loc, buildExpReference(loc, var), buildConstantUint(loc, cast(uint) i));
		auto assign = buildAssign(loc, slice, buildCastSmart(arr.base, exp));
		buildExpStat(loc, sexp, assign);
	}
	sexp.exp = buildExpReference(loc, var, var.name);
	return sexp;
}

ir.StatementExp buildInternalStaticArrayLiteralSmart(ref in Location loc, ir.Type atype, ir.Exp[] exps)
{
	if (atype.nodeType != ir.NodeType.StaticArrayType) {
		throw panic(atype, "must be staticarray type");
	}
	auto arr = cast(ir.StaticArrayType) atype;
	panicAssert(atype, arr !is null);

	auto sexp = new ir.StatementExp();
	sexp.loc = loc;
	auto var = buildVariableSmart(loc, copyTypeSmart(loc, atype), ir.Variable.Storage.Function, "sarray");
	sexp.statements ~= var;
	foreach (i, exp; exps) {
		auto l = buildIndex(loc, buildExpReference(loc, var), buildConstantUint(loc, cast(uint) i));
		auto assign = buildAssign(loc, l, buildCastSmart(arr.base, exp));
		buildExpStat(loc, sexp, assign);
	}
	sexp.exp = buildExpReference(loc, var, var.name);
	return sexp;
}

ir.StatementExp buildInternalArrayLiteralSliceSmart(ref in Location loc,
	LanguagePass lp, ir.Type atype, ir.Type[] types,
	int[] sizes, int totalSize, ir.Exp[] exps)
{
	if (atype.nodeType != ir.NodeType.ArrayType)
		throw panic(atype, "must be array type");

	auto memcpyFn = lp.target.isP64 ? lp.llvmMemcpy64 : lp.llvmMemcpy32;

	auto sexp = new ir.StatementExp();
	sexp.loc = loc;
	auto var = buildVariableSmart(loc, copyTypeSmart(loc, atype), ir.Variable.Storage.Function, "array");

	sexp.statements ~= var;
	auto _new = buildNewSmart(loc, atype, buildConstantUint(loc, cast(uint) totalSize));
	auto vassign = buildAssign(loc, buildExpReference(loc, var), _new);
	buildExpStat(loc, sexp, vassign);

	int offset;
	foreach (i, exp; exps) {
		auto evar = buildVariableSmart(loc, types[i], ir.Variable.Storage.Function, "exp");
		sexp.statements ~= evar;
		auto evassign = buildAssign(loc, buildExpReference(loc, evar), exp);
		buildExpStat(loc, sexp, evassign);

		ir.Exp dst = buildAdd(loc, buildArrayPtr(loc, var.type, buildExpReference(loc, var)), buildConstantUint(loc, cast(uint)offset));
		ir.Exp src = buildCastToVoidPtr(loc, buildAddrOf(loc, buildExpReference(loc, evar)));
		ir.Exp len = buildConstantSizeT(loc, lp.target, cast(size_t)sizes[i]);
		ir.Exp aln = buildConstantInt(loc, 0);
		ir.Exp vol = buildConstantBool(loc, false);
		auto call = buildCall(loc, buildExpReference(loc, memcpyFn), [dst, src, len, aln, vol]);
		buildExpStat(loc, sexp, call);
		offset += sizes[i];
	}
	sexp.exp = buildExpReference(loc, var, var.name);
	return sexp;
}
/**
 * Build an exp statement and add it to a block.
 */
ir.ExpStatement buildExpStat(ref in Location loc, ir.BlockStatement block, ir.Exp exp)
{
	auto ret = new ir.ExpStatement();
	ret.loc = loc;
	ret.exp = exp;

	block.statements ~= ret;

	return ret;
}

/**
 * Build an exp statement without inserting it anywhere.
 */
ir.ExpStatement buildExpStat(ref in Location loc, ir.Exp exp)
{
	auto ret = new ir.ExpStatement();
	ret.loc = loc;
	ret.exp = exp;
	return ret;
}


/**
 * Build an if statement.
 */
ir.IfStatement buildIfStat(ref in Location loc, ir.Exp exp,
                           ir.BlockStatement thenState, ir.BlockStatement elseState = null, string autoName = "")
{
	auto ret = new ir.IfStatement();
	ret.loc = loc;
	ret.exp = exp;
	ret.thenState = thenState;
	ret.elseState = elseState;
	ret.autoName = autoName;

	return ret;
}

/**
 * Build an if statement.
 */
ir.IfStatement buildIfStat(ref in Location loc, ir.BlockStatement block, ir.Exp exp,
                           ir.BlockStatement thenState, ir.BlockStatement elseState = null, string autoName = "")
{
	auto ret = new ir.IfStatement();
	ret.loc = loc;
	ret.exp = exp;
	ret.thenState = thenState;
	ret.elseState = elseState;
	ret.autoName = autoName;

	block.statements ~= ret;

	return ret;
}

/**
 * Build an if statement.
 */
ir.IfStatement buildIfStat(ref in Location loc, ir.StatementExp statExp, ir.Exp exp,
                           ir.BlockStatement thenState, ir.BlockStatement elseState = null, string autoName = "")
{
	auto ret = new ir.IfStatement();
	ret.loc = loc;
	ret.exp = exp;
	ret.thenState = thenState;
	ret.elseState = elseState;
	ret.autoName = autoName;

	statExp.statements ~= ret;

	return ret;
}

/**
 * Build a block statement.
 */
ir.BlockStatement buildBlockStat(ref in Location loc, ir.Node introducingNode, ir.Scope _scope, ir.Node[] statements...)
{
	auto ret = new ir.BlockStatement();
	ret.loc = loc;
	if (statements.length > 0) {
		version (Volt) {
			ret.statements = new statements[0 .. $];
		} else {
			ret.statements = statements.dup;
		}
	}
	ret.myScope = new ir.Scope(_scope, introducingNode is null ? ret : introducingNode, "block", _scope.nestedDepth);

	return ret;
}


/**
 * Build a return statement.
 */
ir.ReturnStatement buildReturnStat(ref in Location loc, ir.BlockStatement block, ir.Exp exp = null)
{
	auto ret = new ir.ReturnStatement();
	ret.loc = loc;
	ret.exp = exp;

	block.statements ~= ret;

	return ret;
}

ir.FunctionType buildFunctionTypeSmart(ref in Location loc, ir.Type ret, ir.Type[] args...)
{
	auto type = new ir.FunctionType();
	type.loc = loc;
	type.ret = copyType(ret);
	foreach (arg; args) {
		type.params ~= copyType(arg);
		type.isArgRef ~= false;
		type.isArgOut ~= false;
	}
	return type;
}

/// Builds a function without inserting it anywhere.
ir.Function buildFunction(ref in Location loc, ir.Scope _scope, string name, bool buildBody = true)
{
	auto func = new ir.Function();
	func.name = name;
	func.loc = loc;
	func.kind = ir.Function.Kind.Function;
	func.myScope = new ir.Scope(_scope, func, func.name, _scope.nestedDepth);

	func.type = new ir.FunctionType();
	func.type.loc = loc;
	func.type.ret = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
	func.type.ret.loc = loc;

	if (buildBody) {
		func._body = new ir.BlockStatement();
		func._body.loc = loc;
		func._body.myScope = new ir.Scope(func.myScope, func._body, name, func.myScope.nestedDepth);
	}

	return func;
}

/// Builds a function with a given type.
ir.Function buildFunction(ref in Location loc, ir.Scope _scope, string name, ir.FunctionType ftype)
{
	auto func = new ir.Function();
	func.name = name;
	func.loc = loc;
	func.kind = ir.Function.Kind.Function;
	func.myScope = new ir.Scope(_scope, func, func.name, _scope.nestedDepth);

	func.type = ftype;

	func._body = new ir.BlockStatement();
	func._body.loc = loc;
	func._body.myScope = new ir.Scope(func.myScope, func._body, name, func.myScope.nestedDepth);

	return func;
}

/**
 * Builds a completely useable Function and insert it into the
 * various places it needs to be inserted.
 */
ir.Function buildFunction(ref in Location loc, ir.TopLevelBlock tlb, ir.Scope _scope, string name, bool buildBody = true)
{
	auto func = buildFunction(loc, _scope, name, buildBody);

	// Insert the struct into all the places.
	_scope.addFunction(func, func.name);
	tlb.nodes ~= func;
	return func;
}

ir.Function buildGlobalConstructor(ref in Location loc, ir.TopLevelBlock tlb, ir.Scope _scope, string name, bool buildBody = true)
{
	auto func = buildFunction(loc, tlb, _scope, name, buildBody);
	func.kind = ir.Function.Kind.GlobalConstructor;
	return func;
}

/**
 * Builds a alias from a string and a Identifier.
 */
ir.Alias buildAliasSmart(ref in Location loc, string name, ir.Identifier i)
{
	auto a = new ir.Alias();
	a.name = name;
	a.loc = loc;
	a.id = buildQualifiedNameSmart(i);
	return a;
}

/**
 * Builds a alias from two strings.
 */
ir.Alias buildAlias(ref in Location loc, string name, string from)
{
	auto a = new ir.Alias();
	a.name = name;
	a.loc = loc;
	a.id = buildQualifiedName(loc, from);
	return a;
}

/**
 * Builds a completely useable struct and insert it into the
 * various places it needs to be inserted.
 *
 * The members list is used directly in the new struct; be wary not to duplicate IR nodes.
 */
ir.Struct buildStruct(ref in Location loc, ir.TopLevelBlock tlb, ir.Scope _scope, string name, ir.Variable[] members...)
{
	auto s = new ir.Struct();
	s.name = name;
	s.myScope = new ir.Scope(_scope, s, name, _scope.nestedDepth);
	s.loc = loc;

	s.members = new ir.TopLevelBlock();
	s.members.loc = loc;

	foreach (member; members) {
		s.members.nodes ~= member;
		s.myScope.addValue(member, member.name);
	}

	// Insert the struct into all the places.
	_scope.addType(s, s.name);
	tlb.nodes ~= s;
	return s;
}

/**
 * Builds an IR complete, but semantically unfinished struct. i.e. it has no scope and isn't inserted anywhere.
 * The members list is used directly in the new struct; be wary not to duplicate IR nodes.
 */
ir.Struct buildStruct(ref in Location loc, string name, ir.Variable[] members...)
{
	auto s = new ir.Struct();
	s.name = name;
	s.loc = loc;

	s.members = new ir.TopLevelBlock();
	s.members.loc = loc;

	foreach (member; members) {
		s.members.nodes ~= member;
	}

	return s;
}

/**
 * Add a variable to a pre-built struct.
 */
ir.Variable addVarToStructSmart(ir.Struct _struct, ir.Variable var)
{
	assert(var.name != "");
	auto cvar = buildVariableSmart(var.loc, var.type, ir.Variable.Storage.Field, var.name);
	_struct.members.nodes ~= cvar;
	_struct.myScope.addValue(cvar, cvar.name);
	return cvar;
}

/**
 * If t is a class, or a typereference to a class, returns the
 * class. Otherwise, returns null.
 */
ir.Class getClass(ir.Type t)
{
	auto asClass = cast(ir.Class) t;
	if (asClass !is null) {
		return asClass;
	}
	auto asTR = cast(ir.TypeReference) t;
	if (asTR is null) {
		return null;
	}
	asClass = cast(ir.Class) asTR.type;
	return asClass;
}

ir.Type buildStaticArrayTypeSmart(ref in Location loc, size_t length, ir.Type base)
{
	auto sat = new ir.StaticArrayType();
	sat.loc = loc;
	sat.length = length;
	sat.base = copyTypeSmart(loc, base);
	return sat;
}

ir.Type buildAATypeSmart(ref in Location loc, ir.Type key, ir.Type value)
{
	auto aa = new ir.AAType();
	aa.loc = loc;
	aa.key = copyTypeSmart(loc, key);
	aa.value = copyTypeSmart(loc, value);
	return aa;
}

/*
 * Functions who takes the loc from the given exp.
 */
ir.Unary buildCastSmart(ir.Type type, ir.Exp exp) { return buildCastSmart(exp.loc, type, exp); }
ir.Unary buildAddrOf(ir.Exp exp) { return buildAddrOf(exp.loc, exp); }
ir.Unary buildCastToBool(ir.Exp exp) { return buildCastToBool(exp.loc, exp); }

ir.Type buildSetType(ref in Location loc, ir.Function[] functions)
{
	assert(functions.length > 0);
	if (functions.length == 1) {
		return functions[0].type;
	}

	auto set = new ir.FunctionSetType();
	set.loc = loc;
	set.set = cast(ir.FunctionSet) buildSet(loc, functions);
	assert(set.set !is null);
	assert(set.set.functions.length > 0);
	return set;
}

ir.Declaration buildSet(ref in Location loc, ir.Function[] functions, ir.ExpReference eref = null)
{
	assert(functions.length > 0);
	if (functions.length == 1) {
		return functions[0];
	}

	auto set = new ir.FunctionSet();
	set.functions = functions;
	set.loc = loc;
	set.reference = eref;
	assert(set.functions.length > 0);
	return set;
}

ir.Type stripStorage(ir.Type type)
{
	auto storage = cast(ir.StorageType) type;
	while (storage !is null) {
		type = storage.base;
		storage = cast(ir.StorageType) type;
	}
	return type;
}

ir.Type deepStripStorage(ir.Type type)
{
	auto ptr = cast(ir.PointerType) type;
	if (ptr !is null) {
		ptr.base = deepStripStorage(ptr.base);
		return ptr;
	}

	auto arr = cast(ir.ArrayType) type;
	if (arr !is null) {
		arr.base = deepStripStorage(arr.base);
		return arr;
	}

	auto aa = cast(ir.AAType) type;
	if (aa !is null) {
		aa.value = deepStripStorage(aa.value);
		aa.key = deepStripStorage(aa.key);
		return aa;
	}

	auto ct = cast(ir.CallableType) type;
	if (ct !is null) {
		ct.ret = deepStripStorage(ct.ret);
		foreach (ref param; ct.params) {
			param = deepStripStorage(param);
		}
		return ct;
	}

	auto storage = cast(ir.StorageType) type;
	if (storage !is null) {
		storage.base = stripStorage(storage.base);
		return storage.base;
	}

	return type;
}

/// Returns the base of consecutive pointers. e.g. 'int***' returns 'int'.
ir.Type realBase(ir.PointerType ptr)
{
	ir.Type base;
	do {
		base = ptr.base;
		ptr = cast(ir.PointerType) base;
	} while (ptr !is null);
	return base;
}

/// Build a with statement that has no block.
ir.WithStatement buildWithStatement(ref in Location loc, ir.Exp exp)
{
	auto ws = new ir.WithStatement();
	ws.loc = loc;
	ws.exp = exp;
	return ws;
}

ir.TokenExp buildTokenExp(ref in Location loc, ir.TokenExp.Type type)
{
	auto texp = new ir.TokenExp(type);
	texp.loc = loc;
	return texp;
}

/// Build a simple index for loop. for (i = 0; i < length; ++i)
void buildForStatement(ref in Location loc, TargetInfo target, ir.Scope parent, ir.Exp length, out ir.ForStatement forStatement, out ir.Variable ivar)
{
	forStatement = new ir.ForStatement();
	forStatement.loc = loc;

	ivar = buildVariable(loc, buildSizeT(loc, target), ir.Variable.Storage.Function, "i", buildConstantSizeT(loc, target, 0));
	forStatement.initVars ~= ivar;
	forStatement.test = buildBinOp(loc, ir.BinOp.Op.Less, buildExpReference(loc, ivar, ivar.name), copyExp(length));
	forStatement.increments ~= buildIncrement(loc, buildExpReference(loc, ivar, ivar.name));
	forStatement.block = buildBlockStat(loc, forStatement, parent);
}

void addStorageIgnoreNamed(ir.Type dest, ir.Type src)
{
	auto named = cast(ir.Named)dest;
	if (named !is null) {
		return;
	}
	addStorage(dest, src);
}

void addStorage(ir.Type dest, ir.Type src)
{
	auto named = cast(ir.Named) dest;
	panicAssert(dest, named is null);
	if (dest is null || src is null) {
		return;
	}
	if (!dest.isConst) dest.isConst = src.isConst;
	if (!dest.isImmutable) dest.isImmutable = src.isImmutable;
	if (!dest.isScope) dest.isScope = src.isScope;
}

void insertInPlace(ref ir.Node[] list, size_t index, ir.Node node)
{
	list = list[0 .. index] ~ node ~ list[index .. $];
}

ir.StoreExp buildStoreExp(ref in Location loc, ir.Store store, string[] idents...)
{
	auto sexp = new ir.StoreExp();
	sexp.loc = loc;
	sexp.store = store;
	version (Volt) {
		sexp.idents = new idents[0 .. $];
	} else {
		sexp.idents = idents.dup;
	}
	return sexp;
}

ir.AutoType buildAutoType(ref in Location loc)
{
	auto at = new ir.AutoType();
	at.loc = loc;
	return at;
}

ir.NoType buildNoType(ref in Location loc)
{
	auto nt = new ir.NoType();
	nt.loc = loc;
	return nt;
}

/// Build a cast to a TypeInfo.
ir.Exp buildTypeInfoCast(LanguagePass lp, ir.Exp e)
{
	return buildCastSmart(e.loc, lp.tiTypeInfo, e);
}

ir.BreakStatement buildBreakStatement(ref in Location loc)
{
	auto bs = new ir.BreakStatement();
	bs.loc = loc;
	return bs;
}

ir.GotoStatement buildGotoDefault(ref in Location loc)
{
	auto gs = new ir.GotoStatement();
	gs.loc = loc;
	gs.isDefault = true;
	return gs;
}

ir.GotoStatement buildGotoCase(ref in Location loc)
{
	auto gs = new ir.GotoStatement();
	gs.loc = loc;
	gs.isCase = true;
	return gs;
}
