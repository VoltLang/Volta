// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.exptyper;

import std.conv : to;
import std.string : format;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.semantic.userresolver : scopeLookup;
import volt.semantic.lookup;

int size(ir.PrimitiveType.Kind kind)
{
	final switch (kind) with (ir.PrimitiveType.Kind) {
	case Void: return 1;
	case Bool: return 1;
	case Char: return 1;
	case Byte: return 1;
	case Ubyte: return 1;
	case Short: return 2;
	case Ushort: return 2;
	case Int: return 4;
	case Uint: return 4;
	case Long: return 8;
	case Ulong: return 8;
	case Float: return 4;
	case Double: return 8;
	case Real: return 8;
	}
}

bool isUnsigned(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
	case Void:
	case Byte:
	case Short:
	case Int:
	case Long:
	case Float:
	case Double:
	case Real:
		return false;
	default:
		return true;
	}
}

bool isOkayForPointerArithmetic(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
	case Byte:
	case Ubyte:
	case Short:
	case Ushort:
	case Int:
	case Uint:
	case Long:
	case Ulong:
		return true;
	default:
		return false;
	}
}

bool isIntegral(ir.PrimitiveType.Kind kind)
{
	switch (kind) with (ir.PrimitiveType.Kind) {
		case Byte:
		case Ubyte:
		case Short:
		case Ushort:
		case Int:
		case Uint:
		case Long:
		case Ulong:
			return true;
		default:
			return false;
	}
}

bool fitsInPrimitive(ir.PrimitiveType t, ir.Exp e)
{
	if (e.nodeType != ir.NodeType.Constant) {
		return false;
	}
	auto asConstant = cast(ir.Constant) e;
	assert(asConstant !is null);

	if (isIntegral(t.type)) {
		long l;
		try {
			l = to!long(asConstant.value);
		} catch (Throwable t) {
			return false;
		}
		switch (t.type) with (ir.PrimitiveType.Kind) {
		case Ubyte:
			return l >= ubyte.min && l <= ubyte.max;
		case Byte:
			return l >= byte.min && l <= byte.max;
		case Ushort:
			return l >= ushort.min && l <= ushort.max;
		case Short:
			return l >= short.min && l <= short.max;
		case Uint:
			return l >= uint.min && l <= uint.max;
		case Int:
			return l >= int.min && l <= int.max;
		case Long:
			return true;
		case Ulong:
			return false;
		case Float:
			return l >= float.min && l <= float.max;
		case Double:
			return l >= double.min && l <= double.max;
		default:
			return false;
		}
	} else {
		return false;
	}
}

/// Get the type from a Variable.
ir.Node declTypeLookup(ir.Scope _scope, string name, Location location)
{
	auto store = _scope.lookup(name);
	if (store is null) {
		throw new CompilerError(location, format("undefined identifier '%s'.", name));
	}
	if (store.kind == ir.Store.Kind.Function) {
		/// @todo Overloading.
		assert(store.functions.length == 1);
		return store.functions[0].type;
	}

	if (store.kind == ir.Store.Kind.Scope) {
		auto asMod = cast(ir.Module) store.s.node;
		assert(asMod !is null);
		return asMod;
	}

	auto d = cast(ir.Variable) store.node;
	if (d is null) {
		throw new CompilerError(location, format("%s used as value.", name));
	}
	return d.type;
}


/**
 * Determines whether the two given types are the same.
 *
 * Not similar. Not implicitly convertable. The _same_ type.
 * Returns: true if they're the same, false otherwise.
 */
