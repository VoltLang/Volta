/*#D*/
// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.util.util;

import watt.text.format : format;

import ir = volta.ir;

import volta.errors;
import volta.interfaces;
import volta.ir.location;
import volta.util.copy;
import volta.util.dup;
import volta.util.sinks;
import volta.util.string : unescapeString;


/*!
 * Builds an identifier exp from a string.
 */
ir.IdentifierExp buildIdentifierExp(ref in Location loc, string value, bool isGlobal = false)
{
	auto iexp = new ir.IdentifierExp(value);
	iexp.loc = loc;
	iexp.globalLookup = isGlobal;
	return iexp;
}

/*!
 * Builds a QualifiedName from an array.
 */
ir.QualifiedName buildQualifiedName(ref in Location loc, scope string[] value...)
{
	auto idents = new ir.Identifier[](value.length);
	foreach (i, val; value) {
		idents[i] = new ir.Identifier(val);
		idents[i].loc = loc;
	}

	auto q = new ir.QualifiedName();
	q.identifiers = idents;
	q.loc = loc;
	return q;
}

/*!
 * Builds a QualifiedName from a Identifier.
 */
ir.QualifiedName buildQualifiedNameSmart(ir.Identifier i)
{
	auto q = new ir.QualifiedName();
	q.identifiers = [new ir.Identifier(i)];
	q.loc = i.loc;
	return q;
}

/*!
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

/*!
 * For the given store get the scope that it introduces.
 *
 * Returns null for Values and non-scope types.
 */
ir.Scope getScopeFromStore(ir.Store store)
{
	final switch(store.kind) with (ir.Store.Kind) {
	case MultiScope:
		return new ir.Scope(store.scopes);
	case Scope:
		return store.myScope;
	case Type:
		auto type = cast(ir.Type)store.node;
		assert(type !is null);
		return getScopeFromType(type);
	case TemplateInstance:
	case Value:
	case Function:
	case FunctionParam:
	case Template:
	case EnumDeclaration:
	case Merge:
	case Alias:
	case Reserved:
		return null;
	}
}

/*!
 * Does a smart copy of a type.
 *
 * A smart copy is one in which all types are copied, but
 * TypeReferences are skipped, and TypeReferences are inserted
 * if we encounter a named type.
 */
ir.Type copyTypeSmart(ref in Location loc, ir.Type type)
{
	assert(type !is null);
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
		pt = new ir.PointerType(copyTypeSmart(/*#ref*/loc, pt.base));
		pt.loc = loc;
		outType = pt;
		break;
	case ArrayType:
		auto at = cast(ir.ArrayType)type;
		at = new ir.ArrayType(copyTypeSmart(/*#ref*/loc, at.base));
		at.loc = loc;
		outType = at;
		break;
	case StaticArrayType:
		auto asSat = cast(ir.StaticArrayType)type;
		auto sat = new ir.StaticArrayType();
		sat.loc = loc;
		sat.base = copyTypeSmart(/*#ref*/loc, asSat.base);
		sat.length = asSat.length;
		outType = sat;
		break;
	case AAType:
		auto asAA = cast(ir.AAType)type;
		auto aa = new ir.AAType();
		aa.loc = loc;
		aa.value = copyTypeSmart(/*#ref*/loc, asAA.value);
		aa.key = copyTypeSmart(/*#ref*/loc, asAA.key);
		outType = aa;
		break;
	case FunctionType:
		auto asFt = cast(ir.FunctionType)type;
		auto ft = new ir.FunctionType(asFt);
		ft.loc = loc;
		ft.ret = copyTypeSmart(/*#ref*/loc, ft.ret);
		foreach (i, ref t; ft.params) {
			t = copyTypeSmart(/*#ref*/loc, t);
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
		dgt.ret = copyTypeSmart(/*#ref*/loc, dgt.ret);
		foreach (i, ref t; dgt.params) {
			t = copyTypeSmart(/*#ref*/loc, t);
		}
		outType = dgt;
		break;
	case StorageType:
		auto asSt = cast(ir.StorageType)type;
		auto st = new ir.StorageType();
		st.loc = loc;
		if (asSt.base !is null) st.base = copyTypeSmart(/*#ref*/loc, asSt.base);
		st.type = asSt.type;
		outType = st;
		break;
	case AutoType:
		auto asAt = cast(ir.AutoType)type;
		auto at = new ir.AutoType();
		at.loc = loc;
		if (asAt.explicitType !is null) {
			at.explicitType = copyTypeSmart(/*#ref*/loc, asAt.explicitType);
		}
		outType = at;
		break;
	case TypeReference:
		auto tr = cast(ir.TypeReference)type;
		assert(tr.type !is null);
		outType = copyTypeSmart(/*#ref*/loc, tr.type);
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
		outType = buildTypeReference(/*#ref*/loc, type, s !is null ? s.name : null);
		break;
	default:
		assert(false);
	}
	addStorage(outType, type);
	return outType;
}

ir.TypeReference buildTypeReference(ref in Location loc, ir.Type type, scope string[] names...)
{
	auto tr = new ir.TypeReference();
	tr.loc = loc;
	tr.type = type;
	tr.id = buildQualifiedName(/*#ref*/loc, names);
	return tr;
}

ir.TypeReference buildTypeReference(ref in Location loc, ir.Type type, ir.QualifiedName id)
{
	auto tr = new ir.TypeReference();
	tr.loc = loc;
	tr.type = type;
	tr.id = id;
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

/*!
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
	array.base = copyTypeSmart(/*#ref*/loc, base);
	return array;
}

