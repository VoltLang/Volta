// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.manglewriter;

import std.conv;
import std.stdio;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.semantic.classify;
import volt.semantic.mangle;

/**
 * Apply mangle symbols to Types and Functions.
 *
 * @ingroup passes passLang
 */
class MangleWriter : NullVisitor, Pass
{
public:
	string[] parentNames;
	int functionDepth;
	int aggregateDepth;

public:
	override void transform(ir.Module m)
	{
		parentNames = getParentScopeNames(m.myScope);
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.Struct s)
	{
		parentNames = getParentScopeNames(s.myScope);
		aggregateDepth++;
		return Continue;
	}

	override Status leave(ir.Struct s)
	{
		aggregateDepth--;
		parentNames = parentNames[0 .. $-1];
		return Continue;
	}


	override Status enter(ir.Class c)
	{
		parentNames = getParentScopeNames(c.myScope);
		aggregateDepth++;
		return Continue;
	}

	override Status leave(ir.Class c)
	{
		aggregateDepth--;
		parentNames = parentNames[0 .. $-1];
		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		parentNames = getParentScopeNames(fn.myScope);
		/// @todo check other linkage as well.
		if (fn.mangledName !is null) {
			// Do nothing.
		} else if (fn.name == "main" &&
		           fn.type.linkage != ir.Linkage.C) {
			fn.mangledName = "vmain";
		} else if (fn.type.linkage == ir.Linkage.C || fn.type.linkage == ir.Linkage.Windows) {
			fn.mangledName = fn.name;
		} else {
			fn.mangledName = mangle(parentNames, fn);
		}
		functionDepth++;
		aggregateDepth++;
		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		functionDepth--;
		aggregateDepth--;
		parentNames = parentNames[0 .. $-1];
		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		if (a.type.mangledName != "") {
			return Continue;
		}
		a.type.mangledName = mangle(parentNames, a.type);
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		if (v.mangledName != "") {
			return Continue;
		}
		if (functionDepth > 0) {
			/// @todo mangle static variables, but we need static for that.
			return Continue;
		}
		if (aggregateDepth == 0) {
			// Module level -- ensure global or local is specified.
			if (v.storage == ir.Variable.Storage.None) {
				throw new CompilerError(v.location, "module level variables must be explicitly global or local.");
			}
		}

		if (v.linkage != ir.Linkage.C && v.linkage != ir.Linkage.Windows) {
			v.mangledName = mangle(parentNames, v);
		} else {
			v.mangledName = v.name;
		}

		return Continue;
	}

	override Status visit(ir.Constant c)
	{
		if (c.type !is null) {
			c.type.mangledName = mangle(parentNames, c.type);
		}
		return Continue;
	}

	override Status debugVisitNode(ir.Node n)
	{
		auto t = cast(ir.Type) n;
		if (t is null) {
			return Continue;
		}

		if (t.mangledName != "") {
			return Continue;
		}

		t.mangledName = mangle(parentNames, t);
		return Continue;
	}
}
