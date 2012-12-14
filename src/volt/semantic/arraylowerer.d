// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.arraylowerer;

import std.conv : to;
import std.string : format;
import std.stdio : writeln;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.exceptions;
import volt.visitor.visitor;
import volt.visitor.expreplace;
import volt.semantic.mangle;

/**
 * Lower arrays into structs.
 *
 * So T[] becomes
 * ---
 * struct TArray {  // This will be an internal symbol, unable to clash with user symbols.
 *     T* ptr;
 *     size_t length;
 * }
 * ---
 */
class ArrayLowerer : NullVisitor, ExpReplaceVisitor, Pass
{
public:
	Settings settings;
	ir.Scope internalScope;
	ir.Struct[string] synthesised;  /// Indexed by mangled name.
	string lastArray;
	string[] parentNames;

public:
	this(Settings settings)
	{
		this.settings = settings;
	}

	/// Turn a type into a string. A protomangler, if you will.
	string tempMangle(ir.Type t)
	{
		switch (t.nodeType) with (ir.NodeType) {
		case PrimitiveType:
			auto asPrimitive = cast(ir.PrimitiveType) t;
			assert(asPrimitive !is null);
			return format("PrimitiveType%s", to!string(asPrimitive.type));
		case Struct:
			auto asStruct = cast(ir.Struct) t;
			assert(asStruct !is null);
			return asStruct.name;
		default:
			return "";
		}
	}

	string arrayStructName(ir.Type t)
	{
		return mangle(parentNames, t);
	}

	/**
	 * Create a struct to represent an array from the given Type.
	 *
	 * Adds it to the internalScope.
	 * Returns: the created struct, or null on failure.
	 */
	ir.Struct synthesiseArrayStruct(ir.ArrayType at)
	{
		auto t = at.base;
		auto name = arrayStructName(at);
		if (name == "") {
			return null;
		}
		if (auto oldStruct = name in synthesised) {
			return *oldStruct;
		}
		auto names = parentNames ~ name;

		auto s = new ir.Struct();
		s.myScope = new ir.Scope(internalScope, s, null);
		s.location = at.location;
		s.members = new ir.TopLevelBlock();
		s.members.location = at.location;
		auto ptype = new ir.PointerType(t);
		auto ltype = settings.getSizeT();

		s.myScope.addValue(ltype, "length");
		auto lengthVar = new ir.Variable();
		lengthVar.location = s.location;
		lengthVar.type = ltype;
		lengthVar.name = "length";
		s.members.nodes ~= lengthVar;

		s.myScope.addValue(ptype, "ptr");
		auto ptrVar = new ir.Variable();
		ptrVar.location = s.location;
		ptrVar.type = ptype;
		ptrVar.name = "ptr";
		s.members.nodes ~= ptrVar;

		s.name = name;
		s.mangledName = name;
		s.loweredNode = at;
		internalScope.addType(s, name);
		synthesised[name] = s;
		return s;

	}

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

	override Status enter(ir.Module m)
	{
		internalScope = m.internalScope;
		assert(internalScope !is null);
		return Continue;
	}

	override Status enter(ir.ArrayType a)
	{
		auto result = synthesiseArrayStruct(a);
		assert(result !is null);
		return Continue;
	}

	override Status enter(ir.FunctionType t)
	{
		foreach (param; t.params) {
			accept(param, this);
		}
		return Continue;
	}

	/** 
	 * Replace when we leave, in case this is the first time
	 * we've seen the ArrayType.
	 */
	override Status leave(ir.Variable d)
	{
		if (d.type.nodeType == ir.NodeType.ArrayType) {
			auto asArray = cast(ir.ArrayType) d.type;
			assert(asArray !is null);
			auto name = arrayStructName(asArray);
			if (auto s = name in synthesised) {
				auto ut = new ir.TypeReference();
				ut.names ~= s.name;
				ut.type = *s;
				ut.isInternal = true;
				d.type = ut;
			} else {
				assert(false);
			}
		}
		return Continue;
	}

	override Status enter(ir.Postfix p)
	{
		if (p.child.nodeType != ir.NodeType.ExpReference) {
			return Continue;
		}
		auto asExp = cast(ir.ExpReference) p.child;
		assert(asExp !is null);

		/// @todo check if this makes sense
		auto asVar = cast(ir.Variable) asExp.decl;
		if (asVar is null) {
			return Continue;
		}

		if (asVar.type.nodeType != ir.NodeType.TypeReference) {
			return Continue;
		}

		auto asType = cast(ir.TypeReference) asVar.type;
		if (asType is null) {
			return Continue;
		}
		
		auto asStruct = cast(ir.Struct) asType.type;
		if (asStruct is null) {
			return Continue;
		}
		if (asStruct.loweredNode is null || asStruct.loweredNode.nodeType != ir.NodeType.ArrayType) {
			return Continue;
		}

		if (p.op == ir.Postfix.Op.Identifier) {
			return Continue;
		}

		auto np = new ir.Postfix();
		np.op = ir.Postfix.Op.Identifier;
		np.child = p.child;
		np.identifier = new ir.Identifier("ptr");
		p.child = np;

		lastArray = asVar.name;
		foreach (ref arg; p.arguments) {
			acceptExp(arg, this);
		}
		lastArray = "";

		return ContinueParent;
	}

	Status enter(ref ir.Exp, ir.Postfix) { return Continue; }
	Status leave(ref ir.Exp, ir.Postfix) { return Continue; }
	Status enter(ref ir.Exp, ir.Unary) { return Continue; }
	Status leave(ref ir.Exp, ir.Unary) { return Continue; }
	Status enter(ref ir.Exp, ir.BinOp) { return Continue; }
	Status leave(ref ir.Exp, ir.BinOp) { return Continue; }
	Status enter(ref ir.Exp, ir.Ternary) { return Continue; }
	Status leave(ref ir.Exp, ir.Ternary) { return Continue; }
	Status enter(ref ir.Exp, ir.Array) { return Continue; }
	Status leave(ref ir.Exp, ir.Array) { return Continue; }
	Status enter(ref ir.Exp, ir.AssocArray) { return Continue; }
	Status leave(ref ir.Exp, ir.AssocArray) { return Continue; }
	Status enter(ref ir.Exp, ir.Assert) { return Continue; }
	Status leave(ref ir.Exp, ir.Assert) { return Continue; }
	Status enter(ref ir.Exp, ir.StringImport) { return Continue; }
	Status leave(ref ir.Exp, ir.StringImport) { return Continue; }
	Status enter(ref ir.Exp, ir.Typeid) { return Continue; }
	Status leave(ref ir.Exp, ir.Typeid) { return Continue; }
	Status enter(ref ir.Exp, ir.IsExp) { return Continue; }
	Status leave(ref ir.Exp, ir.IsExp) { return Continue; }
	Status enter(ref ir.Exp, ir.FunctionLiteral) { return Continue; }
	Status leave(ref ir.Exp, ir.FunctionLiteral) { return Continue; }

	Status visit(ref ir.Exp e, ir.Constant c)
	{
		if (c.value != "$") {
			return Continue;
		}

		if (lastArray.length == 0) {
			throw new CompilerError(c.location, "$ used outside of array index.");
		}

		auto p1 = new ir.Postfix();
		p1.op = ir.Postfix.Op.Identifier;
		p1.child = new ir.IdentifierExp(lastArray);
		p1.identifier = new ir.Identifier("length");
		e = p1;

		return Continue;
	}

	Status visit(ref ir.Exp, ir.IdentifierExp) { return Continue; }
	Status visit(ref ir.Exp, ir.ExpReference) { return Continue; }
}