ir.PrimitiveType buildVoid(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Void); }
ir.PrimitiveType buildBool(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Bool); }
ir.PrimitiveType buildChar(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Char); }
ir.PrimitiveType buildDchar(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Dchar); }
ir.PrimitiveType buildWchar(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Wchar); }
ir.PrimitiveType buildByte(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Byte); }
ir.PrimitiveType buildUbyte(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Ubyte); }
ir.PrimitiveType buildShort(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Short); }
ir.PrimitiveType buildUshort(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Ushort); }
ir.PrimitiveType buildInt(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Int); }
ir.PrimitiveType buildUint(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Uint); }
ir.PrimitiveType buildLong(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Long); }
ir.PrimitiveType buildUlong(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Ulong); }
ir.PrimitiveType buildFloat(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Float); }
ir.PrimitiveType buildDouble(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Double); }
ir.PrimitiveType buildReal(ref in Location loc) { return buildPrimitiveType(/*#ref*/loc, ir.PrimitiveType.Kind.Real); }

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

/*!
 * Build a string (immutable(char)[]) type.
 */
ir.ArrayType buildString(ref in Location loc)
{
	auto c = buildChar(/*#ref*/loc);
	c.isImmutable = true;
	c.glossedName = "string"; // For readability.
	return buildArrayType(/*#ref*/loc, c);
}

ir.ArrayType buildStringArray(ref in Location loc)
{
	return buildArrayType(/*#ref*/loc, buildString(/*#ref*/loc));
}


/*!
 * Build a void* type.
 */
ir.PointerType buildVoidPtr(ref in Location loc)
{
	auto pt = new ir.PointerType(buildVoid(/*#ref*/loc));
	pt.loc = loc;

	return pt;
}

/*!
 * Build a void[] type.
 */
ir.ArrayType buildVoidArray(ref in Location loc)
{
	auto at = new ir.ArrayType(buildVoid(/*#ref*/loc));
	at.loc = loc;

	return at;
}

ir.PointerType buildPtrSmart(ref in Location loc, ir.Type base)
{
	auto pt = new ir.PointerType(copyTypeSmart(/*#ref*/loc, base));
	pt.loc = loc;

	return pt;
}

ir.PointerType buildPtr(ref in Location loc, ir.Type base)
{
	auto pt = new ir.PointerType(base);
	pt.loc = loc;

	return pt;
}

ir.ArrayLiteral buildArrayLiteralSmart(ref in Location loc, ir.Type type, scope ir.Exp[] exps...)
{
	auto literal = new ir.ArrayLiteral();
	literal.loc = loc;
	literal.type = copyTypeSmart(/*#ref*/loc, type);
	literal.exps = exps.dup();
	return literal;
}

ir.StructLiteral buildStructLiteralSmart(ref in Location loc, ir.Type type, scope ir.Exp[] exps...)
{
	auto literal = new ir.StructLiteral();
	literal.loc = loc;
	literal.type = copyTypeSmart(/*#ref*/loc, type);
	literal.exps = exps.dup();
	return literal;
}

ir.UnionLiteral buildUnionLiteralSmart(ref in Location loc, ir.Type type, scope ir.Exp[] exps...)
{
	auto literal = new ir.UnionLiteral();
	literal.loc = loc;
	literal.type = copyTypeSmart(/*#ref*/loc, type);
	literal.exps = exps.dup();
	return literal;
}

/*!
 * Add a Variable to the BlockStatement scope and either to
 * its statement or if StatementExp given to it instead.
 */
void addVariable(ErrorSink errSink, ir.BlockStatement b, ir.StatementExp statExp, ir.Variable var)
{
	ir.Status status;
	b.myScope.addValue(var, var.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, /*#ref*/b.loc, "value redefinition");
		assert(false);
	}
	if (statExp !is null) {
		statExp.statements ~= var;
	} else {
		b.statements ~= var;
	}
}

/*!
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

/*!
 * Build a Variable with an anon. name and insert it into the BlockStatement
 * or StatementExp if given. Note even if you want the Variable to end up in
 * the StatementExp you must give it the BlockStatement that the StatementExp
 * lives in as the variable will be added to its scope and generated a uniqe
 * name from its context.
 */
ir.Variable buildVariableAnonSmart(ErrorSink errSink, ref in Location loc, ir.BlockStatement b,
                                   ir.StatementExp statExp,
                                   ir.Type type, ir.Exp assign)
{
	assert(b !is null);
	assert(b.myScope !is null);
	auto name = b.myScope.genAnonIdent();
	auto var = buildVariable(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, type), ir.Variable.Storage.Function, name, assign);
	addVariable(errSink, b, statExp, var);
	return var;
}

//! Build a variable and add it to the top of a block statement.
ir.Variable buildVariableAnonSmartAtTop(ErrorSink errSink, ref in Location loc, ir.BlockStatement b,
                                   ir.Type type, ir.Exp assign)
{
	assert(b !is null);
	assert(b.myScope !is null);
	auto name = b.myScope.genAnonIdent();
	auto var = buildVariable(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, type), ir.Variable.Storage.Function, name, assign);
	b.statements = var ~ b.statements;
	ir.Status status;
	b.myScope.addValue(var, var.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, /*#ref*/loc, "value redefinition");
		assert(false);
	}
	return var;
}


/*!
 * Create an anonymous variable for a statementexp without a block statement.
 */
ir.Variable buildVariableAnonSmart(ErrorSink errSink, ref in Location loc, ir.Scope current,
                                   ir.StatementExp statExp,
                                   ir.Type type, ir.Exp assign)
{
	auto name = current.genAnonIdent();
	auto var = buildVariable(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, type), ir.Variable.Storage.Function, name, assign);
	ir.Status status;
	current.addValue(var, var.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, /*#ref*/loc, "value redefinition");
	}
	statExp.statements ~= var;
	return var;
}

/*!
 * Copy a Variable, while being smart about its type, does
 * not copy the the assign exp on the Variable.
 */
ir.Variable copyVariableSmart(ref in Location loc, ir.Variable right)
{
	return buildVariable(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, right.type), right.storage, right.name);
}

