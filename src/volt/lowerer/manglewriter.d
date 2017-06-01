// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.manglewriter;

import ir = volt.ir.ir;

import volt.errors;
import volt.interfaces;
import volt.visitor.visitor;

import volt.semantic.mangle;
import volt.semantic.classify;


/*!
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
		parentNames = m.name.strings;
		accept(m, this);
	}

	override void close()
	{
	}

	final void push(string name)
	{
		parentNames ~= [name];
		aggregateDepth++;
	}

	final void pop(string name)
	{
		assert(parentNames[$-1] == name);
		parentNames = parentNames[0 .. $-1];
		aggregateDepth--;
	}

	override Status enter(ir.Struct s)
	{
		mangleType(s);
		mangleType(s.loweredNode);
		push(s.name);
		return Continue;
	}
	override Status leave(ir.Struct s) { pop(s.name); return Continue; }

	override Status enter(ir.Union u) { mangleType(u); push(u.name); return Continue; }
	override Status leave(ir.Union u) { pop(u.name); return Continue; }

	override Status enter(ir.Class c)
	{
		mangleType(c);
		mangleType(c.layoutStruct);
		mangleType(c.vtableVariable.type);
		mangleType(c.initVariable.type);
		push(c.name);
		return Continue;
	}
	override Status leave(ir.Class c) { pop(c.name); return Continue; }

	override Status visit(ir.PrimitiveType pt) { mangleType(pt); return Continue; }
	override Status enter(ir.ArrayType at) { mangleType(at); return Continue; }
	override Status enter(ir.StaticArrayType sat) { mangleType(sat); return Continue; }
	override Status enter(ir.PointerType pt) { mangleType(pt); return Continue; }
	override Status enter(ir.Enum e) { mangleType(e); return Continue; }
	override Status enter(ir._Interface i) { mangleType(i); return Continue; }
	override Status enter(ir.FunctionType ft) { mangleType(ft); return Continue; }
	override Status enter(ir.DelegateType dt) { mangleType(dt); return Continue; }
	override Status visit(ir.TypeReference tr) { mangleType(tr); return Continue; }
	override Status enter(ir.AAType aat) { mangleType(aat); return Continue; }
	override Status visit(ir.NullType nt) { mangleType(nt); return Continue; }
	override Status enter(ir.AmbiguousArrayType array) { mangleType(array); return Continue; }
	override Status enter(ir.Attribute attr) { mangleType(attr); return Continue; }
	override Status enter(ir.TypeOf typeOf) { mangleType(typeOf); return Continue; }
	override Status enter(ir.EnumDeclaration ed) { mangleType(ed); return Continue; }
	override Status visit(ir.AutoType at) { mangleType(at); return Continue; }
	override Status visit(ir.NoType at) { mangleType(at); return Continue; }

	override Status enter(ir.Function func)
	{
		assert(func.name !is null);

		//! @todo check other linkage as well.
		//! @TODO this should live in the mangle code.
		if (func.mangledName !is null) {
			// Do nothing.
		} else if (func.loadDynamic) {
			// @TODO mangle this so that it becomes a variable.
			assert(func.name !is null);
			func.mangledName = mangle(parentNames, func);
		} else if (func.type.linkage == ir.Linkage.C ||
		           func.type.linkage == ir.Linkage.Windows) {
			func.mangledName = func.name;
		} else {
			assert(func.name !is null);
			func.mangledName = mangle(parentNames, func);
		}

		push(func.name);
		functionDepth++;
		return Continue;
	}

	override Status enter(ir.FunctionParam fp)
	{
		mangleType(fp.type);
		return Continue;
	}

	override Status leave(ir.Function func)
	{
		pop(func.name);
		functionDepth--;
		return Continue;
	}

	override Status enter(ir.Alias a)
	{
		mangleType(a.type);
		if (a.type is null ||
		    a.type.mangledName != "") {
			return Continue;
		}
		a.type.mangledName = mangle(a.type);
		return Continue;
	}

	override Status enter(ir.Variable v)
	{
		mangleType(v.type);

		if (v.mangledName !is null) {
			return Continue;
		}
		if (functionDepth > 0) {
			// @todo mangle static variables, but we need static for that.
			return Continue;
		}
		if (aggregateDepth == 0) {
			// Module level -- ensure global or local is specified.
			if (v.storage != ir.Variable.Storage.Local &&
			    v.storage != ir.Variable.Storage.Global) { 
				throw makeExpected(v, "global or local");
			}
		}

		if (v.linkage != ir.Linkage.C && v.linkage != ir.Linkage.Windows) {
			v.mangledName = mangle(parentNames, v);
		} else {
			v.mangledName = v.name;
		}

		return Continue;
	}

	void mangleType(ir.Node n)
	{
		auto t = cast(ir.Type) n;
		if (t is null) {
			return;
		}

		if (t.mangledName != "") {
			return;
		}
		t.mangledName = mangle(t);
	}
}
