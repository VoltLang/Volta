// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.thisinserter;

import ir = volt.ir.ir;

import volt.interfaces;
import volt.semantic.lookup;
import volt.visitor.expreplace;
import volt.visitor.visitor;
import volt.visitor.scopemanager;

class ThisInserter : ScopeManager, ExpReplaceVisitor, Pass
{
public:
	override void transform(ir.Module m)
	{
		accept(m, this);
	}

	override void close() {}

	override Status enter(ir.ExpStatement estat)
	{
		acceptExp(estat.exp, this);
		return Continue;
	}

	override Status enter(ir.ReturnStatement rstat)
	{
		if (rstat.exp is null) {
			return Continue;
		}

		acceptExp(rstat.exp, this);
		return Continue;
	}

	override Status enter(ir.Variable var)
	{
		if (var.assign is null) {
			return Continue;
		}
		acceptExp(var.assign, this);
		return Continue;
	}

	override Status enter(ir.IfStatement _if)
	{
		acceptExp(_if.exp, this);
		return Continue;
	}

	override Status enter(ir.ForStatement _for)
	{
		if (_for.test is null) {
			return Continue;
		}
		acceptExp(_for.test, this);
		return Continue;
	}

	override Status enter(ir.WhileStatement _while)
	{
		acceptExp(_while.condition, this);
		return Continue;
	}

	override Status enter(ir.DoStatement _do)
	{
		acceptExp(_do.condition, this);
		return Continue;
	}
	
	Status visit(ref ir.Exp exp, ir.ExpReference reference)
	{
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
		auto asPointer = cast(ir.PointerType) asVar.type;
		assert(asPointer !is null);
		auto asTR = cast(ir.TypeReference) asPointer.base;
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

		exp = postfix;
		return Continue;
	}

	Status enter(ref ir.Exp, ir.Postfix) { return Continue; }
	Status leave(ref ir.Exp, ir.Postfix) { return Continue; }
	Status enter(ref ir.Exp, ir.Unary) { return Continue; }
	Status leave(ref ir.Exp, ir.Unary) { return Continue; }
	Status enter(ref ir.Exp, ir.BinOp) { return Continue; }
	Status leave(ref ir.Exp, ir.BinOp) { return Continue; }
	Status enter(ref ir.Exp, ir.Ternary) { return Continue; }
	Status leave(ref ir.Exp, ir.Ternary) { return Continue; }
	Status enter(ref ir.Exp, ir.ArrayLiteral) { return Continue; }
	Status leave(ref ir.Exp, ir.ArrayLiteral) { return Continue; }
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
	Status enter(ref ir.Exp, ir.StructLiteral) { return Continue; }
	Status leave(ref ir.Exp, ir.StructLiteral) { return Continue; }

	Status visit(ref ir.Exp, ir.Constant) { return Continue; }
	Status visit(ref ir.Exp, ir.IdentifierExp) { return Continue; }
}
