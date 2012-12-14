// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.refrep;

import std.stdio, std.conv;
import std.string : format;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.visitor.scopemanager;
import volt.visitor.expreplace;
import volt.semantic.lookup;

/** 
 * Replace identifiers with references to what they point at.
 */
class ReferenceReplacer : ScopeManager, ExpReplaceVisitor, Pass
{
public:
	/// Get a scope from n, or null if it doesn't have one.
	ir.Scope getChildScope(ir.Scope _scope, string s)
	{
		auto store = _scope.getStore(s);

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

	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.Variable v)
	{
		if (v.assign !is null) acceptExp(v.assign, this);
		return Continue;
	}

	override Status enter(ir.ExpStatement es)
	{
		acceptExp(es.exp, this);
		return Continue;
	}

	override Status enter(ir.ReturnStatement rs)
	{
		if (rs.exp !is null) acceptExp(rs.exp, this);
		return Continue;
	}

	override Status enter(ir.IfStatement ifs)
	{
		acceptExp(ifs.exp, this);
		return Continue;
	}

	override Status enter(ir.WhileStatement ws)
	{
		acceptExp(ws.condition, this);
		return Continue;
	}

	override Status enter(ir.DoStatement ds)
	{
		acceptExp(ds.condition, this);
		return Continue;
	}

	override Status enter(ir.ForStatement fs)
	{
		if (fs.test !is null) acceptExp(fs.test, this);
		foreach (ref increment; fs.increments) {
			acceptExp(increment, this);
		}
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
		if (gs.exp !is null) acceptExp(gs.exp, this);
		return Continue;
	}

	override Status enter(ir.WithStatement ws)
	{
		acceptExp(ws.exp, this);
		return Continue;
	}

	override Status enter(ir.SynchronizedStatement ss)
	{
		if (ss.exp !is null) acceptExp(ss.exp, this);
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

	override Status enter(ref ir.Exp e, ir.Postfix p)
	{
		foreach (ref arg; p.arguments) {
			acceptExp(arg, this);
		}

		string[] idents;
		ir.Postfix currentP = p;
		while (true) {
			if (currentP.identifier !is null) {
				idents ~= currentP.identifier.value;
			}
			if (currentP.child.nodeType == ir.NodeType.Postfix) {
				currentP = cast(ir.Postfix) currentP.child;
			} else if (currentP.child.nodeType == ir.NodeType.IdentifierExp) {
				auto identExp = cast(ir.IdentifierExp) currentP.child;
				idents ~= identExp.value;
				break;
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

			auto store = _scope.lookup(ident);
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
			}
		}

		if (idents.length > 1) for (int i = cast(int)idents.length - 1; i > 0; --i) {
			if (i > 1) {
				_scope = getChildScope(_scope, idents[i]);
				if (_scope is null) {
					return Continue;
				}
			} else {
				auto store = _scope.lookup(idents[i]);
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

		p.child = _ref;
		return ContinueParent;
	}

	override Status visit(ref ir.Exp e, ir.IdentifierExp i)
	{
		auto store = current.lookup(i.value);
		if (store is null) {
			throw new CompilerError(i.location, format("unidentified identifier '%s'.", i.value));
		}
		if (store.kind != ir.Store.Kind.Value) {
			return Continue;
		}
		auto var = cast(ir.Variable) store.node;
		assert(var !is null);

		auto _ref = new ir.ExpReference();
		_ref.idents ~= i.value;
		_ref.location = i.location;
		_ref.decl = var;
		e = _ref;

		return Continue; 
	}

	override Status visit(ref ir.Exp e, ir.ExpReference expref) { return Continue; }

	override Status leave(ref ir.Exp, ir.Postfix) { return Continue; }
	override Status enter(ref ir.Exp, ir.Unary) { return Continue; }
	override Status leave(ref ir.Exp, ir.Unary) { return Continue; }
	override Status enter(ref ir.Exp, ir.BinOp) { return Continue; }
	override Status leave(ref ir.Exp, ir.BinOp) { return Continue; }
	override Status enter(ref ir.Exp, ir.Ternary) { return Continue; }
	override Status leave(ref ir.Exp, ir.Ternary) { return Continue; }
	override Status enter(ref ir.Exp, ir.Array) { return Continue; }
	override Status leave(ref ir.Exp, ir.Array) { return Continue; }
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
	override Status visit(ref ir.Exp, ir.Constant) { return Continue; }
}