ir.Variable[] copyVariablesSmart(ref in Location loc, ir.Variable[] vars)
{
	auto outVars = new ir.Variable[](vars.length);
	foreach (i, var; vars) {
		outVars[i] = copyVariableSmart(/*#ref*/loc, var);
	}
	return outVars;
}

/*!
 * Get ExpReferences from a list of variables.
 */
ir.Exp[] getExpRefs(ref in Location loc, ir.FunctionParam[] vars)
{
	auto erefs = new ir.Exp[](vars.length);
	foreach (i, var; vars) {
		erefs[i] = buildExpReference(/*#ref*/loc, var, var.name);
	}
	return erefs;
}

/*!
 * Build a Variable, while being smart about its type.
 */
ir.Variable buildVariableSmart(ref in Location loc, ir.Type type, ir.Variable.Storage st, string name)
{
	return buildVariable(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, type), st, name);
}

/*!
 * Builds a usable ExpReference.
 */
ir.ExpReference buildExpReference(ref in Location loc, ir.Declaration decl, scope string[] names...)
{
	auto varRef = new ir.ExpReference();
	varRef.loc = loc;
	varRef.decl = decl;
	varRef.idents = names.dup();  // @todo if this is `~= names;`, PrettyPrinter output is corrupt.

	return varRef;
}

ir.ExpReference buildExpReference(ref in Location loc, ir.Function func)
{
	return buildExpReference(/*#ref*/loc, func, func.name);
}

/*!
 * Builds a constant double.
 */
ir.Constant buildConstantDouble(ref in Location loc, double value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._double = value;
	c.type = buildDouble(/*#ref*/loc);

	return c;
}

/*!
 * Builds a constant float.
 */
ir.Constant buildConstantFloat(ref in Location loc, float value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._float = value;
	c.type = buildFloat(/*#ref*/loc);

	return c;
}

/*!
 * Builds a constant int.
 */
ir.Constant buildConstantInt(ref in Location loc, int value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._int = value;
	c.type = buildInt(/*#ref*/loc);

	return c;
}

ir.Constant buildConstantUint(ref in Location loc, uint value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._uint = value;
	c.type = buildUint(/*#ref*/loc);

	return c;
}

ir.Constant buildConstantLong(ref in Location loc, long value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._long = value;
	c.type = buildLong(/*#ref*/loc);

	return c;
}

ir.Constant buildConstantUlong(ref in Location loc, ulong value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._ulong = value;
	c.type = buildUlong(/*#ref*/loc);

	return c;
}

ir.Constant buildConstantByte(ref in Location loc, byte value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._byte = value;
	c.type = buildByte(/*#ref*/loc);

	return c;
}

ir.Constant buildConstantUbyte(ref in Location loc, ubyte value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._ubyte = value;
	c.type = buildUbyte(/*#ref*/loc);

	return c;
}

ir.Constant buildConstantShort(ref in Location loc, short value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._short = value;
	c.type = buildShort(/*#ref*/loc);

	return c;
}

ir.Constant buildConstantUshort(ref in Location loc, ushort value)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._ushort = value;
	c.type = buildUshort(/*#ref*/loc);

	return c;
}
/*!
 * Builds a constant bool.
 */
ir.Constant buildConstantBool(ref in Location loc, bool val)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._bool = val;
	c.type = buildBool(/*#ref*/loc);

	return c;
}

ir.Constant buildConstantNull(ref in Location loc, ir.Type base)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c.u._pointer = null;
	c.type = copyTypeSmart(/*#ref*/loc, base);
	c.type.loc = loc;
	c.isNull = true;
	return c;
}

/*!
 * Gets a size_t Constant and fills it with a value.
 */
ir.Constant buildConstantSizeT(ref in Location loc, TargetInfo target, size_t val)
{
	auto c = new ir.Constant();
	c.loc = loc;
	auto prim = buildSizeT(/*#ref*/loc, target);
	// Uh, I assume just c._uint = val would work, but I can't test it here, so just be safe.
	if (prim.type == ir.PrimitiveType.Kind.Ulong) {
		c.u._ulong = cast(ulong)val;
	} else {
		c.u._uint = cast(uint)val;
	}
	c.type = prim;
	return c;
}

/*!
 * Builds a constant string.
 */
ir.Constant buildConstantString(ErrorSink errSink, ref in Location loc, string val, bool escape = true)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c._string = val;
	auto atype = buildArrayType(/*#ref*/loc, buildChar(/*#ref*/loc));
	atype.base.isImmutable = true;
	c.type = atype;
	if (escape) {
		c.arrayData = unescapeString(errSink, /*#ref*/loc, c._string);
	} else {
		c.arrayData = cast(immutable(void)[]) c._string;
	}
	return c;
}

ir.Constant buildConstantStringNoEscape(ref in Location loc, string val)
{
	auto c = new ir.Constant();
	c.loc = loc;
	c._string = val;
	auto atype = buildArrayType(/*#ref*/loc, buildChar(/*#ref*/loc));
	atype.base.isImmutable = true;
	c.type = atype;
	c.arrayData = cast(immutable(void)[]) c._string;
	return c;
}


/*!
 * Builds a constant 'c' string.
 */
ir.Exp buildConstantCString(ErrorSink errSink, ref in Location loc, string val, bool escape = true)
{
	return buildArrayPtr(/*#ref*/loc, buildChar(/*#ref*/loc),
	                     buildConstantString(errSink, /*#ref*/loc, val, escape));
}

/*!
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
	c.type = copyTypeSmart(/*#ref*/loc, ed.type);

	return c;
}

ir.EnumDeclaration buildEnumDeclaration(ref in Location loc, ir.Type type, ir.Exp assign, string name)
{
	auto ed = new ir.EnumDeclaration();
	ed.loc = loc;
	ed.type = type;
	ed.assign = copyExp(assign);
	ed.name = name;
	return ed;
}

