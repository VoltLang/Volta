// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.manglewriter;

import std.conv;
import std.stdio;

import ir = volt.ir.ir;

import volt.exceptions;
import volt.interfaces;
import volt.visitor.visitor;
import volt.semantic.mangle;

/// Apply mangle symbols to Types and Functions.
class MangleWriter : NullVisitor, Pass
{
public:
	string[] parentNames;
	int functionDepth;
	int aggregateDepth;

public:
	override void transform(ir.Module m)
	{
		// Mangle the internal symbols.
		foreach (store; m.internalScope.symbols) {
			final switch (store.kind) with (ir.Store.Kind) {
			case Value, Type:
				accept(store.node, this);
				break;
			case Function:
				assert(store.functions.length == 1);
				accept(store.functions[0], this);
				break;
			case Scope:
				break;	
			}
		}

		foreach (ident; m.name.identifiers) {
			parentNames ~= ident.value;
		}
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.Struct s)
	{
		parentNames ~= s.name;
		aggregateDepth++;
		return Continue;
	}

	override Status leave(ir.Struct s)
	{
		parentNames = parentNames[0 .. $-1];
		aggregateDepth--;
		return Continue;
	}


	override Status enter(ir.Class c)
	{
		parentNames ~= c.name;
		aggregateDepth++;
		return Continue;
	}

	override Status leave(ir.Class c)
	{
		parentNames = parentNames[0 .. $-1];
		aggregateDepth--;
		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		/// @todo check other linkage as well.
		if (fn.name == "main" ||
		    fn.type.linkage == ir.Linkage.C) {
			/// @todo Actual proper main rewriting. Requires a runtime.
			fn.mangledName = fn.name;
		} else {
			fn.mangledName = mangle(parentNames, fn);
		}
		parentNames ~= fn.name;
		functionDepth++;
		aggregateDepth++;
		return Continue;
	}

	override Status leave(ir.Function fn)
	{
		parentNames = parentNames[0 .. $-1];
		functionDepth--;
		aggregateDepth--;
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		if (v.mangledName != "") {
			return Continue;
		}
		if (functionDepth > 0) {
			// If we're in a function, only mangle static variables.
			if (v.type.nodeType != ir.NodeType.StorageType) {
				return Continue;
			}
			auto asStorage = cast(ir.StorageType) v.type;
			assert(asStorage !is null);
			if (asStorage.type != ir.StorageType.Kind.Static) {
				return Continue;
			}
		}
		if (aggregateDepth == 0) {
			// Module level -- ensure global or local is specified.
			if (v.storage == ir.Variable.Storage.None) {
				throw new CompilerError(v.location, "module level variables must be explicitly global or local.");
			}
		}

		v.mangledName = mangle(parentNames, v);
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
