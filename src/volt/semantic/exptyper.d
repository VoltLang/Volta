// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.exptyper;

import std.conv : to;
import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.exceptions;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.visitor.expreplace;
import volt.semantic.classify;
import volt.semantic.userresolver : scopeLookup;
import volt.semantic.lookup;
import volt.semantic.typer;


/**
 * Make implicit casts explicit.
 *
 * @ingroup passes passLang
 */
class ExpTyper : ScopeManager, ExpReplaceVisitor, Pass
{
public:
	Settings settings;
	ir.Module _module;
	ir.Type functionRet;
	int pass;

public:
	this(Settings settings)
	{
		this.settings = settings;
	}

	/// Modify a function call to have explicit casts and return the return type.
	void extypePostfix(ir.Postfix postfix)
	{
		if (postfix.op != ir.Postfix.Op.Call) {
			return;
		}

		auto type = getExpType(postfix.child, current);
		auto asFunctionType = cast(ir.CallableType) type;
		if (asFunctionType is null) {
			throw new CompilerError(postfix.location, format("tried to call uncallable type."));
		}

		if (asFunctionType.isScope && postfix.child.nodeType == ir.NodeType.Postfix) {
			auto asPostfix = cast(ir.Postfix) postfix.child;
			auto parentType = getExpType(asPostfix.child, current);
			if (mutableIndirection(parentType)) {
				auto asStorageType = cast(ir.StorageType) parentType;
				if (asStorageType is null || asStorageType.type != ir.StorageType.Kind.Scope) {
					throw new CompilerError(postfix.location, "cannot call scope function on non scope instance.");
				}
			}
		}

		if (asFunctionType.hasVarArgs) {
			auto asExp = cast(ir.ExpReference) postfix.child;
			assert(asExp !is null);
			auto asFunction = cast(ir.Function) asExp.decl;
			assert(asFunction !is null);

			replaceVarArgsIfNeeded(asFunction);

			auto amountOfVarArgs = postfix.arguments.length - (asFunctionType.params.length + 1);
			assert(amountOfVarArgs >= 0);

			auto tinfoClass = retrieveTypeInfoClass(postfix.location, current);
			auto tr = new ir.TypeReference(tinfoClass, tinfoClass.name);
			tr.location = postfix.location;
			auto array = new ir.ArrayType();
			array.location = postfix.location;
			array.base = tr;

			auto typeidsLiteral = new ir.ArrayLiteral();
			typeidsLiteral.location = postfix.location;
			typeidsLiteral.type = array;

			for (size_t i = asFunctionType.params.length - 1; i < postfix.arguments.length; ++i) {
				auto typeId = new ir.Typeid();
				typeId.location = postfix.location;
				typeId.type = copyTypeSmart(postfix.location, getExpType(postfix.arguments[i], current));
				typeidsLiteral.values ~= typeId;
			}

			if (postfix.arguments.length != asFunctionType.params.length) {
				postfix.arguments.length = asFunctionType.params.length;
			}
			postfix.arguments[$- 1] = typeidsLiteral;
		}

		if (postfix.arguments.length != asFunctionType.params.length) {
			throw new CompilerError(postfix.location, "wrong number of arguments to function.");
		}
		foreach (i; 0 .. postfix.arguments.length) {
			if (asFunctionType.params[i].isRef) {
				postfix.arguments[i] = buildAddrOf(postfix.location, postfix.arguments[i]);
			}
			extype(asFunctionType.params[i].type, postfix.arguments[i]);
		}
	}