bool typesEqual(ir.Type a, ir.Type b)
{
	if (a.nodeType == ir.NodeType.PrimitiveType &&
		b.nodeType == ir.NodeType.PrimitiveType) {
		auto ap = cast(ir.PrimitiveType) a;
		auto bp = cast(ir.PrimitiveType) b;
		assert(ap !is null && bp !is null);
		return ap.type == bp.type;
	} else if (a.nodeType == ir.NodeType.PointerType &&
			   b.nodeType == ir.NodeType.PointerType) {
		auto ap = cast(ir.PointerType) a;
		auto bp = cast(ir.PointerType) b;
		assert(ap !is null && bp !is null);
		return typesEqual(ap.base, bp.base);
	} else if (a.nodeType == ir.NodeType.ArrayType &&
			   b.nodeType == ir.NodeType.ArrayType) {
		auto ap = cast(ir.ArrayType) a;
		auto bp = cast(ir.ArrayType) b;
		assert(ap !is null && bp !is null);
		return typesEqual(ap.base, ap.base);
	} else if (a.nodeType == ir.NodeType.TypeReference &&
			   b.nodeType == ir.NodeType.TypeReference) {
		auto ap = cast(ir.TypeReference) a;
		auto bp = cast(ir.TypeReference) b;
		assert(ap !is null && bp !is null);
		return ap.names == bp.names;
	} else if (a.nodeType == ir.NodeType.FunctionType &&
			   b.nodeType == ir.NodeType.FunctionType) {
		auto ap = cast(ir.FunctionType) a;
		auto bp = cast(ir.FunctionType) b;
		assert(ap !is null && bp !is null);

		if (ap.params.length != bp.params.length)
			return false;
		auto ret = typesEqual(ap.ret, bp.ret);
		if (!ret)
			return false;
		for (int i; i < ap.params.length; i++)
			if (!typesEqual(ap.params[i].type, bp.params[i].type))
				return false;
		return true;
	} else if (a.nodeType == ir.NodeType.DelegateType &&
			   b.nodeType == ir.NodeType.DelegateType) {
		auto ap = cast(ir.DelegateType) a;
		auto bp = cast(ir.DelegateType) b;
		assert(ap !is null && bp !is null);

		if (ap.params.length != bp.params.length)
			return false;
		auto ret = typesEqual(ap.ret, bp.ret);
		if (!ret)
			return false;
		for (int i; i < ap.params.length; i++)
			if (!typesEqual(ap.params[i].type, bp.params[i].type))
				return false;
		return true;
	} else {
		return a is b;
	}
}

bool isComparison(ir.BinOp.Type t)
{
	switch (t) with (ir.BinOp.Type) {
	case OrOr, AndAnd, Equal, NotEqual, Is, NotIs, Less, LessEqual, Greater, GreaterEqual:
		return true;
	default:
		return false;
	}
}

bool isValidPointerArithmeticOperation(ir.BinOp.Type t)
{
	switch (t) with (ir.BinOp.Type) {
	case Add, Sub:
		return true;
	default:
		return false;
	}
}

/// Make implicit casts explicit.
class ExpTyper : ScopeManager, Pass
{
public:
	Settings settings;
	ir.Module _module;
	ir.Node[ir.Exp] subTypes;
	ir.Type functionRet;

public:
	this(Settings settings)
	{
		this.settings = settings;
	}

	/// Look up an identifier. Assumes struct parent. (!!!)
	ir.Node evaluatePostfixIdentifier(ir.Postfix asPostfix)
	{
		auto t = evaluate(asPostfix.child);

		if (t.nodeType == ir.NodeType.ArrayType) {
			auto asArray = cast(ir.ArrayType) t;
			assert(asArray !is null);
			switch (asPostfix.identifier.value) {
			case "length":
				return subTypes[asPostfix] = settings.getSizeT();
			case "ptr":
				return subTypes[asPostfix] = new ir.PointerType(asArray.base);
			default:
				throw new CompilerError(asPostfix.location, "arrays have length and ptr members only.");
			}
		}

		ir.Scope _scope;
		string emsg;
		if (t.nodeType == ir.NodeType.Module) {
			auto asModule = cast(ir.Module) t;
			assert(asModule !is null);
			_scope = asModule.myScope;
			emsg = format("module '%s' has no member '%s'.", asModule.name, asPostfix.identifier.value);
		} else if (t.nodeType == ir.NodeType.TypeReference) {
			auto asUser = cast(ir.TypeReference) t;
			auto asStruct = cast(ir.Struct) asUser.type;
			_scope = asStruct.myScope;
			emsg = format("type '%s' has no member '%s'.", asUser.names[$-1], asPostfix.identifier.value);
		} else {
			assert(false);
		}

		auto store = _scope.getStore(asPostfix.identifier.value);
		if (store is null) {
			throw new CompilerError(asPostfix.identifier.location, emsg);
		}

		if (store.kind == ir.Store.Kind.Value) {
			auto asDecl = cast(ir.Variable) store.node;
			assert(asDecl !is null);
			return subTypes[asPostfix] = asDecl.type;
		} else if (store.kind == ir.Store.Kind.Function) {
			return subTypes[asPostfix] = store.functions[$-1].type;  // !!!
		} else {
			throw CompilerPanic(asPostfix.location, "unhandled postfix type retrieval.");
		}
	}

