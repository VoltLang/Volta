// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.util;

import std.conv : to;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.semantic.util : canonicaliseStorageType;
import volt.util.string : unescapeString;
import ir = volt.ir.ir;
import volt.ir.copy;


/**
 * Builds a QualifiedName from a string.
 */
ir.QualifiedName buildQualifiedName(Location loc, string value)
{
	auto i = new ir.Identifier(value);
	i.location = loc;
	auto q = new ir.QualifiedName();
	q.identifiers = [i];
	q.location = loc;
	return q;
}

/**
 * Builds a QualifiedName from an array.
 */
ir.QualifiedName buildQualifiedName(Location loc, string[] value)
{
	auto idents = new ir.Identifier[value.length];
	foreach (i, val; value) {
		idents[i] = new ir.Identifier(val);
		idents[i].location = loc;
	}

	auto q = new ir.QualifiedName();
	q.identifiers = idents;
	q.location = loc;
	return q;
}

/**
 * Builds a QualifiedName from a Identifier.
 */
ir.QualifiedName buildQualifiedNameSmart(ir.Identifier i)
{
	auto q = new ir.QualifiedName();
	q.identifiers = [new ir.Identifier(i)];
	q.location = i.location;
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
	case UserAttribute:
		auto asAttr = cast(ir.UserAttribute) type;
		assert(asAttr !is null);
		return asAttr.myScope;
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
		return store.s;
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
	case Alias:
		throw panic(store.node.location, "unresolved alias");
	}
}

/**
 * Does a smart copy of a type.
 *
 * Meaning that well copy all types, but skipping
 * TypeReferences, but inserting one when it comes
 * across a named type.
 */
ir.Type copyTypeSmart(Location loc, ir.Type type)
{
	switch (type.nodeType) with (ir.NodeType) {
	case PrimitiveType:
		auto pt = cast(ir.PrimitiveType)type;
		pt.location = loc;
		pt = new ir.PrimitiveType(pt.type);
		return pt;
	case PointerType:
		auto pt = cast(ir.PointerType)type;
		pt.location = loc;
		pt = new ir.PointerType(copyTypeSmart(loc, pt.base));
		return pt;
	case ArrayType:
		auto at = cast(ir.ArrayType)type;
		at.location = loc;
		at = new ir.ArrayType(copyTypeSmart(loc, at.base));
		return at;
	case StaticArrayType:
		auto asSat = cast(ir.StaticArrayType)type;
		auto sat = new ir.StaticArrayType();
		sat.location = loc;
		sat.base = copyTypeSmart(loc, asSat.base);
		sat.length = asSat.length;
		return sat;
	case AAType:
		auto asAA = cast(ir.AAType)type;
		auto aa = new ir.AAType();
		aa.location = loc;
		aa.value = copyTypeSmart(loc, asAA.value);
		aa.key = copyTypeSmart(loc, asAA.key);
		return aa;
	case FunctionType:
		auto asFt = cast(ir.FunctionType)type;
		auto ft = new ir.FunctionType(asFt);
		ft.location = loc;
		ft.ret = copyTypeSmart(loc, ft.ret);
		foreach(i, ref t; ft.params) {
			t = copyTypeSmart(loc, t);
		}
		return ft;
	case DelegateType:
		auto asDg = cast(ir.DelegateType)type;
		auto dg = new ir.DelegateType(asDg);
		dg.location = loc;
		dg.ret = copyTypeSmart(loc, dg.ret);
		foreach(i, ref t; dg.params) {
			t = copyTypeSmart(loc, t);
		}
		return dg;
	case StorageType:
		auto asSt = cast(ir.StorageType)type;
		auto st = new ir.StorageType();
		st.location = loc;
		if (asSt.base !is null) st.base = copyTypeSmart(loc, asSt.base);
		st.type = asSt.type;
		st.isCanonical = asSt.isCanonical;
		return st;
	case TypeReference:
		auto tr = cast(ir.TypeReference)type;
		assert(tr.type !is null);
		return copyTypeSmart(loc, tr.type);
	case NullType:
		auto nt = new ir.NullType();
		nt.location = type.location;
		return nt;
	case UserAttribute:
	case Interface:
	case Struct:
	case Class:
	case Union:
	case Enum:
		auto s = getScopeFromType(type);
		/// @todo Get fully qualified name for type.
		return buildTypeReference(loc, type, s !is null ? s.name : null);
	default:
		throw panicUnhandled(type, to!string(type.nodeType));
	}
}