ir.Constant buildConstantTrue(ref in Location loc) { return buildConstantBool(/*#ref*/loc, true); }
ir.Constant buildConstantFalse(ref in Location loc) { return buildConstantBool(/*#ref*/loc, false); }

/*!
 * Build a cast and sets the loc, does not call copyTypeSmart.
 */
ir.Unary buildCast(ref in Location loc, ir.Type type, ir.Exp exp)
{
	auto cst = new ir.Unary(type, exp);
	cst.loc = loc;
	return cst;
}

/*!
 * Build a cast, sets the loc and calling copyTypeSmart
 * on the type, to avoid duplicate nodes.
 */
ir.Unary buildCastSmart(ref in Location loc, ir.Type type, ir.Exp exp)
{
	return buildCast(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, type), exp);
}

ir.Unary buildCastToBool(ref in Location loc, ir.Exp exp) { return buildCast(/*#ref*/loc, buildBool(/*#ref*/loc), exp); }
ir.Unary buildCastToVoidPtr(ref in Location loc, ir.Exp exp) { return buildCast(/*#ref*/loc, buildVoidPtr(/*#ref*/loc), exp); }

/*!
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

/*!
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

/*!
 * Builds a ExpReference and a AddrOf from a Variable.
 */
ir.Unary buildAddrOf(ref in Location loc, ir.Variable var, scope string[] names...)
{
	return buildAddrOf(/*#ref*/loc, buildExpReference(/*#ref*/loc, var, names));
}

/*!
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

/*!
 * Builds an expression that dereferences a variable.
 */
ir.Unary buildDeref(ref in Location loc, ir.Variable var)
{
	auto eref = buildExpReference(/*#ref*/loc, var, var.name);
	return buildDeref(/*#ref*/loc, eref);
}

/*!
 * Builds a New expression.
 */
ir.Unary buildNew(ref in Location loc, ir.Type type, string name, scope ir.Exp[] arguments...)
{
	auto new_ = new ir.Unary();
	new_.loc = loc;
	new_.op = ir.Unary.Op.New;
	new_.type = buildTypeReference(/*#ref*/loc, type, name);
	new_.hasArgumentList = arguments.length > 0;
	new_.argumentList = arguments.dup();
	return new_;
}

ir.Unary buildNewSmart(ref in Location loc, ir.Type type, scope ir.Exp[] arguments...)
{
	auto new_ = new ir.Unary();
	new_.loc = loc;
	new_.op = ir.Unary.Op.New;
 	new_.type = copyTypeSmart(/*#ref*/loc, type);
	new_.hasArgumentList = arguments.length > 0;
	new_.argumentList = arguments.dup();
	return new_;
}

/*!
 * Builds a typeid with type smartly.
 */
ir.Typeid buildTypeidSmart(ref in Location loc, ir.Type type)
{
	auto t = new ir.Typeid();
	t.loc = loc;
	t.type = copyTypeSmart(/*#ref*/loc, type);
	return t;
}

/*!
 * Build a typeid casting if needed.
 */
ir.Exp buildTypeidSmart(ref in Location loc, ir.Class typeInfoClass, ir.Type type)
{
	return buildCastSmart(/*#ref*/loc, typeInfoClass, buildTypeidSmart(/*#ref*/loc, type));
}

/*!
 * Builds a BuiltinExp of ArrayPtr type. Make sure the type you
 * pass in is the base of the array and that the child exp is
 * not a pointer to an array.
 */
ir.BuiltinExp buildArrayPtr(ref in Location loc, ir.Type base, ir.Exp child)
{
	auto ptr = buildPtrSmart(/*#ref*/loc, base);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.ArrayPtr, ptr, [child]);
	builtin.loc = loc;

	return builtin;
}

/*!
 * Builds a BuiltinExp of BuildVtable type.
 */
ir.BuiltinExp buildBuildVtable(ref in Location loc, ir.Type type, ir.Class _class, FunctionSink functionSink)
{
	auto builtin = new ir.BuiltinExp(ir.BuiltinExp.Kind.BuildVtable, copyTypeSmart(/*#ref*/loc, type), _class, /*#ref*/functionSink);
	builtin.loc = loc;

	return builtin;
}

/*!
 * Builds a BuiltinExp of EnumMembers type.
 */
ir.BuiltinExp buildEnumMembers(ref in Location loc, ir.Enum _enum, ir.Exp enumRef, ir.Exp sinkRef)
{
	auto builtin = new ir.BuiltinExp(ir.BuiltinExp.Kind.EnumMembers, buildVoid(/*#ref*/loc), [enumRef, sinkRef]);
	builtin.loc = loc;
	builtin._enum = _enum;

	return builtin;
}

/*!
 * Builds a BuiltinExp of ArrayLength type. Make sure the child exp is
 * not a pointer to an array.
 */
ir.BuiltinExp buildArrayLength(ref in Location loc, TargetInfo target, ir.Exp child)
{
	auto st = buildSizeT(/*#ref*/loc, target);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.ArrayLength, st, [child]);
	builtin.loc = loc;

	return builtin;
}

/*!
 * Builds an ArrayDup BuiltinExp.
 */
ir.BuiltinExp buildArrayDup(ref in Location loc, ir.Type t, ir.Exp[] children)
{
	auto bi = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.ArrayDup, copyTypeSmart(/*#ref*/loc, t), children);
	bi.loc = loc;
	return bi;
}

/*!
 * Builds a BuiltinExp of AALength type.
 */
ir.BuiltinExp buildAALength(ref in Location loc, TargetInfo target, ir.Exp[] child)
{
	auto st = buildSizeT(/*#ref*/loc, target);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AALength, st, child);
	builtin.loc = loc;

	return builtin;
}

/*!
 * Builds a BuiltinExp of AAKeys type.
 */