	/// Modify a function call to have explicit casts and return the return type.
	ir.Node evaluatePostfixCall(ir.Postfix asPostfix)
	{
		auto t = evaluate(asPostfix.child);
		if (t.nodeType == ir.NodeType.TypeReference) {
			auto asTR = cast(ir.TypeReference) t;
			assert(asTR !is null);
			t = asTR.type;
		}

		auto asFunctionType = cast(ir.CallableType) t;
		assert(asFunctionType !is null);
		if (asPostfix.arguments.length != asFunctionType.params.length) {
			throw new CompilerError(asPostfix.location, "wrong number of arguments to function.");
		}
		foreach (i; 0 .. asPostfix.arguments.length) {
			extype(asFunctionType.params[i].type, asPostfix.arguments[i]);
		}
		return asFunctionType.ret;
	}

	ir.Node evaluatePostfixIncDec(ir.Postfix asPostfix)
	{
		auto t = evaluate(asPostfix.child);
		/// @todo check if value is LValue.

		if (t.nodeType == ir.NodeType.PointerType) {
			return t;
		} else if (t.nodeType == ir.NodeType.PrimitiveType &&
		           isOkayForPointerArithmetic((cast(ir.PrimitiveType)t).type)) {
			return t;
		}

		throw new CompilerError(asPostfix.location, "value not suited for increment/decrement");
	}

	ir.Node evaluatePostfixIndex(ir.Postfix asPostfix)
	{
		ir.ArrayType array;
		ir.PointerType pointer;

		auto t = evaluate(asPostfix.child);
		if (t.nodeType == ir.NodeType.PointerType) {
			pointer = cast(ir.PointerType) t;
			assert(pointer !is null);
		} else if (t.nodeType == ir.NodeType.ArrayType) {
			array = cast(ir.ArrayType) t;
			assert(array !is null);
		} else {
			throw CompilerPanic(asPostfix.location, "don't know how to index non pointers or non arrays.");
		}
		assert((pointer !is null && array is null) || (array !is null && pointer is null));

		return pointer is null ? array.base : pointer.base;
	}

	ir.Node evaluateNewExp(ir.Unary u)
	{
		assert(u.op == ir.Unary.Op.New);
		if (!u.isArray && !u.hasArgumentList) {
			return subTypes[u] = new ir.PointerType(u.type);
		} else if (u.isArray) {
			return subTypes[u] = new ir.ArrayType(u.type);
		} else {
			assert(u.hasArgumentList);
			return u.type;
		}
		assert(false);
	}

	/// Retrieve the type for e.
	ir.Node evaluate(ir.Exp e)
	{
		if (auto p = e in subTypes) {
			return *p;
		}

		switch (e.nodeType) with (ir.NodeType) {
			case Constant:
				auto asConstant = cast(ir.Constant) e;
				assert(asConstant !is null);
				return subTypes[e] = asConstant.type;
			case IdentifierExp:
				auto asIdentifierExp = cast(ir.IdentifierExp) e;
				assert(asIdentifierExp !is null);
				if (asIdentifierExp.type is null) {
					visit(asIdentifierExp);
				}
				assert(asIdentifierExp.type !is null);
				return subTypes[e] = asIdentifierExp.type;
			case BinOp:
				auto asBin = cast(ir.BinOp) e;
				assert(asBin !is null);
				return subTypes[e] = extype(asBin);
			case TypeReference:
				auto asUser = cast(ir.TypeReference) e;
				assert(asUser !is null);
				return subTypes[e] = asUser.type;
			case Variable:
				auto asDecl = cast(ir.Variable) e;
				assert(asDecl !is null);
				return subTypes[e] = asDecl.type;
			case Postfix:
				auto asPostfix = cast(ir.Postfix) e;
				assert(asPostfix !is null);
				if (asPostfix.op == ir.Postfix.Op.Identifier) {
					return evaluatePostfixIdentifier(asPostfix);
				} else if (asPostfix.op == ir.Postfix.Op.Call) {
					return evaluatePostfixCall(asPostfix);
				} else if (asPostfix.op == ir.Postfix.Op.Index ||
						   asPostfix.op == ir.Postfix.Op.Slice) {
					return evaluatePostfixIndex(asPostfix);
				} else if (asPostfix.op == ir.Postfix.Op.Increment ||
				           asPostfix.op == ir.Postfix.Op.Decrement) {
					return evaluatePostfixIncDec(asPostfix);
				} else  {
					assert(false);
				}
			case Unary:
				auto asUnary = cast(ir.Unary) e;
				if (asUnary.op == ir.Unary.Op.None) {
					return subTypes[e] = evaluate(asUnary.value);
				} else if (asUnary.op == ir.Unary.Op.Cast) {
					return subTypes[e] = asUnary.type;
				} else if (asUnary.op == ir.Unary.Op.Dereference) {
					auto t = evaluate(asUnary.value);
					if (t.nodeType != ir.NodeType.PointerType) {
						throw new CompilerError(asUnary.location, "tried to dereference non-pointer type.");
					}
					auto asPointer = cast(ir.PointerType) t;
					assert(asPointer !is null);
					return subTypes[e] = asPointer.base;
				} else if (asUnary.op == ir.Unary.Op.AddrOf) {
					auto t = cast(ir.Type) evaluate(asUnary.value);
					assert(t !is null);
					return subTypes[e] = new ir.PointerType(t);
				} else if (asUnary.op == ir.Unary.Op.New) {
					return evaluateNewExp(asUnary);
				} else {
					assert(false);
				}
			default:
				return null;
		}
		assert(false);
	}