ir.TypeReference buildTypeReference(Location loc, ir.Type type, string[] names...)
{
	auto tr = new ir.TypeReference();
	tr.location = loc;
	tr.type = type;
	tr.id = buildQualifiedName(loc, names);
	return tr;
}

ir.StorageType buildStorageType(Location loc, ir.StorageType.Kind kind, ir.Type base)
{
	auto storage = new ir.StorageType();
	storage.location = loc;
	storage.type = kind;
	storage.base = base;
	return storage;
}

/**
 * Build a PrimitiveType.
 */
ir.PrimitiveType buildPrimitiveType(Location loc, ir.PrimitiveType.Kind kind)
{
	auto pt = new ir.PrimitiveType(kind);
	pt.location = loc;
	return pt;
}

ir.ArrayType buildArrayType(Location loc, ir.Type base)
{
	auto array = new ir.ArrayType();
	array.location = loc;
	array.base = base;
	return array;
}

ir.ArrayType buildArrayTypeSmart(Location loc, ir.Type base)
{
	auto array = new ir.ArrayType();
	array.location = loc;
	array.base = copyTypeSmart(loc, base);
	return array;
}

ir.PrimitiveType buildVoid(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Void); }
ir.PrimitiveType buildBool(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Bool); }
ir.PrimitiveType buildChar(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Char); }
ir.PrimitiveType buildDchar(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Dchar); }
ir.PrimitiveType buildWchar(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Wchar); }
ir.PrimitiveType buildByte(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Byte); }
ir.PrimitiveType buildUbyte(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Ubyte); }
ir.PrimitiveType buildShort(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Short); }
ir.PrimitiveType buildUshort(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Ushort); }
ir.PrimitiveType buildInt(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Int); }
ir.PrimitiveType buildUint(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Uint); }
ir.PrimitiveType buildLong(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Long); }
ir.PrimitiveType buildUlong(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Ulong); }
ir.PrimitiveType buildSizeT(Location loc, LanguagePass lp) { return lp.settings.getSizeT(loc); }
ir.PrimitiveType buildFloat(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Float); }
ir.PrimitiveType buildDouble(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Double); }
ir.PrimitiveType buildReal(Location loc) { return buildPrimitiveType(loc, ir.PrimitiveType.Kind.Real); }

/**
 * Build a string (immutable(char)[]) type.
 */
ir.ArrayType buildString(Location loc)
{
	auto stor = buildStorageType(loc, ir.StorageType.Kind.Immutable, buildChar(loc));
	return buildArrayType(loc, stor);
}

ir.ArrayType buildStringArray(Location loc)
{
	return buildArrayType(loc, buildString(loc));
}


/**
 * Build a void* type.
 */
ir.PointerType buildVoidPtr(Location loc)
{
	auto pt = new ir.PointerType(buildVoid(loc));
	pt.location = loc;

	return pt;
}

ir.PointerType buildPtrSmart(Location loc, ir.Type base)
{
	auto pt = new ir.PointerType(copyTypeSmart(loc, base));
	pt.location = loc;

	return pt;
}

ir.ArrayLiteral buildArrayLiteralSmart(Location loc, ir.Type type, ir.Exp[] exps...)
{
	auto literal = new ir.ArrayLiteral();
	literal.location = loc;
	literal.type = copyTypeSmart(loc, type);
	literal.values = exps.dup;
	return literal;
}