ir.BuiltinExp buildAAKeys(ref in Location loc, ir.AAType aa, ir.Exp[] child)
{
	auto st = buildArrayTypeSmart(/*#ref*/loc, aa.key);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AAKeys, st, child);
	builtin.loc = loc;

	return builtin;
}

/*!
 * Builds a BuiltinExp of AAValues type.
 */
ir.BuiltinExp buildAAValues(ref in Location loc, ir.AAType aa, ir.Exp[] child)
{
	auto st = buildArrayTypeSmart(/*#ref*/loc, aa.value);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AAValues, st, child);
	builtin.loc = loc;

	return builtin;
}

/*!
 * Builds a BuiltinExp of AARehash type.
 */
ir.BuiltinExp buildAARehash(ref in Location loc, ir.Exp[] child)
{
	auto st = buildVoid(/*#ref*/loc);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AAValues, st, child);
	builtin.loc = loc;

	return builtin;
}

/*!
 * Builds a BuiltinExp of AAGet type.
 */
ir.BuiltinExp buildAAGet(ref in Location loc, ir.AAType aa, ir.Exp[] child)
{
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AAGet, copyTypeSmart(/*#ref*/loc, aa.value), child);
	builtin.loc = loc;
	return builtin;
}

/*!
 * Builds a BuiltinExp of AARemove type.
 */
ir.BuiltinExp buildAARemove(ref in Location loc, ir.Exp[] child)
{
	auto st = buildBool(/*#ref*/loc);
	auto builtin = new ir.BuiltinExp(
		ir.BuiltinExp.Kind.AARemove, st, child);
	builtin.loc = loc;

	return builtin;
}


/*!
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


/*!
 * Builds a BuiltinExp of Classinfo type.
 */
ir.BuiltinExp buildClassinfo(ref in Location loc, ir.Type type, ir.Exp child)
{
	auto kind = ir.BuiltinExp.Kind.Classinfo;
	auto builtin = new ir.BuiltinExp(kind, type, [child]);
	builtin.loc = loc;
	return builtin;
}


/*!
 * Builds a BuiltinExp of AARemove type.
 */
ir.BuiltinExp buildAAIn(ref in Location loc, ir.AAType aa, ir.Exp[] child)
{
	auto p = buildPtrSmart(/*#ref*/loc, aa.value);
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.AAIn, p, child);
	bi.loc = loc;
	return bi;
}

/*!
 * Builds a BuiltinExp of AADup type.
 */
ir.BuiltinExp buildAADup(ref in Location loc, ir.AAType aa, ir.Exp[] child)
{
	auto p = copyTypeSmart(/*#ref*/loc, aa);
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.AADup, p, child);
	bi.loc = loc;
	return bi;
}

/*!
 * Builds a BuiltinExp of PODCtor type.
 */
ir.BuiltinExp buildPODCtor(ref in Location loc, ir.PODAggregate pod, ir.Postfix postfix, ir.Function ctor)
{
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.PODCtor, copyTypeSmart(/*#ref*/loc, pod), [cast(ir.Exp)postfix]);
	bi.functions ~= ctor;
	bi.loc = loc;
	return bi;
}

/*!
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

/*!
 * Builds a chain of postfix lookups from a QualifiedName.
 * These are only useful before the extyper runs.
 */
ir.Postfix buildPostfixIdentifier(ref in Location loc, ir.QualifiedName qname, string name)
{
	ir.Exp current = buildIdentifierExp(/*#ref*/loc, qname.identifiers[0].value);
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
	return buildPostfixIdentifier(/*#ref*/loc, current, name);
}

/*!
 * Builds a postfix slice.
 */
ir.Postfix buildSlice(ref in Location loc, ir.Exp child, scope ir.Exp[] args...)
{
	auto slice = new ir.Postfix();
	slice.loc = loc;
	slice.op = ir.Postfix.Op.Slice;
	slice.child = child;
	slice.arguments = args.dup();

	return slice;
}

/*!
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

/*!
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

/*!
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

/*!
 * Builds a postfix call.
 */
ir.Postfix buildCall(ref in Location loc, ir.Exp child, ir.Exp[] args)
{
	auto call = new ir.Postfix();
	call.loc = loc;
	call.op = ir.Postfix.Op.Call;
	call.child = child;
	call.arguments = args.dup();

	return call;
}

/*!
 * Builds a call to a function.
 */
ir.Postfix buildCall(ref in Location loc, ir.Function func, ir.Exp[] args)
{
	auto eref = buildExpReference(/*#ref*/loc, func, func.name);
	return buildCall(/*#ref*/loc, eref, args);
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

/*!
 * Builds a postfix call.
 */
ir.Postfix buildCall(ref in Location loc, ir.Declaration decl, ir.Exp[] args, scope string[] names...)
{
	return buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, decl, names), args);
}

/*!
 * Builds an add BinOp.
 */
ir.BinOp buildAdd(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.Add, left, right);
}

/*!
 * Builds a subtraction BinOp.
 */
ir.BinOp buildSub(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.Sub, left, right);
}

/*!
 * Builds a multiplication BinOp.
 */ 
ir.BinOp buildMul(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul, left, right);
}

/*!
 * Builds a division BinOp.
 */ 
ir.BinOp buildDiv(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.Div, left, right);
}

/*!
 * Builds a modulo BinOp.
 */
ir.BinOp buildMod(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mod, left, right);
}

/*!
 * Builds a bitwise and Binop
 */
ir.BinOp buildAnd(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.And, left, right);
}

/*!
 * Builds a bitwise or Binop
 */
ir.BinOp buildOr(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.Or, left, right);
}

/*!
 * Builds a bitwise xor binop.
 */
ir.BinOp buildXor(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.Xor, left, right);
}

/*!
 * Builds a concatenate BinOp.
 */
ir.BinOp buildCat(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.Cat, left, right);
}