	ir.Node extype(ir.Type left, ref ir.Exp right)
	{
		ir.Node t = evaluate(right);
		string emsg = format("cannot implicitly convert '%s' to '%s'.", to!string(left.nodeType), to!string(t.nodeType));

		if (left.nodeType == ir.NodeType.PrimitiveType &&
			t.nodeType == ir.NodeType.PrimitiveType) {

			return extypePrimitiveAssign(right, left, right);
		} else if (left.nodeType == ir.NodeType.PointerType &&
					t.nodeType == ir.NodeType.PointerType) {
			return extypePointerAssign(right, left, right);
		} else if (left.nodeType == ir.NodeType.ArrayType &&
				   t.nodeType == ir.NodeType.ArrayType) {
			return extypeArrayAssign(right, left, right);
		} else if (left.nodeType == ir.NodeType.TypeReference &&
				   t.nodeType == ir.NodeType.TypeReference) {
			auto asUser = cast(ir.TypeReference) t;
			assert(asUser !is null);
			if (!typesEqual(left, asUser)) {
				import std.stdio;
				writefln("%s %s", left.mangledName, asUser.mangledName);
				throw new CompilerError(right.location, emsg);
			}
			return left;
		} else {
			throw new CompilerError(right.location, emsg);
		}
	}

	/// Convert a BinOp to use explicit casts where needed.
	ir.Node extype(ir.BinOp bin)
	{
		ir.Node left = evaluate(bin.left);
		if (left is null) {
			throw new CompilerError(bin.left.location, "could not determine type.");
		}

		ir.Node right = evaluate(bin.right); 
		if (right is null) {
			throw new CompilerError(bin.right.location, "could not determine type.");
		}

		if (bin.op == ir.BinOp.Type.AndAnd || bin.op == ir.BinOp.Type.OrOr) {
			auto boolType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
			bin.left = new ir.Unary(boolType, bin.left);
			bin.right = new ir.Unary(boolType, bin.right);
			return left = right = boolType;
		}
		
		ir.Node result;
		if (left.nodeType == ir.NodeType.PrimitiveType &&
			right.nodeType == ir.NodeType.PrimitiveType) {
			result = extypePrimitive(bin, left, right);
		} else if (left.nodeType == ir.NodeType.PointerType &&
				   right.nodeType == ir.NodeType.PointerType) {
			if (bin.op == ir.BinOp.Type.Assign) {
				return extypePointerAssign(bin.left, left, bin.right);
			} else if (bin.op == ir.BinOp.Type.Is || bin.op == ir.BinOp.Type.NotIs) {
				result = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
			} else {
				throw new CompilerError(bin.location, "invalid binary operation for pointer types.");
			}
		} else if (left.nodeType == ir.NodeType.ArrayType ||
				   right.nodeType == ir.NodeType.ArrayType) {
			// ...
			if (bin.op != ir.BinOp.Type.Cat) {
				throw new CompilerError(bin.location, "can only concatenate arrays.");
			}
			ir.ArrayType array;
			ir.ArrayType array2;
			bool rightExp;
			if (left.nodeType == ir.NodeType.ArrayType) {
				array = cast(ir.ArrayType) left;
				array2 = cast(ir.ArrayType) right;
				rightExp = true;
			} else if (right.nodeType == ir.NodeType.ArrayType) {
				array = cast(ir.ArrayType) right;
				array2 = cast(ir.ArrayType) left;
				rightExp = false;
			}
			if (array2 !is null) {
				// T[] ~ J[]
				if (!typesEqual(array, array2)) {
					throw new CompilerError(bin.location, "concatenated arrays must be the same type.");
				}
				result = left;
			} else {
				// T[] ~ J
				extype(array.base, rightExp ? bin.right : bin.left);
				result = array;
			}
		} else if ((left.nodeType == ir.NodeType.PointerType && right.nodeType != ir.NodeType.PointerType) ||
                   (left.nodeType != ir.NodeType.PointerType && right.nodeType == ir.NodeType.PointerType)) {
			if (!isValidPointerArithmeticOperation(bin.op)) {
				throw new CompilerError(bin.location, "invalid operation for pointer arithmetic.");
			}
			ir.PrimitiveType prim;
			ir.PointerType pointer;
			if (left.nodeType == ir.NodeType.PrimitiveType) {
				prim = cast(ir.PrimitiveType) left;
				pointer = cast(ir.PointerType) right;
			} else {
				prim = cast(ir.PrimitiveType) right;
				pointer = cast(ir.PointerType) left;
			}
			assert(pointer !is null);
			/// @todo @p Type to @p string function.
			if (prim is null) {
				throw new CompilerError(bin.location, "pointer arithmetic can only be performed with integral types.");
			} else if (!isOkayForPointerArithmetic(prim.type)) {
				throw new CompilerError(bin.location, format("pointer arithmetic cannot be performed with '%s'.", to!string(prim.type)));
			}
			result = pointer;
		} else {
			auto lt = cast(ir.Type) left;
			auto rt = cast(ir.Type) right;
			if (lt !is null && rt !is null && typesEqual(lt, rt)) {
				result = lt;
			} else {
				throw new CompilerError(bin.location, "cannot implicitly reconcile binary expression types.");
			}
		}

		if (isComparison(bin.op)) {
			return new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
		}

		return result;
	}