	ir.Node extype(ref ir.Type left, ref ir.Exp right, bool inVariable = false)
	{
		ir.Type localLeft = left;

		auto asExpRef = cast(ir.ExpReference) right;
		ir.Variable asVar;
		if (asExpRef !is null) {
			asVar = cast(ir.Variable) asExpRef.decl;
			if (asVar !is null && asVar.isRef) {
				right = buildDeref(right.location, right);
			}
		}

		if (right.nodeType == ir.NodeType.StructLiteral) {
			auto asLit = cast(ir.StructLiteral) right;
			assert(asLit !is null);
			string emsg = "cannot implicitly cast struct literal to destination.";

			auto asStruct = cast(ir.Struct) localLeft;
			if (asStruct is null) {
				auto asTR = cast(ir.TypeReference) localLeft;
				if (asTR !is null) {
					asStruct = cast(ir.Struct) asTR.type;
				}
				if (asStruct is null) {
					throw new CompilerError(right.location, emsg);
				}
			}

			ir.Type[] types = getStructFieldTypes(asStruct);

			if (types.length < asLit.exps.length) {
				throw new CompilerError(right.location, "cannot implicitly cast struct literal -- too many expressions for target.");
			}

			foreach (i, ref sexp; asLit.exps) {
				extype(types[i], sexp);
			}

			asLit.type = new ir.TypeReference(asStruct, asStruct.name);
			asLit.type.location = right.location;
			return asLit.type;
		}

		ir.Type t = getExpType(right, current);

		// Turn no-arg @property functions into calls.
		if (t.nodeType == ir.NodeType.FunctionType || t.nodeType == ir.NodeType.DelegateType) {
			auto asCallable = cast(ir.CallableType) t;
			if (asCallable.isProperty && asCallable.params.length == 0) {
				right = buildCall(right.location, right, null);
				t = asCallable.ret;
			}
		}


		// Fill in storage type if the base is null.
		auto asStorageType = cast(ir.StorageType) left;
		if (asStorageType !is null) {
			if (asStorageType.base is null) {
				asStorageType.base = copyTypeSmart(left.location, t);
			}
			if (asStorageType.type == ir.StorageType.Kind.Auto) {
				localLeft = left = asStorageType.base;
			}
		}

		auto lstorage = cast(ir.StorageType) localLeft;
		auto rstorage = cast(ir.StorageType) t;
		if (isConst(lstorage) && isImmutable(rstorage) && mutableIndirection(rstorage.base)) {
			throw new CompilerError(right.location, "cannot convert immutable type to const.");
		}

		if (inVariable && effectivelyConst(left)) {
			asStorageType = cast(ir.StorageType) left;
			right = buildCastSmart(asStorageType, right);
			t = asStorageType;
		}

		auto asTR = cast(ir.TypeReference) left;
		if (asTR !is null) {
			localLeft = asTR.type;
		}

		ir.Type type = t;
		string emsg = format("cannot implicitly convert '%s' to '%s'.", to!string(t.nodeType), to!string(localLeft.nodeType));

		if (localLeft.nodeType == ir.NodeType.PrimitiveType &&
			t.nodeType == ir.NodeType.PrimitiveType) {

			return extypePrimitiveAssign(right, localLeft, right);
		} else if (localLeft.nodeType == ir.NodeType.PointerType &&
					t.nodeType == ir.NodeType.PointerType) {
			return extypePointerAssign(right, localLeft, right);
		} else if (localLeft.nodeType == ir.NodeType.ArrayType &&
				   t.nodeType == ir.NodeType.ArrayType) {
			return extypeArrayAssign(right, localLeft, right);
		} else if (localLeft.nodeType == ir.NodeType.Class &&
				   t.nodeType == ir.NodeType.Class) {
			auto leftClass = cast(ir.Class) localLeft;
			assert(leftClass !is null);
			auto rightClass = cast(ir.Class) t;
			assert(rightClass !is null);
			/// Check for converting child classes into parent classes.
			if (leftClass !is null && rightClass !is null) {
				if (inheritsFrom(rightClass, leftClass)) {
					right = buildCastSmart(new ir.TypeReference(localLeft, leftClass.name), right);
					return localLeft;
				}
			}

			if (leftClass !is rightClass) {
				throw new CompilerError(right.location, emsg);
			}
			return localLeft;
		} else if ((localLeft.nodeType == ir.NodeType.PointerType &&
			 	   t.nodeType == ir.NodeType.Class) ||
				   (localLeft.nodeType == ir.NodeType.Class &&
				   t.nodeType == ir.NodeType.PointerType)) {
			/* This is the case when using a function that takes a
			 * class instance in one module from another before the
			 * latter module's class lowerer has turned it into the
			 * struct pointer. We know it'll run eventually, so just
			 * verify that the struct and class agree, and move on.
			 */ 
			auto asClass = cast(ir.Class) t;
			if (asClass is null) {
				asClass = cast(ir.Class) localLeft;
				assert(asClass !is null);
			}
			
			auto asPointer = cast(ir.PointerType) localLeft;
			if (asPointer is null) {
				asPointer = cast(ir.PointerType) t;
				assert(asPointer !is null);
			}
			auto asTR2 = cast(ir.TypeReference) asPointer.base;
			if (asTR2 is null) {
				throw new CompilerError(right.location, emsg);
			}
			auto asStruct = cast(ir.Struct) asTR2.type;
			if (asStruct is null || asStruct.loweredNode !is asClass) {
				throw new CompilerError(right.location, emsg);
			}

			return asPointer;
		} else if (localLeft.nodeType == ir.NodeType.DelegateType &&
				   t.nodeType == ir.NodeType.DelegateType) {
			auto ldg = cast(ir.DelegateType) localLeft;
			auto rdg = cast(ir.DelegateType) t;
			assert(ldg !is null && rdg !is null);

			if (typesEqual(ldg, rdg)) {
				return ldg;
			}
		} else if (localLeft.nodeType != ir.NodeType.StorageType &&
				   t.nodeType == ir.NodeType.StorageType) {
			asStorageType = cast(ir.StorageType) t;
			assert(asStorageType !is null);
			if (asStorageType.type == ir.StorageType.Kind.Scope) {
				if (mutableIndirection(asStorageType.base)) {
					throw new CompilerError(right.location, "cannot convert scope into mutably indirectable type.");
				}
				right = buildCastSmart(asStorageType.base, right);
				return extype(left, right);
			}

			if (effectivelyConst(t)) {
				if (!mutableIndirection(asStorageType.base)) {
					right = buildCastSmart(asStorageType.base, right);
					return extype(left, right);
				} else {
					throw new CompilerError(right.location, "cannot implicitly convert const to non const.");
				}
			}
		} else if (localLeft.nodeType == ir.NodeType.StorageType &&
				   t.nodeType != ir.NodeType.StorageType) {
			asStorageType = cast(ir.StorageType) localLeft;
			/* Scope is always the first StorageType, so we don't have to
			 * worry about StorageType chains.
			 */
			if (asStorageType.type == ir.StorageType.Kind.Scope) {
				if ((asVar !is null && !asVar.isRef) && mutableIndirection(t)) {
					/// This is not the world's greatest error message. @todo
					throw new CompilerError(right.location, "cannot convert mutably indirectable type to scope.");
				} else {
					right = buildCastSmart(asStorageType, right);
					return asStorageType;
				}
			}
		} else {
			if (typesEqual(localLeft, t)) {
				return localLeft;
			}
		}

		throw new CompilerError(right.location, emsg);
	}

