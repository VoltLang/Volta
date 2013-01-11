// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
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

public:
	this(Settings settings)
	{
		this.settings = settings;
	}

	/// Get a scope from n, or null if it doesn't have one.
	ir.Scope getChildScope(Location location, ir.Scope _scope, string s)
	{
		auto store = _scope.lookup(s, location);

		if (store is null) {
			auto emsg = format("'%s' has no member '%s'", _scope.name, s);
			throw new CompilerError(location, emsg);
		}

		if (store.kind == ir.Store.Kind.Scope) {
			return store.s;
		}

		assert(store.node.nodeType == ir.NodeType.Variable);
		auto asDecl = cast(ir.Variable) store.node;
		assert(asDecl !is null);

		if (asDecl.type.nodeType == ir.NodeType.ArrayType) {
			return null;
		}

		assert(asDecl.type.nodeType == ir.NodeType.TypeReference);
		auto asUser = cast(ir.TypeReference) asDecl.type;
		switch (asUser.type.nodeType) with (ir.NodeType) {
		case Struct:
			auto asStruct = cast(ir.Struct) asUser.type;
			assert(asStruct !is null);
			return asStruct.myScope;
		case Class:
			auto asClass = cast(ir.Class) asUser.type;
			assert(asClass !is null);
			return asClass.myScope;
		case Interface:
			auto asInterface = cast(ir._Interface) asUser.type;
			assert(asInterface !is null);
			return asInterface.myScope;
		default:
			throw new CompilerError(asUser.location, "can't retrieve members from type.");
		}
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
		if (postfix.arguments.length != (asFunctionType.params.length - (asFunctionType.hiddenParameter ? 1 : 0))) {
			throw new CompilerError(postfix.location, "wrong number of arguments to function.");
		}
		foreach (i; 0 .. postfix.arguments.length) {
			extype(asFunctionType.params[i].type, postfix.arguments[i]);
		}
	}

	ir.Node extype(ir.Type left, ref ir.Exp right)
	{
		if (right.nodeType == ir.NodeType.StructLiteral) {
			auto asLit = cast(ir.StructLiteral) right;
			assert(asLit !is null);
			string emsg = "cannot implicitly cast struct literal to destination.";

			auto asStruct = cast(ir.Struct) left;
			if (asStruct is null) {
				auto asTR = cast(ir.TypeReference) left;
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

		ir.Node t = getExpType(right, current);

		auto asTR = cast(ir.TypeReference) left;
		if (asTR !is null) {
			left = asTR.type;
		}

		ir.Type type = cast(ir.Type)t;
		string emsg = format("cannot implicitly convert '%s' to '%s'.", to!string(t.nodeType), to!string(left.nodeType));

		if (type !is null && typesEqual(left, type)) {
			return left;
		}

		if (left.nodeType == ir.NodeType.PrimitiveType &&
			t.nodeType == ir.NodeType.PrimitiveType) {

			return extypePrimitiveAssign(right, left, right);
		} else if (left.nodeType == ir.NodeType.PointerType &&
					t.nodeType == ir.NodeType.PointerType) {
			return extypePointerAssign(right, left, right);
		} else if (left.nodeType == ir.NodeType.ArrayType &&
				   t.nodeType == ir.NodeType.ArrayType) {
			return extypeArrayAssign(right, left, right);
		} else if (left.nodeType == ir.NodeType.Class &&
				   t.nodeType == ir.NodeType.Class) {
			auto leftClass = cast(ir.Class) left;
			assert(leftClass !is null);
			auto rightClass = cast(ir.Class) t;
			assert(rightClass !is null);
			/// Check for converting child classes into parent classes.
			if (leftClass !is null && rightClass !is null) {
				if (inheritsFrom(rightClass, leftClass)) {
					right = new ir.Unary(new ir.TypeReference(left, leftClass.name), right);
					return left;
				}
			}

			if (leftClass !is rightClass) {
				throw new CompilerError(right.location, emsg);
			}
			return left;
		} else if ((left.nodeType == ir.NodeType.PointerType &&
			 	   t.nodeType == ir.NodeType.Class) ||
				   (left.nodeType == ir.NodeType.Class &&
				   t.nodeType == ir.NodeType.PointerType)) {
			/* This is the case when using a function that takes a
			 * class instance in one module from another before the
			 * latter module's class lowerer has turned it into the
			 * struct pointer. We know it'll run eventually, so just
			 * verify that the struct and class agree, and move on.
			 */ 
			auto asClass = cast(ir.Class) t;
			if (asClass is null) {
				asClass = cast(ir.Class) left;
				assert(asClass !is null);
			}
			
			auto asPointer = cast(ir.PointerType) left;
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
		} else if (left.nodeType == ir.NodeType.DelegateType &&
				   t.nodeType == ir.NodeType.DelegateType) {
			auto ldg = cast(ir.DelegateType) left;
			auto rdg = cast(ir.DelegateType) t;
			assert(ldg !is null && rdg !is null);

			if (typesEqual(ldg, rdg)) {
				return ldg;
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

		ir.Node left = getExpType(bin.left, current);
		ir.Node right = getExpType(bin.right, current);
		
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
		auto rp = cast(ir.ArrayType) getExpType(src, current);

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
		return Continue;
	}

	override Status enter(ir.Postfix p)
	{
		extypePostfix(p);
		return Continue;
	}

	override Status enter(ir.Variable d)
	{
		if (d.assign is null) {
			return Continue;
		}
		acceptExp(d.assign, this);

		extype(d.type, d.assign);

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

		ir.Node t = getExpType(ifs.exp, current);
		if (t.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) t;
			if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
				return Continue;
			}
		}
		ifs.exp = new ir.Unary(new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool), ifs.exp);
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

		ir.Node t = getExpType(fs.test, current);
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
		acceptExp(ws.condition, this);

		ir.Node t = getExpType(ws.condition, current);
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
		acceptExp(ds.condition, this);

		ir.Node t = getExpType(ds.condition, current);
		if (t.nodeType == ir.NodeType.PrimitiveType) {
			auto asPrimitive = cast(ir.PrimitiveType) t;
			if (asPrimitive.type == ir.PrimitiveType.Kind.Bool) {
				return Continue;
			}
		}
		ds.condition = new ir.Unary(new ir.PrimitiveType(ir.PrimitiveType.Kind.Bool), ds.condition);
		return Continue;
	}

	override Status enter(ir.SwitchStatement ss)
	{
		acceptExp(ss.condition, this);
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
			acceptExp(rs.exp, this);
			extype(functionRet, rs.exp);
		} else {
			auto v = new ir.PrimitiveType(ir.PrimitiveType.Kind.Void);
			if (!typesEqual(functionRet, v))
				throw new CompilerError(rs.location, "function return type is not void.");
		}
		return Continue;
	}

	override Status enter(ref ir.Exp e, ir.Postfix p)
	{
		if (p.op != ir.Postfix.Op.Identifier)
			return Continue;

		string[] idents;
		ir.Postfix currentP = p;
		while (true) {
			if (currentP.identifier is null)
				throw CompilerPanic(currentP.location, "null identifier");

			idents ~= currentP.identifier.value;

			if (currentP.child.nodeType == ir.NodeType.Postfix) {
				auto child = cast(ir.Postfix) currentP.child;

				// for things like func().structVar;
				if (child.op != ir.Postfix.Op.Identifier) {
					return acceptExp(currentP.child, this);
				}

				currentP = child;

			} else if (currentP.child.nodeType == ir.NodeType.IdentifierExp) {
				auto identExp = cast(ir.IdentifierExp) currentP.child;
				idents ~= identExp.value;
				break;
			} else {
				throw CompilerPanic(currentP.location, "strange postfix child");
			}
		}

		ir.Scope _scope = current;
		ir.ExpReference _ref;
		/// Fillout _ref with data from ident.
		void filloutReference(string ident)
		{
			_ref = new ir.ExpReference();
			_ref.location = p.location;
			_ref.idents = idents;

			auto store = _scope.lookup(ident, p.location);
			if (store is null) {
				throw new CompilerError(p.location, format("unknown identifier '%s'.", ident));
			}
			if (store.kind == ir.Store.Kind.Value) {
				auto var = cast(ir.Variable) store.node;
				assert(var !is null);
				_ref.decl = var;
			} else if (store.kind == ir.Store.Kind.Function) {
				assert(store.functions.length == 1);
				auto fn = store.functions[0];
				_ref.decl = fn;
			} else if (store.kind == ir.Store.Kind.Type) {
				throw CompilerPanic(p.location, "ExpReferences can't hold types, related to aggregate test 5.");
			} else {
				auto emsg = format("unhandled Store kind: '%s'.", to!string(store.kind));
				throw CompilerPanic(_ref.location, emsg);
			}
		}

		if (idents.length > 1) for (int i = cast(int)idents.length - 1; i > 0; --i) {
			if (i > 1) {
				_scope = getChildScope(p.location, _scope, idents[i]);
				if (_scope is null) {
					return Continue;
				}
			} else {
				auto store = _scope.lookup(idents[i], p.location);
				if (store is null) {
					auto emsg = format("'%s' has no member '%s'.", _scope.name, idents[i]);
					throw new CompilerError(p.location, emsg);
				}
				assert(store !is null);
				if (store.kind == ir.Store.Kind.Scope) {
					_scope = store.s;
					assert(i == 1);
					filloutReference(idents[0]);
					e = _ref;
					return ContinueParent;
				} else {
					filloutReference(idents[i]);
				}
			}
		} else if (idents.length == 1) {
			filloutReference(idents[0]);
		}

		if (_ref.decl is null) {
			return Continue;
			//throw CompilerPanic(_ref.location, "empty ExpReference declaration.");
		}

		p.child = _ref;



		/* If we end up with a identifier postfix that points
		 * at a struct, and retrieves a member function, then
		 * transform the op from Identifier to CreatePostfix.
		 */
		if (p.op == ir.Postfix.Op.Identifier && _ref.decl.declKind == ir.Declaration.Kind.Variable) {
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
			ir.Store store = asStruct.myScope.lookupOnlyThisScope(p.identifier.value, p.location);
			if (store is null) {
				throw new CompilerError(_ref.location, format("aggregate has no member '%s'.", p.identifier.value));
			}
			if (store.functions.length == 0) {
				return ContinueParent;
			}
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

	override Status visit(ref ir.Exp e, ir.ExpReference expref) { return Continue; }

	override Status leave(ref ir.Exp, ir.Postfix) { return Continue; }
	override Status enter(ref ir.Exp, ir.Unary) { return Continue; }
	override Status leave(ref ir.Exp, ir.Unary) { return Continue; }
	override Status enter(ref ir.Exp, ir.BinOp) { return Continue; }
	override Status leave(ref ir.Exp, ir.BinOp) { return Continue; }
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
	override Status visit(ref ir.Exp, ir.Constant) { return Continue; }
}