	/// Given a binary operation between two primitive types, make the casts explicit.
	ir.Node extypePrimitive(ir.BinOp bin, ir.Node left, ir.Node right)
	{
		auto lp = cast(ir.PrimitiveType) left;
		auto rp = cast(ir.PrimitiveType) right;

		if (lp is null || rp is null) {
			throw new CompilerError(bin.location, "cannot implicitly reconcile binary expression types.");
		}

		auto leftsz = size(lp.type);
		auto rightsz = size(rp.type);

		bool leftUnsigned = isUnsigned(lp.type);
		bool rightUnsigned = isUnsigned(rp.type);
		if (leftUnsigned != rightUnsigned) {
			throw new CompilerError(bin.location, "binary operation with both signed and unsigned operands.");
		}

		auto intsz = size(ir.PrimitiveType.Kind.Int);
		int largestsz;
		ir.Type largestType;

		if (leftsz > rightsz) {
			largestsz = leftsz;
			largestType = lp;
		} else {
			largestsz = rightsz;
			largestType = rp;
		}

		if (intsz > largestsz) {
			largestsz = intsz;
			largestType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
		}

		if (leftsz < largestsz) {
			bin.left = new ir.Unary(largestType, bin.left);
		}

		if (rightsz < largestsz) {
			bin.right = new ir.Unary(largestType, bin.right);
		}

		return largestType;
	}

	ir.Node extypeArrayAssign(ref ir.Exp exp, ir.Node dest, ir.Exp src)
	{
		auto lp = cast(ir.ArrayType) dest;
		auto rp = cast(ir.ArrayType) evaluate(src);

		if (lp is null || rp is null) {
			throw CompilerPanic(exp.location, "extypeArrayAssign called with non-array types.");
		}

		if (typesEqual(lp, rp)) {
			return lp;
		}

		if (lp.base.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) lp.base;
			assert(asPrimitive !is null);
			if (asPrimitive.type == ir.PrimitiveType.Kind.Void) {
				exp = new ir.Unary(lp, exp);
				return lp;
			}
		}