	/// Convert a BinOp to use explicit casts where needed.
	ir.Node extype(ir.BinOp bin)
	{
		if (bin.left.nodeType == ir.NodeType.Postfix) {
			extypePostfix(cast(ir.Postfix)bin.left);
		} else if (bin.left.nodeType == ir.NodeType.BinOp) {
			extype(cast(ir.BinOp)bin.left);
		}
		if (bin.right.nodeType == ir.NodeType.Postfix) {
			extypePostfix(cast(ir.Postfix)bin.right);
		} else if (bin.right.nodeType == ir.NodeType.BinOp) {
			extype(cast(ir.BinOp)bin.right);
		}

		auto asExpRef = cast(ir.ExpReference) bin.left;
		if (asExpRef !is null) {
			auto asVar = cast(ir.Variable) asExpRef.decl;
			if (asVar !is null && asVar.isRef) {
				bin.left = buildDeref(bin.left.location, bin.left);
			}
		}

		ir.Type left = getExpType(bin.left, current);
		ir.Type right = getExpType(bin.right, current);

		if (effectivelyConst(left) && bin.op == ir.BinOp.Type.Assign) {
			throw new CompilerError(bin.location, "cannot assign to const type.");
		}
		
		if (bin.op == ir.BinOp.Type.AndAnd || bin.op == ir.BinOp.Type.OrOr) {
			auto boolType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool);
			bin.left = buildCastSmart(boolType, bin.left);
			bin.right = buildCastSmart(boolType, bin.right);
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
			if (!(bin.op == ir.BinOp.Type.Cat || bin.op == ir.BinOp.Type.Assign)) {
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
		} else if (left.nodeType == ir.NodeType.StorageType) {
			auto asStorage = cast(ir.StorageType) left;
			assert(asStorage !is null);
			if (asStorage.type == ir.StorageType.Kind.Scope && !mutableIndirection(right)) {
				bin.right = buildCastSmart(bin.right.location, asStorage, bin.right);
				result = asStorage;
			} else {
				throw new CompilerError(bin.location, "cannot implicitly convert non storage type to storage type.");
			}
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

		if (bin.op != ir.BinOp.Type.Assign && intsz > largestsz) {
			largestsz = intsz;
			largestType = new ir.PrimitiveType(ir.PrimitiveType.Kind.Int);
		}

		if (leftsz < largestsz) {
			bin.left = buildCastSmart(largestType, bin.left);
		}

		if (rightsz < largestsz) {
			bin.right = buildCastSmart(largestType, bin.right);
		}

		return largestType;
	}

	ir.Node extypeArrayAssign(ref ir.Exp exp, ir.Node dest, ir.Exp src)
	{
		auto lp = cast(ir.ArrayType) dest;
		auto rp = cast(ir.ArrayType) getExpType(src, current);

		if (lp is null || rp is null) {
			throw CompilerPanic(exp.location, "extypeArrayAssign called with non-array types.");
		}

		if (effectivelyConst(rp.base) && !effectivelyConst(lp.base)) {
			// All arrays are mutable indirectable.
			throw new CompilerError(exp.location, "cannot convert const array to mutable array.");
		}

		if (typesEqual(lp, rp)) {
			return lp;
		}

		if (lp.base.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) lp.base;
			assert(asPrimitive !is null);
			if (asPrimitive.type == ir.PrimitiveType.Kind.Void) {
				exp = buildCastSmart(lp, exp);
				return lp;
			}
		}

		throw new CompilerError(exp.location, "arrays may only be implicitly converted to void[].");
	}