ir.StructLiteral buildStructLiteralSmart(Location loc, ir.Type type, ir.Exp[] exps)
{
	auto literal = new ir.StructLiteral();
	literal.location = loc;
	literal.type = copyTypeSmart(loc, type);
	literal.exps = exps.dup;
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
ir.Variable buildVariable(Location loc, ir.Type type, ir.Variable.Storage st, string name, ir.Exp assign = null)
{
	auto var = new ir.Variable();
	var.location = loc;
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
ir.Variable buildVariableAnonSmart(Location loc, ir.BlockStatement b,
                                   ir.StatementExp statExp,
                                   ir.Type type, ir.Exp assign)
{
	auto name = b.myScope.genAnonIdent();
	auto var = buildVariable(loc, type, ir.Variable.Storage.Function, name, assign);
	addVariable(b, statExp, var);
	return var;
}

/**
 * Copy a Variable, while being smart about its type, does
 * not copy the the assign exp on the Variable.
 */
ir.Variable copyVariableSmart(Location loc, ir.Variable right)
{
	return buildVariable(loc, copyTypeSmart(loc, right.type), right.storage, right.name);
}

ir.Variable[] copyVariablesSmart(Location loc, ir.Variable[] vars)
{
	auto outVars = new ir.Variable[vars.length];
	foreach (i, var; vars) {
		outVars[i] = copyVariableSmart(loc, var);
	}
	return outVars;
}

/**
 * Get ExpReferences from a list of variables.
 */
ir.Exp[] getExpRefs(Location loc, ir.FunctionParam[] vars)
{
	auto erefs = new ir.Exp[vars.length];
	foreach (i, var; vars) {
		erefs[i] = buildExpReference(loc, var, var.name);
	}
	return erefs;
}

/**
 * Build a Variable, while being smart about its type.
 */
ir.Variable buildVariableSmart(Location loc, ir.Type type, ir.Variable.Storage st, string name)
{
	return buildVariable(loc, copyTypeSmart(loc, type), st, name);
}

/**
 * Builds a usable ExpReference.
 */
ir.ExpReference buildExpReference(Location loc, ir.Declaration decl, string[] names...)
{
	auto varRef = new ir.ExpReference();
	varRef.location = loc;
	varRef.decl = decl;
	varRef.idents ~= names;

	return varRef;
}

/**
 * Builds a constant int.
 */
ir.Constant buildConstantInt(Location loc, int value)
{
	auto c = new ir.Constant();
	c.location = loc;
	c._int = value;
	c.type = buildInt(loc);

	return c;
}

ir.Constant buildConstantUint(Location loc, uint value)
{
	auto c = new ir.Constant();
	c.location = loc;
	c._uint = value;
	c.type = buildUint(loc);

	return c;
}

ir.Constant buildConstantLong(Location loc, long value)
{
	auto c = new ir.Constant();
	c.location = loc;
	c._long = value;
	c.type = buildLong(loc);

	return c;
}

ir.Constant buildConstantUlong(Location loc, ulong value)
{
	auto c = new ir.Constant();
	c.location = loc;
	c._ulong = value;
	c.type = buildUlong(loc);

	return c;
}

/**
 * Builds a constant bool.
 */
ir.Constant buildConstantBool(Location loc, bool val)
{
	auto c = new ir.Constant();
	c.location = loc;
	c._bool = val;
	c.type = buildBool(loc);

	return c;
}

ir.Constant buildConstantNull(Location loc, ir.Type base)
{
	auto c = new ir.Constant();
	c.location = loc;
	c._pointer = null;
	c.type = copyTypeSmart(loc, base);
	c.type.location = loc;
	c.isNull = true;
	return c;
}

/**
 * Gets a size_t Constant and fills it with a value.
 */
ir.Constant buildSizeTConstant(Location loc, LanguagePass lp, int val)
{
	auto c = new ir.Constant();
	c.location = loc;
	auto prim = lp.settings.getSizeT(loc);
	// Uh, I assume just c._uint = val would work, but I can't test it here, so just be safe.
	if (prim.type == ir.PrimitiveType.Kind.Ulong) {
		c._ulong = val;
	} else {
		c._uint = val;
	}
	c.type = prim;
	return c;
}

/**
 * Builds a constant string.
 */
ir.Constant buildStringConstant(Location loc, string val)
{
	auto c = new ir.Constant();
	c.location = loc;
	c._string = val;
	auto stor = buildStorageType(loc, ir.StorageType.Kind.Immutable, buildChar(loc));
	canonicaliseStorageType(stor);
	c.type = buildArrayType(loc, stor);
	assert((c._string[$-1] == '"' || c._string[$-1] == '`') && c._string.length >= 2);
	c.arrayData = unescapeString(loc, c._string[1 .. $-1]);
	return c;
}

/**
 * Build a constant to insert to the IR from a resolved EnumDeclaration.
 */
ir.Constant buildConstant(Location loc, ir.EnumDeclaration ed)
{
	auto cnst = cast(ir.Constant) ed.assign;
	auto c = new ir.Constant();
	c.location = loc;
	c._ulong = cnst._ulong;
	c._string = cnst._string;
	c.arrayData = cnst.arrayData;
	c.type = copyTypeSmart(loc, ed.type);

	return c;
}

ir.Constant buildTrue(Location loc) { return buildConstantBool(loc, true); }
ir.Constant buildFalse(Location loc) { return buildConstantBool(loc, false); }

/**
 * Build a cast and sets the location, does not call copyTypeSmart.
 */
ir.Unary buildCast(Location loc, ir.Type type, ir.Exp exp)
{
	auto cst = new ir.Unary(type, exp);
	cst.location = loc;
	return cst;
}

/**
 * Build a cast, sets the location and calling copyTypeSmart
 * on the type, to avoid duplicate nodes.
 */
ir.Unary buildCastSmart(Location loc, ir.Type type, ir.Exp exp)
{
	return buildCast(loc, copyTypeSmart(loc, type), exp);
}

ir.Unary buildCastToBool(Location loc, ir.Exp exp) { return buildCast(loc, buildBool(loc), exp); }
ir.Unary buildCastToVoidPtr(Location loc, ir.Exp exp) { return buildCast(loc, buildVoidPtr(loc), exp); }

/**
 * Builds an AddrOf expression.
 */
ir.Unary buildAddrOf(Location loc, ir.Exp exp)
{
	auto addr = new ir.Unary();
	addr.location = loc;
	addr.op = ir.Unary.Op.AddrOf;
	addr.value = exp;
	return addr;
}

/**
 * Builds a ExpReference and a AddrOf from a Variable.
 */
ir.Unary buildAddrOf(Location loc, ir.Variable var, string[] names...)
{
	return buildAddrOf(loc, buildExpReference(loc, var, names));
}

/**
 * Builds a Dereference expression.
 */
ir.Unary buildDeref(Location loc, ir.Exp exp)
{
	auto deref = new ir.Unary();
	deref.location = loc;
	deref.op = ir.Unary.Op.Dereference;
	deref.value = exp;
	return deref;
}

/**
 * Builds a New expression.
 */
ir.Unary buildNew(Location loc, ir.Type type, string name, ir.Exp[] arguments...)
{
	auto new_ = new ir.Unary();
	new_.location = loc;
	new_.op = ir.Unary.Op.New;
	new_.type = buildTypeReference(loc, type, name);
// 	new_.type = type;
	new_.hasArgumentList = arguments.length > 0;
	new_.argumentList = arguments;
	return new_;
}

ir.Unary buildNewSmart(Location loc, ir.Type type, ir.Exp[] arguments...)
{
	auto new_ = new ir.Unary();
	new_.location = loc;
	new_.op = ir.Unary.Op.New;
 	new_.type = copyTypeSmart(loc, type);
	new_.hasArgumentList = arguments.length > 0;
	new_.argumentList = arguments.dup;
	return new_;
}

/**
 * Builds a typeid with type smartly.
 */
ir.Typeid buildTypeidSmart(Location loc, ir.Type type)
{
	auto t = new ir.Typeid();
	t.location = loc;
	t.type = copyTypeSmart(loc, type);
	return t;
}

/**
 * Build a postfix Identifier expression.
 */
ir.Postfix buildAccess(Location loc, ir.Exp exp, string name)
{
	auto access = new ir.Postfix();
	access.location = loc;
	access.op = ir.Postfix.Op.Identifier;
	access.child = exp;
	access.identifier = new ir.Identifier();
	access.identifier.location = loc;
	access.identifier.value = name;

	return access;
}

/**
 * Builds a postfix slice.
 */
ir.Postfix buildSlice(Location loc, ir.Exp child, ir.Exp[] args...)
{
	auto slice = new ir.Postfix();
	slice.location = loc;
	slice.op = ir.Postfix.Op.Slice;
	slice.child = child;
	slice.arguments = args.dup;

	return slice;
}

/**
 * Builds a postfix index.
 */
ir.Postfix buildIndex(Location loc, ir.Exp child, ir.Exp arg)
{
	auto slice = new ir.Postfix();
	slice.location = loc;
	slice.op = ir.Postfix.Op.Index;
	slice.child = child;
	slice.arguments ~= arg;

	return slice;
}

/**
 * Builds a postfix call.
 */
ir.Postfix buildCall(Location loc, ir.Exp child, ir.Exp[] args)
{
	auto call = new ir.Postfix();
	call.location = loc;
	call.op = ir.Postfix.Op.Call;
	call.child = child;
	call.arguments = args.dup;

	return call;
}

ir.Postfix buildMemberCall(Location loc, ir.Exp child, ir.ExpReference fn, string name, ir.Exp[] args)
{
	auto lookup = new ir.Postfix();
	lookup.location = loc;
	lookup.op = ir.Postfix.Op.CreateDelegate;
	lookup.child = child;
	lookup.identifier = new ir.Identifier();
	lookup.identifier.location = loc;
	lookup.identifier.value = name;
	lookup.memberFunction = fn;

	auto call = new ir.Postfix();
	call.location = loc;
	call.op = ir.Postfix.Op.Call;
	call.child = lookup;
	call.arguments = args;

	return call;
}

ir.Postfix buildCreateDelegate(Location loc, ir.Exp child, ir.ExpReference fn)
{
	auto postfix = new ir.Postfix();
	postfix.location = loc;
	postfix.op = ir.Postfix.Op.CreateDelegate;
	postfix.child = child;
	postfix.memberFunction = fn;
	return postfix;
}

/**
 * Builds a postfix call.
 */
ir.Postfix buildCall(Location loc, ir.Declaration decl, ir.Exp[] args, string[] names...)
{
	return buildCall(loc, buildExpReference(loc, decl, names), args);
}


/**
 * Builds an add BinOp.
 */
ir.BinOp buildAdd(Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(loc, ir.BinOp.Op.Add, left, right);
}

/**
 * Builds an assign BinOp.
 */
ir.BinOp buildAssign(Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(loc, ir.BinOp.Op.Assign, left, right);
}

/**
 * Builds an add-assign BinOp.
 */
ir.BinOp buildAddAssign(Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(loc, ir.BinOp.Op.AddAssign, left, right);
}

/**
 * Builds an BinOp.
 */
ir.BinOp buildBinOp(Location loc, ir.BinOp.Op op, ir.Exp left, ir.Exp right)
{
	auto binop = new ir.BinOp();
	binop.location = loc;
	binop.op = op;
	binop.left = left;
	binop.right = right;
	return binop;
}

ir.StatementExp buildStatementExp(Location loc)
{
	auto stateExp = new ir.StatementExp();
	stateExp.location = loc;
	return stateExp;
}

ir.StatementExp buildStatementExp(Location loc, ir.Node[] stats, ir.Exp exp)
{
	auto stateExp = buildStatementExp(loc);
	stateExp.statements = stats;
	stateExp.exp = exp;
	return stateExp;
}

ir.FunctionParam buildFunctionParam(Location loc, size_t index, string name, ir.Function fn)
{
	auto fparam = new ir.FunctionParam();
	fparam.location = loc;
	fparam.index = index;
	fparam.name = name;
	fparam.fn = fn;
	return fparam;
}

/**
 * Adds a variable argument to a function, also adds it to the scope.
 */
ir.FunctionParam addParam(Location loc, ir.Function fn, ir.Type type, string name)
{
	auto var = buildFunctionParam(loc, fn.type.params.length, name, fn);

	fn.type.params ~= type;

	fn.params ~= var;
	fn.myScope.addValue(var, name);

	return var;
}

/**
 * Adds a variable argument to a function, also adds it to the scope.
 */
ir.FunctionParam addParamSmart(Location loc, ir.Function fn, ir.Type type, string name)
{
	return addParam(loc, fn, copyTypeSmart(loc, type), name);
}

/**
 * Builds a variable statement smartly, inserting at the end of the
 * block statements and inserting it in the scope.
 */
ir.Variable buildVarStatSmart(Location loc, ir.BlockStatement block, ir.Scope _scope, ir.Type type, string name)
{
	auto var = buildVariableSmart(loc, type, ir.Variable.Storage.Function, name);
	block.statements ~= var;
	_scope.addValue(var, name);
	return var;
}

/**
 * Build an exp statement and add it to a StatementExp.
 */
ir.ExpStatement buildExpStat(Location loc, ir.StatementExp stat, ir.Exp exp)
{
	auto ret = new ir.ExpStatement();
	ret.location = loc;
	ret.exp = exp;

	stat.statements ~= ret;

	return ret;
}

ir.StatementExp buildVaArgCast(Location loc, ir.VaArgExp vaexp)
{
	auto sexp = new ir.StatementExp();
	sexp.location = loc;

	auto ptrToPtr = buildVariableSmart(loc, buildPtrSmart(loc, buildVoidPtr(loc)), ir.Variable.Storage.Function, "ptrToPtr");
	ptrToPtr.assign = buildAddrOf(loc, vaexp.arg);
	sexp.statements ~= ptrToPtr;

	auto cpy = buildVariableSmart(loc, buildVoidPtr(loc), ir.Variable.Storage.Function, "cpy");
	cpy.assign = buildDeref(loc, buildExpReference(loc, ptrToPtr));
	sexp.statements ~= cpy;

	auto vlderef = buildDeref(loc, buildExpReference(loc, ptrToPtr));
	auto tid = buildTypeidSmart(loc, vaexp.type);
	auto sz = buildAccess(loc, tid, "size");
	auto assign = buildAddAssign(loc, vlderef, sz);
	buildExpStat(loc, sexp, assign);

	auto ptr = buildPtrSmart(loc, vaexp.type);
	auto _cast = buildCastSmart(loc, ptr, buildExpReference(loc, cpy));
	auto deref = buildDeref(loc, _cast);
	sexp.exp = deref;

	return sexp;
}

ir.Exp buildVaArgStart(Location loc, ir.Exp vlexp, ir.Exp argexp)
{
	return buildAssign(loc, buildDeref(loc, vlexp), argexp);
}

ir.Exp buildVaArgEnd(Location loc, ir.Exp vlexp)
{
	return buildAssign(loc, buildDeref(loc, vlexp), buildConstantNull(loc, buildVoidPtr(loc)));
}

ir.StatementExp buildInternalArrayLiteralSmart(Location loc, ir.Type atype, ir.Exp[] exps)
{
	assert(atype.nodeType == ir.NodeType.ArrayType);
	auto sexp = new ir.StatementExp();
	sexp.location = loc;
	auto var = buildVariableSmart(loc, copyTypeSmart(loc, atype), ir.Variable.Storage.Function, "array");
	sexp.statements ~= var;
	auto _new = buildNewSmart(loc, atype, buildConstantUint(loc, cast(uint) exps.length));
	auto vassign = buildAssign(loc, buildExpReference(loc, var), _new);
	buildExpStat(loc, sexp, vassign);
	foreach (i, exp; exps) {
		auto slice = buildIndex(loc, buildExpReference(loc, var), buildConstantUint(loc, cast(uint) i));
		auto assign = buildAssign(loc, slice, exp);
		buildExpStat(loc, sexp, assign);
	}
	sexp.exp = buildExpReference(loc, var, var.name);
	return sexp;
}

ir.StatementExp buildInternalArrayLiteralSliceSmart(Location loc, ir.Type atype, ir.Type[] types, int[] sizes, int totalSize, ir.Function memcpyFn, ir.Exp[] exps)
{
	assert(atype.nodeType == ir.NodeType.ArrayType);
	auto sexp = new ir.StatementExp();
	sexp.location = loc;
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

		ir.Exp dst = buildAdd(loc, buildAccess(loc, buildExpReference(loc, var), "ptr"), buildConstantUint(loc, offset));
		ir.Exp src = buildCastToVoidPtr(loc, buildAddrOf(loc, buildExpReference(loc, evar)));
		ir.Exp len = buildConstantUint(loc, cast(uint) sizes[i]);
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
ir.ExpStatement buildExpStat(Location loc, ir.BlockStatement block, ir.Exp exp)
{
	auto ret = new ir.ExpStatement();
	ret.location = loc;
	ret.exp = exp;

	block.statements ~= ret;

	return ret;
}


/**
 * Build an exp statement without inserting it anywhere.
 */
ir.ExpStatement buildExpStat(Location loc, ir.Exp exp)
{
	auto ret = new ir.ExpStatement();
	ret.location = loc;
	ret.exp = exp;
	return ret;
}


/**
 * Build an if statement.
 */
ir.IfStatement buildIfStat(Location loc, ir.BlockStatement block, ir.Exp exp,
                           ir.BlockStatement thenState, ir.BlockStatement elseState = null, string autoName = "")
{
	auto ret = new ir.IfStatement();
	ret.location = loc;
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
ir.IfStatement buildIfStat(Location loc, ir.StatementExp statExp, ir.Exp exp,
                           ir.BlockStatement thenState, ir.BlockStatement elseState = null, string autoName = "")
{
	auto ret = new ir.IfStatement();
	ret.location = loc;
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
ir.BlockStatement buildBlockStat(Location loc, ir.Node introducingNode, ir.Scope _scope, ir.Node[] statements...)
{
	auto ret = new ir.BlockStatement();
	ret.location = loc;
	ret.statements = statements;
	ret.myScope = new ir.Scope(_scope, introducingNode, "block");

	return ret;
}


/**
 * Build a return statement.
 */
ir.ReturnStatement buildReturnStat(Location loc, ir.BlockStatement block, ir.Exp exp = null)
{
	auto ret = new ir.ReturnStatement();
	ret.location = loc;
	ret.exp = exp;

	block.statements ~= ret;

	return ret;
}

/**
 * Builds a completely useable Function and insert it into the
 * various places it needs to be inserted.
 */
ir.Function buildFunction(Location loc, ir.TopLevelBlock tlb, ir.Scope _scope, string name, bool buildBody = true)
{
	auto fn = new ir.Function();
	fn.name = name;
	fn.location = loc;
	fn.kind = ir.Function.Kind.Function;
	fn.myScope = new ir.Scope(_scope, fn, fn.name);

	fn.type = new ir.FunctionType();
	fn.type.location = loc;
	fn.type.ret = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
	fn.type.ret.location = loc;

	if (buildBody) {
		fn._body = new ir.BlockStatement();
		fn._body.location = loc;
		fn._body.myScope = new ir.Scope(fn.myScope, fn._body, name);
	}

	// Insert the struct into all the places.
	_scope.addFunction(fn, fn.name);
	tlb.nodes ~= fn;
	return fn;
}

/**
 * Builds a alias from a string and a Identifier.
 */
ir.Alias buildAliasSmart(Location loc, string name, ir.Identifier i)
{
	auto a = new ir.Alias();
	a.name = name;
	a.location = loc;
	a.id = buildQualifiedNameSmart(i);
	return a;
}

/**
 * Builds a alias from two strings.
 */
ir.Alias buildAlias(Location loc, string name, string from)
{
	auto a = new ir.Alias();
	a.name = name;
	a.location = loc;
	a.id = buildQualifiedName(loc, from);
	return a;
}

/**
 * Builds a completely useable struct and insert it into the
 * various places it needs to be inserted.
 *
 * The members list is used directly in the new struct; be wary not to duplicate IR nodes.
 */
ir.Struct buildStruct(Location loc, ir.TopLevelBlock tlb, ir.Scope _scope, string name, ir.Variable[] members...)
{
	auto s = new ir.Struct();
	s.name = name;
	s.myScope = new ir.Scope(_scope, s, name);
	s.location = loc;

	s.members = new ir.TopLevelBlock();
	s.members.location = loc;

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
ir.Struct buildStruct(Location loc, string name, ir.Variable[] members...)
{
	auto s = new ir.Struct();
	s.name = name;
	s.location = loc;

	s.members = new ir.TopLevelBlock();
	s.members.location = loc;

	foreach (member; members) {
		s.members.nodes ~= member;
	}

	return s;
}

/**
 * Add a variable to a pre-built struct.
 */
void addVarToStructSmart(ir.Struct _struct, ir.Variable var)
{
	auto cvar = buildVariableSmart(var.location, var.type, ir.Variable.Storage.Field, var.name);
	_struct.members.nodes ~= cvar;
	_struct.myScope.addValue(cvar, cvar.name);
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

ir.Type buildStaticArrayTypeSmart(Location loc, size_t length, ir.Type base)
{
	auto sa = new ir.StaticArrayType();
	sa.location = loc;
	sa.length = length;
	sa.base = copyTypeSmart(loc, base);
	return sa;
}

ir.Type buildAATypeSmart(Location loc, ir.Type key, ir.Type value)
{
	auto aa = new ir.AAType();
	aa.location = loc;
	aa.key = copyTypeSmart(loc, key);
	aa.value = copyTypeSmart(loc, value);
	return aa;
}

/*
 * Functions who takes the location from the given exp.
 */
ir.Unary buildCastSmart(ir.Type type, ir.Exp exp) { return buildCastSmart(exp.location, type, exp); }
ir.Unary buildAddrOf(ir.Exp exp) { return buildAddrOf(exp.location, exp); }
ir.Unary buildCastToBool(ir.Exp exp) { return buildCastToBool(exp.location, exp); }

ir.Type buildSetType(Location loc, ir.Function[] functions)
{
	assert(functions.length > 0);
	if (functions.length == 1) {
		return functions[0].type;
	}

	auto set = new ir.FunctionSetType();
	set.location = loc;
	set.set = cast(ir.FunctionSet) buildSet(loc, functions);
	assert(set.set !is null);
	assert(set.set.functions.length > 0);
	return set;
}

ir.Declaration buildSet(Location loc, ir.Function[] functions, ir.ExpReference eref = null)
{
	assert(functions.length > 0);
	if (functions.length == 1) {
		return functions[0];
	}

	auto set = new ir.FunctionSet();
	set.functions = functions;
	set.location = loc;
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

