// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.visitor.mangleprinter;

import std.conv;
import std.stdio;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.visitor.visitor;
import volt.semantic.mangle;

/// Apply mangle symbols to Types and Functions.
class ManglePrinter : NullVisitor, Pass
{
public:
	string[] parentNames;

public:
	override void transform(ir.Module m)
	{
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
		return Continue;
	}

	override Status leave(ir.Struct s)
	{
		parentNames = parentNames[0 .. $-1];
		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		writeln(mangle(parentNames, fn.type));
		return ContinueParent;
	}

	override Status debugVisitNode(ir.Node n)
	{
		auto t = cast(ir.Type) n;
		if (t is null) {
			return Continue;
		}

		t.mangledName = mangle(parentNames, t);
		writeln(t.mangledName);
		return Continue;
	}
}