/*!
 * Builds a LS BinOp.
 */
ir.BinOp buildLS(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.LS, left, right);
}

/*!
 * Builds a SRS BinOp.
 */
ir.BinOp buildSRS(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.SRS, left, right);
}

/*!
 * Builds an RS BinOp.
 */
ir.BinOp buildRS(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.RS, left, right);
}

/*!
 * Builds a Pow BinOp.
 */
ir.BinOp buildPow(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.Pow, left, right);
}

/*!
 * Builds an assign BinOp.
 */
ir.BinOp buildAssign(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.Assign, left, right);
}

/*!
 * Builds an assign BinOp to a given variable.
 */
ir.BinOp buildAssign(ref in Location loc, ir.Variable left, ir.Exp right)
{
	auto eref = buildExpReference(/*#ref*/loc, left, left.name);
	return buildAssign(/*#ref*/loc, eref, right);
}

/*!
 * Builds an assign BinOp to a given variable from a given variable.
 */
ir.BinOp buildAssign(ref in Location loc, ir.Variable left, ir.Variable right)
{
	auto lref = buildExpReference(/*#ref*/loc, left, left.name);
	auto rref = buildExpReference(/*#ref*/loc, right, right.name);
	return buildAssign(/*#ref*/loc, lref, rref);
}

/*!
 * Builds an add-assign BinOp.
 */
ir.BinOp buildAddAssign(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.AddAssign, left, right);
}

/*!
 * Builds a cat-assign BinOp.
 */
ir.BinOp buildCatAssign(ref in Location loc, ir.Exp left, ir.Exp right)
{
	return buildBinOp(/*#ref*/loc, ir.BinOp.Op.CatAssign, left, right);
}

/*!
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
	auto stateExp = buildStatementExp(/*#ref*/loc);
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

/*!
 * Adds a variable argument to a function, also adds it to the scope.
 */
ir.FunctionParam addParam(ErrorSink errSink, ref in Location loc, ir.Function func, ir.Type type, string name)
{
	auto var = buildFunctionParam(/*#ref*/loc, func.type.params.length, name, func);

	func.type.params ~= type;
	func.type.isArgOut ~= false;
	func.type.isArgRef ~= false;

	func.params ~= var;
	ir.Status status;
	func.myScope.addValue(var, name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, /*#ref*/loc, "value redefinition");
		assert(false);
	}
	return var;
}

/*!
 * Adds a variable argument to a function, also adds it to the scope.
 */
ir.FunctionParam addParamSmart(ErrorSink errSink, ref in Location loc, ir.Function func, ir.Type type, string name)
{
	return addParam(errSink, /*#ref*/loc, func, copyTypeSmart(/*#ref*/loc, type), name);
}

/*!
 * Builds a variable statement smartly, inserting at the end of the
 * block statements and inserting it in the scope.
 */
ir.Variable buildVarStatSmart(ErrorSink errSink, ref in Location loc, ir.BlockStatement block, ir.Scope _scope, ir.Type type, string name)
{
	auto var = buildVariableSmart(/*#ref*/loc, type, ir.Variable.Storage.Function, name);
	block.statements ~= var;
	ir.Status status;
	_scope.addValue(var, name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, /*#ref*/loc, "value redefinition");
		assert(false);
	}
	return var;
}

/*!
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
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.VaStart, buildVoid(/*#ref*/loc), [vlexp, argexp]);
	bi.loc = loc;
	return bi;
}

ir.BuiltinExp buildVaArgEnd(ref in Location loc, ir.Exp vlexp)
{
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.VaEnd, buildVoid(/*#ref*/loc), [vlexp]);
	bi.loc = loc;
	return bi;
}

ir.BuiltinExp buildVaArg(ref in Location loc, ir.VaArgExp vaexp)
{
	auto bi = new ir.BuiltinExp(ir.BuiltinExp.Kind.VaArg, copyType(vaexp.type), [cast(ir.Exp)vaexp]);
	bi.loc = loc;
	return bi;
}

/*!
 * Build a Ternary expression.
 */
ir.Ternary buildTernary(ref in Location loc, ir.Exp condition, ir.Exp l, ir.Exp r)
{
	auto te = new ir.Ternary();
	te.loc = loc;
	te.condition = condition;
	te.ifTrue = l;
	te.ifFalse = r;
	return te;
}

ir.StatementExp buildInternalArrayLiteralSmart(ErrorSink errSink, ref in Location loc, ir.Type atype, ir.Exp[] exps)
{
	if (atype.nodeType != ir.NodeType.ArrayType) {
		panic(errSink, atype, "must be array type");
		assert(false);
	}
	auto arr = cast(ir.ArrayType) atype;
	passert(errSink, atype, arr !is null);

	auto sexp = new ir.StatementExp();
	sexp.loc = loc;
	auto var = buildVariableSmart(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, atype), ir.Variable.Storage.Function, "array");
	sexp.statements ~= var;
	auto _new = buildNewSmart(/*#ref*/loc, atype, buildConstantUint(/*#ref*/loc, cast(uint) exps.length));
	auto vassign = buildAssign(/*#ref*/loc, buildExpReference(/*#ref*/loc, var), _new);
	buildExpStat(/*#ref*/loc, sexp, vassign);
	foreach (i, exp; exps) {
		auto slice = buildIndex(/*#ref*/loc, buildExpReference(/*#ref*/loc, var), buildConstantUint(/*#ref*/loc, cast(uint) i));
		auto assign = buildAssign(/*#ref*/loc, slice, buildCastSmart(arr.base, exp));
		buildExpStat(/*#ref*/loc, sexp, assign);
	}
	sexp.exp = buildExpReference(/*#ref*/loc, var, var.name);
	return sexp;
}