	ir.Node extypePointerAssign(ref ir.Exp exp, ir.Node dest, ir.Exp src)
	{
		auto lp = cast(ir.PointerType) dest;
		auto rp = cast(ir.PointerType) getExpType(src, current);

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
				exp = buildCastSmart(lp, exp);
				return lp;
			}
		}

		throw new CompilerError(exp.location, "pointers may only be implicitly converted to void*.");
	}

	/// Modify exp to become a cast to dest from src, if required.
	ir.Node extypePrimitiveAssign(ref ir.Exp exp, ir.Node dest, ir.Exp src)
	{
		auto lp = cast(ir.PrimitiveType) dest;
		auto rp = cast(ir.PrimitiveType) getExpType(src, current);

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
		
		
		exp = buildCastSmart(lp, exp);

		return lp;
	}

	override void transform(ir.Module m)
	{
		pass = 1;
		accept(m, this);
		pass = 2;
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
		if (pass == 2) {
			return Continue;
		}

		if (e.globalLookup) {
			e.type = declTypeLookup(_module.myScope, e.value, e.location);
		} else {
			e.type = declTypeLookup(current, e.value, e.location);
		}

		return Continue;
	}

	override Status enter(ir.BinOp bin)
	{
		if (pass == 2) {
			return Continue;
		}
		extype(bin);
		return Continue;
	}

	override Status enter(ir.Postfix p)
	{
		if (pass == 2) {
			// Ensure semantic correctness.
			getExpType(p, current);
			return Continue;
		}
		extypePostfix(p);
		return Continue;
	}

	override Status enter(ir.Variable d)
	{
		if (d.assign is null) {
			return Continue;
		}
		acceptExp(d.assign, this);

		if (pass == 2) {
			return Continue;
		}

		extype(d.type, d.assign, true);

		return Continue;
	}

	override Status enter(ir.ExpStatement es)
	{
		acceptExp(es.exp, this);
		return Continue;
	}

	override Status enter(ir.IfStatement ifs)
	{
		acceptExp(ifs.exp, this);

		if (pass == 2) {
			return Continue;
		}

		ir.Node t = getExpType(ifs.exp, current);
		if (t.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) t;
			if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
				return Continue;
			}
		}
		ifs.exp = buildCastToBool(ifs.exp);
		ifs.exp.location = ifs.location;
		return Continue;
	}

	override Status enter(ir.ForStatement fs)
	{
		if (fs.test is null) {
			return Continue;
		}
		acceptExp(fs.test, this);
		foreach (ref increment; fs.increments) {
			acceptExp(increment, this);
		}

		if (pass == 2) {
			return Continue;
		}

		ir.Node t = getExpType(fs.test, current);
		if (t.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) t;
			if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
				return Continue;
			}
		}
		fs.test = buildCastToBool(fs.test);
		return Continue;
	}

	override Status enter(ir.WhileStatement ws)
	{
		acceptExp(ws.condition, this);

		if (pass == 2) {
			return Continue;
		}

		ir.Node t = getExpType(ws.condition, current);
		if (t.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) t;
			if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
				return Continue;
			}
		}
		ws.condition = buildCastToBool(ws.condition);
		return Continue;
	}

	override Status enter(ir.DoStatement ds)
	{
		acceptExp(ds.condition, this);

		if (pass == 2) {
			return Continue;
		}

		ir.Node t = getExpType(ds.condition, current);
		if (t.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) t;
			if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
				return Continue;
			}
		}
		ds.condition = buildCastSmart(new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool), ds.condition);
		return Continue;
	}

	override Status enter(ir.SwitchStatement ss)
	{
		acceptExp(ss.condition, this);

		if (pass == 2) {
			return Continue;
		}

		foreach (ref c; ss.cases) {
			if (c.firstExp !is null) acceptExp(c.firstExp, this);
			if (c.secondExp !is null) acceptExp(c.secondExp, this);
			foreach (i; 0 .. c.exps.length) {
				acceptExp(c.exps[i], this);
			}
		}
		return Continue;
	}

	override Status enter(ir.GotoStatement gs)
	{
		if (gs.exp !is null) {
			acceptExp(gs.exp, this);
		}
		return Continue;
	}

	override Status enter(ir.WithStatement ws)
	{
		acceptExp(ws.exp, this);
		return Continue;
	}

	override Status enter(ir.SynchronizedStatement ss)
	{
		if (ss.exp !is null) {
			acceptExp(ss.exp, this);
		}
		return Continue;
	}

	override Status enter(ir.ThrowStatement ts)
	{
		acceptExp(ts.exp, this);
		return Continue;
	}

	override Status enter(ir.PragmaStatement ps)
	{
		foreach (ref exp; ps.arguments) {
			acceptExp(exp, this);
		}
		return Continue;
	}

	void replaceVarArgsIfNeeded(ir.Function fn)
	{
		if (fn.type.hasVarArgs && !fn.type.varArgsProcessed) {
			auto tinfoClass = retrieveTypeInfoClass(fn.location, current);
			assert(tinfoClass !is null);
			auto tr = new ir.TypeReference(tinfoClass, tinfoClass.name);
			tr.location = fn.location;
			auto array = new ir.ArrayType();
			array.location = tr.location;
			array.base = tr;
			auto var = new ir.Variable();
			var.location = fn.location;
			var.type = array;
			var.name = "_typeids";
			fn.type.params ~= var;
			fn.myScope.addValue(var, "_typeids");
			fn.type.varArgsProcessed = true;
		}
	}

	override Status enter(ir.Function fn)
	{
		replaceVarArgsIfNeeded(fn);
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
			acceptExp(rs.exp, this);
			if (pass == 2) {
				return Continue;
			}
			extype(functionRet, rs.exp);
		} else {
			if (pass == 2) {
				return Continue;
			}
			auto v = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
			if (!typesEqual(functionRet, v))
				throw new CompilerError(rs.location, "function return type is not void.");
		}
		return Continue;
	}

	/// If this is an assignment to a @property function, turn it into a function call.
	override Status leave(ref ir.Exp e, ir.BinOp bin)
	{
		if (bin.op != ir.BinOp.Type.Assign) {
			return Continue;
		}
		auto asExpRef = cast(ir.ExpReference) bin.left;
		ir.Postfix asPostfix;

		// Not a stand alone function, check if it's a member function.
		if (asExpRef is null) {
			asPostfix = cast(ir.Postfix) bin.left;
			if (asPostfix is null) {
				return Continue;
			}
			asExpRef = asPostfix.memberFunction;
			if (asExpRef is null) {
				return Continue;
			}
		}

		auto asFunction = cast(ir.Function) asExpRef.decl;
		if (asFunction is null) {
			return Continue;
		}
		if (!asFunction.type.isProperty) {
			return Continue;
		}
		if (asFunction.type.params.length != 1) {
			return Continue;
		}
		auto call = buildCall(bin.location, buildExpReference(bin.left.location, asFunction, asFunction.name), [bin.right]);
		assert(call.arguments.length == 1);
		assert(call.arguments[0] !is null);
		
		if (asPostfix !is null) {
			call.child = asPostfix;
		}
		e = call;
		return Continue;
	}

	override Status enter(ref ir.Exp e, ir.Postfix p)
	{
		if (pass == 2) {
			return Continue;
		}
		if (p.op != ir.Postfix.Op.Identifier)
			return Continue;

		ir.Postfix[] postfixIdents; // In reverse order.
		ir.IdentifierExp identExp; // The top of the stack.
		ir.Postfix currentP = p;

		while (true) {
			if (currentP.identifier is null)
				throw CompilerPanic(currentP.location, "null identifier");

			postfixIdents = [currentP] ~ postfixIdents;

			if (currentP.child.nodeType == ir.NodeType.Postfix) {
				auto child = cast(ir.Postfix) currentP.child;

				// for things like func().structVar;
				if (child.op != ir.Postfix.Op.Identifier) {
					return acceptExp(currentP.child, this);
				}

				currentP = child;

			} else if (currentP.child.nodeType == ir.NodeType.IdentifierExp) {
				identExp = cast(ir.IdentifierExp) currentP.child;
				break;
			} else {
				throw CompilerPanic(currentP.location, "strange postfix child");
			}
		}

		ir.ExpReference _ref;
		ir.Location loc;
		string ident;
		string[] idents;

		/// Fillout _ref with data from ident.
		void filloutReference(ir.Store store)
		{
			_ref = new ir.ExpReference();
			_ref.location = loc;
			_ref.idents = idents;

			assert(store !is null);
			if (store.kind == ir.Store.Kind.Value) {
				auto var = cast(ir.Variable) store.node;
				assert(var !is null);
				_ref.decl = var;
			} else if (store.kind == ir.Store.Kind.Function) {
				assert(store.functions.length == 1);
				auto fn = store.functions[0];
				_ref.decl = fn;
			} else {
				auto emsg = format("unhandled Store kind: '%s'.", to!string(store.kind));
				throw CompilerPanic(_ref.location, emsg);
			}

			// Sanity check.
			if (_ref.decl is null) {
				throw CompilerPanic(_ref.location, "empty ExpReference declaration.");
			}
		}

		/**
		 * Our job here is to work trough the stack of postfixs and
		 * the top identifier exp looking for the first variable or
		 * function.
		 *
		 * pkg.mod.Class.Child.'staticVar'.field.anotherField;
		 *
		 * Would have 6 postfixs and IdentifierExp == "pkg".
		 * We would skip 3 postfixes and the IdentifierExp.
		 * Postfix "anotherField" ->
		 *   Postfix "field" ->
		 *     ExpReference "pkg.mod.Class.Child.staticVar".
		 *
		 *
		 * pkg.mod.'staticVar'.field;
		 *
		 * Would have 2 Postfixs and the IdentifierExp.
		 * We would should skip everything but one Postfix.
		 * Postfix "field" ->
		 *   ExpReference "pkg.mod.staticVar".
		 */

		ir.Scope _scope;
		ir.Store store;

		// First do the identExp lookup.
		// p is in an unknown state at this point.
		{
			_scope = current;
			loc = identExp.location;
			ident = identExp.value;
			idents = [ident];

			/// @todo handle leading dot.
			assert(!identExp.globalLookup);

			store = _scope.lookup(ident, loc);
		}

		// Now do the looping.
		do {
			if (store is null) {
				/// @todo keep track of what the context was that we looked into.
				throw new CompilerError(loc, format("unknown identifier '%s'.", ident));
			}

			final switch(store.kind) with (ir.Store.Kind) {
			case Scope:
			case Type:
				_scope = getScopeFromStore(store);
				if (_scope is null)
					throw CompilerPanic(loc, "missing scope");

				if (postfixIdents.length == 0)
					throw new CompilerError(loc, "expected value or function not type/scope");

				p = postfixIdents[0];
				postfixIdents = postfixIdents[1 .. $];
				ident = p.identifier.value;
				loc = p.identifier.location;

				store = _scope.lookupOnlyThisScope(ident, loc);
				idents = [ident] ~ idents;

				break;
			case Value:
			case Function:
				filloutReference(store);
				break;
			}

		} while(_ref is null);

		assert(_ref !is null);

		if (postfixIdents.length == 0) {
			e = _ref;
			return ContinueParent;
		} else {
			p = postfixIdents[0];
			p.child = _ref;
		}

		/* If we end up with a identifier postfix that points
		 * at a struct, and retrieves a member function, then
		 * transform the op from Identifier to CreatePostfix.
		 */
		/// @todo this should be checked in another place,
		///        probably at the same place we handle property
		if (p.op == ir.Postfix.Op.Identifier &&
		    _ref.decl.declKind == ir.Declaration.Kind.Variable) {

			auto asVar = cast(ir.Variable) _ref.decl;
			assert(asVar !is null);
			if (asVar.type.nodeType != ir.NodeType.TypeReference) {
				return ContinueParent;
			}

			auto asTR = cast(ir.TypeReference) asVar.type;
			assert(asTR !is null);
			if (asTR.type.nodeType != ir.NodeType.Struct) {
				return ContinueParent;
			}

			auto asStruct = cast(ir.Struct) asTR.type;
			assert(asStruct !is null);

			/// @todo this is probably an error.
			store = asStruct.myScope.lookupOnlyThisScope(p.identifier.value, p.location);
			if (store is null) {
				throw new CompilerError(_ref.location, format("aggregate has no member '%s'.", p.identifier.value));
			}

			if (store.kind != ir.Store.Kind.Function) {
				return ContinueParent;
			}

			/// @todo handle function overloading.
			assert(store.functions.length == 1);

			auto funcref = new ir.ExpReference();
			funcref.location = p.identifier.location;
			funcref.idents = _ref.idents;
			funcref.idents ~= p.identifier.value;
			funcref.decl = store.functions[0];
			p.op = ir.Postfix.Op.CreateDelegate;
			p.memberFunction = funcref;
		}

		return ContinueParent;
	}

	override Status visit(ref ir.Exp e, ir.IdentifierExp i)
	{
		if (pass == 2) {
			return Continue;
		}
		auto store = current.lookup(i.value, e.location);
		if (store is null) {
			throw new CompilerError(i.location, format("unidentified identifier '%s'.", i.value));
		}

		if (store.kind == ir.Store.Kind.Value) {
			auto var = cast(ir.Variable) store.node;
			assert(var !is null);

			auto _ref = new ir.ExpReference();
			_ref.idents ~= i.value;
			_ref.location = i.location;
			_ref.decl = var;
			e = _ref;
			return Continue;
		} else if (store.kind == ir.Store.Kind.Function) {
			if (store.functions.length != 1)
				throw CompilerPanic(i.location, "can not take function pointers from overloaded functions");

			/// @todo Figure out if this is a delegate or not.
			auto fn = cast(ir.Function) store.functions[0];
			assert(fn !is null);

			auto _ref = new ir.ExpReference();
			_ref.idents ~= i.value;
			_ref.location = i.location;
			_ref.decl = fn;
			e = _ref;

			return Continue;
		} else if (store.kind == ir.Store.Kind.Type) {
			return Continue;
		}

		throw CompilerPanic(i.location, format("unhandled identifier type '%s'.", i.value));
	}

	override Status visit(ref ir.Exp e, ir.ExpReference reference)
	{
		ir.Scope _; 
		ir.Class _class;
		bool foundClass = current.getFirstClass(_, _class);
		if (foundClass) {
			auto asFunction = cast(ir.Function) current.node;
			if (asFunction is null) {
				return Continue;
			}

			auto store = _class.myScope.lookup(reference.idents[$-1], reference.location);
			if (store is null) {
				return Continue;
			}

			store = current.lookup("this", reference.location);
			if (store is null || store.kind != ir.Store.Kind.Value) {
				throw CompilerPanic("function doesn't have this");
			}

			auto asVar = cast(ir.Variable)store.node;
			assert(asVar !is null);

			auto thisRef = new ir.ExpReference();
			thisRef.location = reference.location;
			thisRef.idents ~= "this";
			thisRef.decl = asVar;

			auto postfix = new ir.Postfix();
			postfix.location = reference.location;
			postfix.op = ir.Postfix.Op.Identifier;
			postfix.identifier = new ir.Identifier();
			postfix.identifier.location = reference.location;
			postfix.identifier.value = reference.idents[0];
			postfix.child = thisRef;

			e = postfix;
			return Continue;
		}

		if (pass == 1) {
			return Continue;
		}
		auto varStore = current.lookupOnlyThisScope(reference.idents[$-1], reference.location);
		if (varStore !is null) {
			return Continue;
		}

		auto thisStore = current.lookupOnlyThisScope("this", reference.location);
		if (thisStore is null) {
			return Continue;
		}

		auto asVar = cast(ir.Variable) thisStore.node;
		assert(asVar !is null);
		auto asTR = cast(ir.TypeReference) asVar.type;
		assert(asTR !is null);
		auto asStruct = cast(ir.Struct) asTR.type;
		assert(asStruct !is null);

		varStore = asStruct.myScope.lookupOnlyThisScope(reference.idents[0], reference.location);
		if (varStore is null) {
			return Continue;
		}

		// Okay, it looks like reference isn't pointing at a local, and it exists in a this.
		auto thisRef = new ir.ExpReference();
		thisRef.location = reference.location;
		thisRef.idents ~= "this";
		thisRef.decl = asVar;

		auto postfix = new ir.Postfix();
		postfix.location = reference.location;
		postfix.op = ir.Postfix.Op.Identifier;
		postfix.identifier = new ir.Identifier();
		postfix.identifier.location = reference.location;
		postfix.identifier.value = reference.idents[0];
		postfix.child = thisRef;

		e = postfix;
		return Continue;
	}

	override Status leave(ref ir.Exp, ir.Postfix) { return Continue; }
	override Status enter(ref ir.Exp, ir.Unary) { return Continue; }
	override Status leave(ref ir.Exp, ir.Unary) { return Continue; }
	override Status enter(ref ir.Exp, ir.BinOp) { return Continue; }
	override Status enter(ref ir.Exp, ir.Ternary) { return Continue; }
	override Status leave(ref ir.Exp, ir.Ternary) { return Continue; }
	override Status enter(ref ir.Exp, ir.ArrayLiteral) { return Continue; }
	override Status leave(ref ir.Exp, ir.ArrayLiteral) { return Continue; }
	override Status enter(ref ir.Exp, ir.AssocArray) { return Continue; }
	override Status leave(ref ir.Exp, ir.AssocArray) { return Continue; }
	override Status enter(ref ir.Exp, ir.Assert) { return Continue; }
	override Status leave(ref ir.Exp, ir.Assert) { return Continue; }
	override Status enter(ref ir.Exp, ir.StringImport) { return Continue; }
	override Status leave(ref ir.Exp, ir.StringImport) { return Continue; }
	override Status enter(ref ir.Exp, ir.Typeid) { return Continue; }
	override Status leave(ref ir.Exp, ir.Typeid) { return Continue; }
	override Status enter(ref ir.Exp, ir.IsExp) { return Continue; }
	override Status leave(ref ir.Exp, ir.IsExp) { return Continue; }
	override Status enter(ref ir.Exp, ir.FunctionLiteral) { return Continue; }
	override Status leave(ref ir.Exp, ir.FunctionLiteral) { return Continue; }
	override Status enter(ref ir.Exp, ir.StructLiteral) { return Continue; }
	override Status leave(ref ir.Exp, ir.StructLiteral) { return Continue; }
	override Status enter(ref ir.Exp, ir.ClassLiteral) { return Continue; }
	override Status leave(ref ir.Exp, ir.ClassLiteral) { return Continue; }
	override Status visit(ref ir.Exp, ir.Constant) { return Continue; }
}