		throw new CompilerError(exp.location, "arrays may only be implicitly converted to void[].");
	}

	ir.Node extypePointerAssign(ref ir.Exp exp, ir.Node dest, ir.Exp src)
	{
		auto lp = cast(ir.PointerType) dest;
		auto rp = cast(ir.PointerType) evaluate(src);

		if (lp is null || rp is null) {
			throw CompilerPanic(exp.location, "extypePointerAssign called with non-pointer types.");
		}

		if (typesEqual(lp, rp)) {
			return lp;
		}

		if (lp.base.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) lp.base;
			assert(asPrimitive !is null);
			if (asPrimitive.type == ir.PrimitiveType.Kind.Void) {
				exp = new ir.Unary(lp, exp);
				return lp;
			}
		}

		throw new CompilerError(exp.location, "pointers may only be implicitly converted to void*.");
	}

	/// Modify exp to become a cast to dest from src, if required.
	ir.Node extypePrimitiveAssign(ref ir.Exp exp, ir.Node dest, ir.Exp src)
	{
		auto lp = cast(ir.PrimitiveType) dest;
		auto rp = cast(ir.PrimitiveType) evaluate(src);

		if (lp is null || rp is null) {
			throw new CompilerError(exp.location, "cannot implicitly reconcile binary expression types.");
		}

		if (typesEqual(lp, rp)) {
			return lp;
		}

		auto leftsz = size(lp.type);
		auto rightsz = size(rp.type);

		bool leftUnsigned = isUnsigned(lp.type);
		bool rightUnsigned = isUnsigned(rp.type);
		if (leftUnsigned != rightUnsigned && !fitsInPrimitive(lp, src) && rightsz >= leftsz) {
			throw new CompilerError(exp.location, "binary operation with both signed and unsigned operands.");
		}

		if (rightsz > leftsz && !fitsInPrimitive(lp, src)) {
			throw new CompilerError(exp.location, format("cannot implicitly cast '%s' to '%s'.", to!string(rp.type), to!string(lp.type)));
		}
		
		
		exp = new ir.Unary(lp, exp);

		return lp;
	}

	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.Module m)
	{
		_module = m;
		return super.enter(m);
	}

	override Status visit(ir.IdentifierExp e)
	{
		if (e.globalLookup) {
			e.type = declTypeLookup(_module.myScope, e.value, e.location);
		} else {
			e.type = declTypeLookup(current, e.value, e.location);
		}

		return Continue;
	}

	override Status enter(ir.BinOp bin)
	{
		extype(bin);
		return ContinueParent;
	}

	override Status enter(ir.Postfix p)
	{
		evaluate(p);
		return ContinueParent;
	}

	override Status enter(ir.Variable d)
	{
		if (d.assign is null) {
			return ContinueParent;
		}

		extype(d.type, d.assign);
		return ContinueParent;
	}

	override Status enter(ir.IfStatement ifs)
	{
		ir.Node t = evaluate(ifs.exp);
		if (t.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) t;
			if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
				return Continue;
			}
		}
		ifs.exp = new ir.Unary(new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool), ifs.exp);
		return Continue;
	}

	override Status enter(ir.ForStatement fs)
	{
		ir.Node t = evaluate(fs.test);
		if (t.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) t;
			if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
				return Continue;
			}
		}
		fs.test = new ir.Unary(new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool), fs.test);
		return Continue;
	}

	override Status enter(ir.WhileStatement ws)
	{
		ir.Node t = evaluate(ws.condition);
		if (t.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) t;
			if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
				return Continue;
			}
		}
		ws.condition = new ir.Unary(new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool), ws.condition);
		return Continue;
	}

	override Status enter(ir.DoStatement ds)
	{
		ir.Node t = evaluate(ds.condition);
		if (t.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) t;
			if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
				return Continue;
			}
		}
		ds.condition = new ir.Unary(new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool), ds.condition);
		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		super.enter(fn);
		functionRet = fn.type.ret;
		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		super.leave(fn);
		functionRet = null;
		return Continue;
	}

	override Status enter(ir.ReturnStatement rs)
	{
		if (rs.exp !is null) {
			extype(functionRet, rs.exp);
		} else {
			auto v = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
			if (!typesEqual(functionRet, v))
				throw new CompilerError(rs.location, "function return type is not void.");
		}
		return Continue;
	}
}