ir.StatementExp buildInternalStaticArrayLiteralSmart(ErrorSink errSink, ref in Location loc, ir.Type atype, ir.Exp[] exps)
{
	if (atype.nodeType != ir.NodeType.StaticArrayType) {
		panic(errSink, atype, "must be staticarray type");
		assert(false);
	}
	auto arr = cast(ir.StaticArrayType) atype;
	passert(errSink, atype, arr !is null);

	auto sexp = new ir.StatementExp();
	sexp.loc = loc;
	auto var = buildVariableSmart(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, atype), ir.Variable.Storage.Function, "sarray");
	sexp.statements ~= var;
	foreach (i, exp; exps) {
		auto l = buildIndex(/*#ref*/loc, buildExpReference(/*#ref*/loc, var), buildConstantUint(/*#ref*/loc, cast(uint) i));
		auto assign = buildAssign(/*#ref*/loc, l, buildCastSmart(arr.base, exp));
		buildExpStat(/*#ref*/loc, sexp, assign);
	}
	sexp.exp = buildExpReference(/*#ref*/loc, var, var.name);
	return sexp;
}

/*!
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

/*!
 * Build an exp statement without inserting it anywhere.
 */
ir.ExpStatement buildExpStat(ref in Location loc, ir.Exp exp)
{
	auto ret = new ir.ExpStatement();
	ret.loc = loc;
	ret.exp = exp;
	return ret;
}

/*!
 * Build a switch statement.
 */
ir.SwitchStatement buildSwitchStat(ref in Location loc, ir.Exp condition)
{
	auto ss = new ir.SwitchStatement();
	ss.loc = loc;
	ss.condition = condition;
	return ss;
}

/*!
 * Build a simple switch case.
 *
 * Does not build a block statement, only uses `firstExp`.
 */
ir.SwitchCase buildSwitchCase(ref in Location loc, ir.Exp caseExp)
{
	auto sc = new ir.SwitchCase();
	sc.loc = loc;
	sc.firstExp = caseExp;
	return sc;
}

/*!
 * Build an `assert(false)` statement.
 *
 * No message.
 */
ir.AssertStatement buildAssertFalse(ref in Location loc)
{
	auto as = new ir.AssertStatement();
	as.loc = loc;
	as.condition = buildConstantBool(/*#ref*/loc, false);
	return as;
}

/*!
 * Build a simple default switch case.
 *
 * Does not build a block statement.
 */
ir.SwitchCase buildSwitchDefault(ref in Location loc)
{
	auto sc = new ir.SwitchCase();
	sc.loc = loc;
	sc.isDefault = true;
	return sc;
}

/*!
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

/*!
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

/*!
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

/*!
 * Build a block statement.
 */
ir.BlockStatement buildBlockStat(ref in Location loc, ir.Node introducingNode, ir.Scope _scope, scope ir.Node[] statements...)
{
	auto ret = new ir.BlockStatement();
	ret.loc = loc;
	ret.statements = statements.dup();
	ret.myScope = new ir.Scope(_scope, introducingNode is null ? ret : introducingNode, "block", _scope.nestedDepth);

	return ret;
}


/*!
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

ir.FunctionType buildFunctionTypeSmart(ref in Location loc, ir.Type ret, scope ir.Type[] args...)
{
	auto type = new ir.FunctionType();
	type.loc = loc;
	type.ret = copyType(ret);
	type.params = new ir.Type[](args.length);
	type.isArgRef = new bool[](args.length);
	type.isArgOut = new bool[](args.length);
	foreach (i, arg; args) {
		type.params[i] = copyType(arg);
	}
	return type;
}

//! Builds a function without inserting it anywhere.
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
		func.parsedBody = new ir.BlockStatement();
		func.parsedBody.loc = loc;
		func.parsedBody.myScope = new ir.Scope(func.myScope, func.parsedBody, name, func.myScope.nestedDepth);
	}

	return func;
}

//! Builds a function with a given type.
ir.Function buildFunction(ref in Location loc, ir.Scope _scope, string name, ir.FunctionType ftype)
{
	auto func = new ir.Function();
	func.name = name;
	func.loc = loc;
	func.kind = ir.Function.Kind.Function;
	func.myScope = new ir.Scope(_scope, func, func.name, _scope.nestedDepth);

	func.type = ftype;

	func.parsedBody = new ir.BlockStatement();
	func.parsedBody.loc = loc;
	func.parsedBody.myScope = new ir.Scope(func.myScope, func.parsedBody, name, func.myScope.nestedDepth);

	return func;
}

/*!
 * Builds a completely useable Function and insert it into the
 * various places it needs to be inserted.
 */
ir.Function buildFunction(ErrorSink errSink, ref in Location loc, ir.TopLevelBlock tlb, ir.Scope _scope, string name, bool buildBody = true)
{
	auto func = buildFunction(/*#ref*/loc, _scope, name, buildBody);

	// Insert the struct into all the places.
	ir.Status status;
	_scope.addFunction(func, func.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, /*#ref*/loc, "function redefinition");
		assert(false);
	}
	tlb.nodes ~= func;
	return func;
}

ir.Function buildGlobalConstructor(ErrorSink errSink, ref in Location loc, ir.TopLevelBlock tlb, ir.Scope _scope, string name, bool buildBody = true)
{
	auto func = buildFunction(errSink, /*#ref*/loc, tlb, _scope, name, buildBody);
	func.kind = ir.Function.Kind.GlobalConstructor;
	return func;
}

/*!
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

/*!
 * Builds a alias from two strings.
 */
ir.Alias buildAlias(ref in Location loc, string name, string from)
{
	auto a = new ir.Alias();
	a.name = name;
	a.loc = loc;
	a.id = buildQualifiedName(/*#ref*/loc, from);
	return a;
}

/*!
 * Builds a completely useable struct and insert it into the
 * various places it needs to be inserted.
 *
 * The members list is used directly in the new struct; be wary not to duplicate IR nodes.
 */
ir.Struct buildStruct(ErrorSink errSink, ref in Location loc, ir.TopLevelBlock tlb, ir.Scope _scope, string name, scope ir.Variable[] members...)
{
	auto s = new ir.Struct();
	s.name = name;
	s.myScope = new ir.Scope(_scope, s, name, _scope.nestedDepth);
	s.loc = loc;

	s.members = new ir.TopLevelBlock();
	s.members.loc = loc;
	s.members.nodes = new ir.Node[](members.length);

	foreach (i, member; members) {
		s.members.nodes[i] = member;
		ir.Status status;

		/* In an ideal world, the caller would detect this error.
		 * However, we don't want to incur another AA memory/lookup 
		 * cost per struct/class, or a linear search, so it's cheaper
		 * to do it here.
		 */
		auto store = s.myScope.getStore(member.name);
		if (store !is null) {
			errorRedefine(errSink, /*#ref*/loc, /*#ref*/store.node.loc, member.name);
			return s;
		}

		s.myScope.addValue(member, member.name, /*#out*/status);
		if (status != ir.Status.Success) {
			panic(errSink, /*#ref*/loc, "value redefinition");
			assert(false);
		}
	}

	// Insert the struct into all the places.
	ir.Status status;
	_scope.addType(s, s.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink,/*#ref*/loc, "type redefinition");
		assert(false);
	}
	tlb.nodes ~= s;
	return s;
}

/*!
 * Builds an IR complete, but semantically unfinished struct. i.e. it has no scope and isn't inserted anywhere.
 * The members list is used directly in the new struct; be wary not to duplicate IR nodes.
 */
ir.Struct buildStruct(ref in Location loc, string name, scope ir.Variable[] members...)
{
	auto s = new ir.Struct();
	s.name = name;
	s.loc = loc;

	s.members = new ir.TopLevelBlock();
	s.members.loc = loc;
	s.members.nodes = new ir.Node[](members.length);

	foreach (i, member; members) {
		s.members.nodes[i] = member;
	}

	return s;
}

/*!
 * Add a variable to a pre-built struct.
 */
ir.Variable addVarToStructSmart(ErrorSink errSink, ir.Struct _struct, ir.Variable var)
{
	assert(var.name != "");
	auto cvar = buildVariableSmart(/*#ref*/var.loc, var.type, ir.Variable.Storage.Field, var.name);
	_struct.members.nodes ~= cvar;
	ir.Status status;
	_struct.myScope.addValue(cvar, cvar.name, /*#out*/status);
	if (status != ir.Status.Success) {
		panic(errSink, /*#ref*/cvar.loc, "value redefinition");
		assert(false);
	}
	return cvar;
}

/*!
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
	sat.base = copyTypeSmart(/*#ref*/loc, base);
	return sat;
}

ir.Type buildAATypeSmart(ref in Location loc, ir.Type key, ir.Type value)
{
	auto aa = new ir.AAType();
	aa.loc = loc;
	aa.key = copyTypeSmart(/*#ref*/loc, key);
	aa.value = copyTypeSmart(/*#ref*/loc, value);
	return aa;
}

/*
 * Functions who takes the loc from the given exp.
 */
ir.Unary buildCastSmart(ir.Type type, ir.Exp exp) { return buildCastSmart(/*#ref*/exp.loc, type, exp); }
ir.Unary buildAddrOf(ir.Exp exp) { return buildAddrOf(/*#ref*/exp.loc, exp); }
ir.Unary buildCastToBool(ir.Exp exp) { return buildCastToBool(/*#ref*/exp.loc, exp); }

ir.Type buildSetType(ref in Location loc, ir.Function[] functions)
{
	assert(functions.length > 0);
	if (functions.length == 1) {
		return functions[0].type;
	}

	auto set = new ir.FunctionSetType();
	set.loc = loc;
	set.set = cast(ir.FunctionSet)buildSet(/*#ref*/loc, functions);
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

//! Returns the base of consecutive pointers. e.g. 'int***' returns 'int'.
ir.Type realBase(ir.PointerType ptr)
{
	ir.Type base;
	do {
		base = ptr.base;
		ptr = cast(ir.PointerType) base;
	} while (ptr !is null);
	return base;
}

//! Build a with statement that has no block.
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

//! Build a simple index for loop. for (i = 0; i < length; ++i)
void buildForStatement(ref in Location loc, TargetInfo target, ir.Scope parent, ir.Exp length, out ir.ForStatement forStatement, out ir.Variable ivar)
{
	forStatement = new ir.ForStatement();
	forStatement.loc = loc;

	ivar = buildVariable(/*#ref*/loc, buildSizeT(/*#ref*/loc, target),
		ir.Variable.Storage.Function, "i", buildConstantSizeT(/*#ref*/loc, target, 0));
	forStatement.initVars ~= ivar;
	forStatement.test = buildBinOp(/*#ref*/loc, ir.BinOp.Op.Less, buildExpReference(/*#ref*/loc, ivar, ivar.name), copyExp(length));
	forStatement.increments ~= buildIncrement(/*#ref*/loc, buildExpReference(/*#ref*/loc, ivar, ivar.name));
	forStatement.block = buildBlockStat(/*#ref*/loc, forStatement, parent);
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
	assert(named is null);
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

ir.StoreExp buildStoreExp(ref in Location loc, ir.Store store, scope string[] idents...)
{
	auto sexp = new ir.StoreExp();
	sexp.loc = loc;
	sexp.store = store;
	sexp.idents = idents.dup();
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

ir.NullType buildNullType(ref in Location loc)
{
	auto nt = new ir.NullType();
	nt.loc = loc;
	return nt;
}

//! Build a cast to a TypeInfo.
ir.Exp buildTypeInfoCast(ir.Class typeInfoClass, ir.Exp e)
{
	return buildCastSmart(/*#ref*/e.loc, typeInfoClass, e);
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
