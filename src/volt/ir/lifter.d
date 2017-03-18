// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2016, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.lifter;

import ir = volt.ir.ir;
import volt.errors;


/**
 * Base lifting class, only implements copying not lifting.
 *
 * The Lifter facilitates moving pieces of the IR to another module.
 * This is presently used in creating an environment for CTFE functions.
 */
abstract class Lifter
{
public:
	/*
	 *
	 * Reference replacers
	 *
	 */

	abstract ir.Function lift(ir.Function old);
	abstract ir.Variable lift(ir.Variable old);
	abstract ir.Class lift(ir.Class old);
	abstract ir.Union lift(ir.Union old);
	abstract ir.Struct lift(ir.Struct old);
	abstract ir._Interface lift(ir._Interface old);
	abstract ir.FunctionParam lift(ir.FunctionParam old);
	abstract ir.Node liftedOrPanic(ir.Node n, string msg);


	/*
	 *
	 * Copy dispatchers.
	 *
	 */

	ir.Exp copyExp(ir.Exp n)
	{
		switch (n.nodeType) with (ir.NodeType) {
		case AccessExp: return copy(cast(ir.AccessExp)n);
		case Constant: return copy(cast(ir.Constant)n);
		case BinOp: return copy(cast(ir.BinOp)n);
		case IdentifierExp: return copy(cast(ir.IdentifierExp)n);
		case TypeExp: return copy(cast(ir.TypeExp)n);
		case ArrayLiteral: return copy(cast(ir.ArrayLiteral)n);
		case TokenExp: return copy(cast(ir.TokenExp)n);
		case Postfix: return copy(cast(ir.Postfix)n);
		case PropertyExp: return copy(cast(ir.PropertyExp)n);
		case Unary: return copy(cast(ir.Unary)n);
		case Typeid: return copy(cast(ir.Typeid)n);
		case BuiltinExp: return copy(cast(ir.BuiltinExp)n);
		case RunExp: return copy(cast(ir.RunExp)n);
		case ExpReference: return copy(cast(ir.ExpReference)n);
		default: throw makeUnsupported(n.loc, ir.nodeToString(n.nodeType));
		}
	}

	ir.Type copyType(ir.Type n)
	{
		switch (n.nodeType) with (ir.NodeType) {
		case PrimitiveType: return copy(cast(ir.PrimitiveType)n);
		case TypeReference: return copy(cast(ir.TypeReference)n);
		default: throw makeUnsupported(n.loc, ir.nodeToString(n.nodeType));
		}
	}

	ir.Node copyStatement(ir.Scope parent, ir.Node n)
	{
		switch (n.nodeType) with (ir.NodeType) {
		case BlockStatement: assert(false);
		case IfStatement: return copy(parent, cast(ir.IfStatement)n);
		case WhileStatement: return copy(parent, cast(ir.WhileStatement)n);
		case ForStatement: return copy(parent, cast(ir.ForStatement)n);
		case ForeachStatement: return copy(parent, cast(ir.ForeachStatement)n);
		case DoStatement: return copy(parent, cast(ir.DoStatement)n);
		case SwitchStatement: return copy(parent, cast(ir.SwitchStatement)n);
		case Variable: return lift(cast(ir.Variable)n);
		case ExpStatement: return copy(cast(ir.ExpStatement)n);
		case BreakStatement: return copy(cast(ir.BreakStatement)n);
		case ContinueStatement: return copy(cast(ir.ContinueStatement)n);
		case ReturnStatement: return copy(parent, cast(ir.ReturnStatement)n);
		default:
			throw panic(n, ir.nodeToString(n));
		}
		assert(false);
	}


	/*
	 *
	 * Base
	 *
	 */

	ir.QualifiedName copy(ir.QualifiedName old)
	{
		auto n = new ir.QualifiedName(old);
		foreach (i; 0 .. n.identifiers.length) {
			n.identifiers[i] = copy(old.identifiers[i]);
		}
		return n;
	}

	ir.Identifier copy(ir.Identifier old)
	{
		return new ir.Identifier(old);
	}


	/*
	 *
	 * Declarations
	 *
	 */

	ir.FunctionParam copy(ir.FunctionParam old)
	{
		auto fparam = new ir.FunctionParam(old);
		fparam.func = lift(old.func);
		if (old.assign !is null) {
			fparam.assign = copyExp(old.assign);
		}
		return fparam;
	}


	/*
	 *
	 * Expressions
	 *
	 */

	ir.Ternary copy(ir.Ternary old)
	{
		auto n = new ir.Ternary(old);
		n.condition = copyExp(old.condition);
		n.ifTrue = copyExp(old.ifTrue);
		n.ifFalse = copyExp(old.ifFalse);
		return n;
	}

	ir.AccessExp copy(ir.AccessExp old)
	{
		auto n = new ir.AccessExp(old);
		n.child = copyExp(old.child);
		// Type should not be copied,
		// as it's a reference to a named type.
		return n;
	}

	ir.Constant copy(ir.Constant old)
	{
		auto n = new ir.Constant(old);
		n.type = copyType(old.type);
		return n;
	}

	ir.BinOp copy(ir.BinOp old)
	{
		auto n = new ir.BinOp(old);
		n.left = copyExp(old.left);
		n.right = copyExp(old.right);
		return n;
	}

	ir.IdentifierExp copy(ir.IdentifierExp old)
	{
		auto n = new ir.IdentifierExp(old);
		return n;
	}

	ir.TypeExp copy(ir.TypeExp old)
	{
		auto n = new ir.TypeExp(old);
		n.type = copyType(old.type);
		return n;
	}

	ir.ArrayLiteral copy(ir.ArrayLiteral old)
	{
		auto n = new ir.ArrayLiteral(old);
		foreach (i; 0 .. old.exps.length) {
			n.exps[i] = copyExp(old.exps[i]);
		}
		n.type = copyType(old.type);
		return n;
	}

	ir.TokenExp copy(ir.TokenExp old)
	{
		auto n = new ir.TokenExp(old);
		return n;
	}

	ir.ExpReference copy(ir.ExpReference old)
	{
		auto n = new ir.ExpReference(old);

		// Give children a chance to touch up the reference.
		final switch (n.decl.declKind) with (ir.Declaration.Kind) {
		case Function: n.decl = lift(cast(ir.Function)n.decl); break;
		case Variable: n.decl = lift(cast(ir.Variable)n.decl); break;
		case FunctionParam: n.decl = lift(cast(ir.FunctionParam)n.decl); break;
		case Invalid: assert(false, "Invalid node");
		case FunctionSet: assert(false, "FunctionSet");
		case EnumDeclaration: assert(false, "EnumDeclaration");
		}

		return n;
	}

	ir.Postfix copy(ir.Postfix old)
	{
		auto n = new ir.Postfix(old);
		n.child = copyExp(old.child);
		foreach (i; 0 .. old.arguments.length) {
			n.arguments[i] = copyExp(old.arguments[i]);
		}
		if (old.identifier !is null) {
			n.identifier = copy(old.identifier);
		}
		if (old.memberFunction !is null) {
			n.memberFunction = copy(old.memberFunction);
		}
		if (old.templateInstance !is null) {
			n.templateInstance = copyExp(old.templateInstance);
		}
		return n;
	}

	ir.PropertyExp copy(ir.PropertyExp old)
	{
		auto n = new ir.PropertyExp(old);
		if (old.child !is null) {
			n.child = copyExp(old.child);
		}
		// TODO Functions
		n.identifier = copy(old.identifier);
		return n;
	}

	ir.Unary copy(ir.Unary old)
	{
		auto n = new ir.Unary(old);
		n.value = copyExp(old.value);
		if (old.type !is null) {
			n.type = copyType(old.type);
		}
		foreach (i; 0 .. old.argumentList.length) {
			n.argumentList[i] = copyExp(old.argumentList[i]);
		}
		// TODO ctor
		if (old.dupBeginning !is null) {
			n.dupBeginning = copyExp(old.dupBeginning);
		}
		if (old.dupEnd !is null) {
			n.dupEnd = copyExp(old.dupEnd);
		}
		return n;
	}

	ir.Typeid copy(ir.Typeid old)
	{
		auto n = new ir.Typeid(old);
		if (old.exp !is null) {
			n.exp = copyExp(old.exp);
		}
		if (old.type !is null) {
			n.type = copyType(old.type);
		}
		if (old.tinfoType !is null) {
			n.tinfoType = lift(cast(ir.Class)old.tinfoType);
		}
		return n;
	}

	ir.BuiltinExp copy(ir.BuiltinExp old)
	{
		auto n = new ir.BuiltinExp(old);
		if (old.type !is null) {
			n.type = cast(ir.Type)old.type;
		}
		foreach (i; 0 .. old.children.length) {
			n.children[i] = copyExp(old.children[i]);
		}
		// TODO functions
		return n;
	}

	ir.RunExp copy(ir.RunExp old)
	{
		auto n = new ir.RunExp(old);
		n.child = cast(ir.Exp)old.child;
		return n;
	}


	/*
	 *
	 * Statements.
	 *
	 */

	ir.ReturnStatement copy(ir.Scope parent, ir.ReturnStatement old)
	{
		auto n = new ir.ReturnStatement(old);
		if (n.exp !is null) {
			n.exp = copyExp(old.exp);
		}
		return n;
	}

	ir.BlockStatement copy(ir.Scope parent, ir.BlockStatement old)
	{
		assert(old !is null);
		auto n = new ir.BlockStatement(old);
		n.myScope = copyScope(parent, n, old.myScope);

		foreach (ref stat; n.statements) {
			stat = copyStatement(n.myScope, stat);
		}

		copyStores(n.myScope, old.myScope);

		return n;
	}

	ir.BreakStatement copy(ir.BreakStatement old)
	{
		auto b = new ir.BreakStatement();
		b.loc = old.loc;
		b.label = old.label;
		return b;
	}

	ir.ContinueStatement copy(ir.ContinueStatement old)
	{
		auto c = new ir.ContinueStatement();
		c.loc = old.loc;
		c.label = old.label;
		return c;
	}

	ir.ExpStatement copy(ir.ExpStatement old)
	{
		auto es = new ir.ExpStatement();
		es.loc = old.loc;
		es.exp = copyExp(old.exp);
		return es;
	}

	ir.IfStatement copy(ir.Scope parent, ir.IfStatement old)
	{
		auto ifs = new ir.IfStatement();
		ifs.loc = old.loc;
		ifs.exp = copyExp(old.exp);
		ifs.thenState = copy(parent, old.thenState);
		if (old.elseState !is null) {
			old.elseState = copy(parent, old.elseState);
		}
		ifs.autoName = old.autoName;
		return ifs;
	}

	ir.WhileStatement copy(ir.Scope parent, ir.WhileStatement old)
	{
		auto ws = new ir.WhileStatement();
		ws.loc = old.loc;
		ws.condition = copyExp(old.condition);
		ws.block = copy(parent, old.block);
		return ws;
	}

	ir.DoStatement copy(ir.Scope parent, ir.DoStatement old)
	{
		auto ws = new ir.DoStatement();
		ws.loc = old.loc;
		ws.condition = copyExp(old.condition);
		ws.block = copy(parent, old.block);
		return ws;
	}

	ir.SwitchStatement copy(ir.Scope parent, ir.SwitchStatement old)
	{
		auto ss = new ir.SwitchStatement();
		ss.condition = copyExp(old.condition);
		ss.loc = old.loc;
		ss.isFinal = old.isFinal;
		assert(old.cases.length > 0);
		ss.cases = new ir.SwitchCase[](old.cases.length);
		foreach (i, cc; ss.cases) {
			auto oc = old.cases[i];
			auto c = ss.cases[i] = new ir.SwitchCase();
			c.loc = oc.loc;
			if (oc.firstExp !is null) {
				c.firstExp = copyExp(oc.firstExp);
			}
			if (oc.secondExp !is null) {
				c.secondExp = copyExp(oc.secondExp);
			}
			if (oc.exps.length > 0) {
				c.exps = new ir.Exp[](oc.exps.length);
				foreach (j; 0 .. c.exps.length) {
					c.exps[j] = copyExp(oc.exps[j]);
				}
			}
			c.isDefault = oc.isDefault;
			c.statements = copy(parent, oc.statements);
		}
		return ss;
	}

	ir.ForeachStatement copy(ir.Scope parent, ir.ForeachStatement old)
	{
		auto fes = new ir.ForeachStatement();
		fes.loc = old.loc;
		fes.reverse = old.reverse;
		if (old.itervars.length > 0) {
			fes.itervars = new ir.Variable[](old.itervars.length);
			foreach (i; 0 .. old.itervars.length) {
				fes.itervars[i] = lift(old.itervars[i]);
			}
		}
		version (Volt) {
			fes.refvars = new old.refvars[0 .. $];
		} else {
			fes.refvars = old.refvars.dup;
		}
		if (old.aggregate !is null) {
			fes.aggregate = copyExp(old.aggregate);
		}
		if (old.beginIntegerRange !is null) {
			fes.beginIntegerRange = copyExp(old.beginIntegerRange);
		}
		if (old.endIntegerRange !is null) {
			fes.endIntegerRange = copyExp(old.endIntegerRange);
		}
		fes.block = copy(parent, old.block);
		assert(fes.opApplyType is null);
		assert(fes.decodeFunction is null);
		return fes;
	}

	ir.ForStatement copy(ir.Scope parent, ir.ForStatement old)
	{
		auto fs = new ir.ForStatement();
		fs.loc = old.loc;
		if (old.initVars.length > 0) {
			fs.initVars = new ir.Variable[](old.initVars.length);
			foreach (i; 0 .. old.initVars.length) {
				fs.initVars[i] = lift(old.initVars[i]);
			}
		}
		if (old.initExps.length > 0) {
			fs.initExps = new ir.Exp[](old.initExps.length);
			foreach (i; 0 .. old.initExps.length) {
				fs.initExps[i] = copyExp(old.initExps[i]);
			}
		}
		if (old.test !is null) {
			fs.test = copyExp(old.test);
		}
		if (old.increments.length > 0) {
			fs.increments = new ir.Exp[](old.increments.length);
			foreach (i; 0 .. fs.increments.length) {
				fs.increments[i] = copyExp(old.increments[i]);
			}
		}
		fs.block = copy(parent, old.block);
		return fs;
	}


	/*
	 *
	 * Types
	 *
	 */

	ir.FunctionType copy(ir.FunctionType old)
	{
		auto n = new ir.FunctionType(old);
		n.ret = copyType(n.ret);
		foreach (ref type; n.params) {
			type = copyType(type);
		}
		n.ret = copyType(n.ret);
		return n;
	}

	ir.PrimitiveType copy(ir.PrimitiveType old)
	{
		return new ir.PrimitiveType(old);
	}

	ir.TypeReference copy(ir.TypeReference old)
	{
		auto n = new ir.TypeReference(old);
		if (old.id !is null) {
			n.id = copy(old.id);
		}

		assert(old.type !is null);
		switch (old.type.nodeType) with (ir.NodeType) {
		case Class: n.type = lift(cast(ir.Class)old.type); break;
		case Struct: n.type = lift(cast(ir.Struct)old.type); break;
		case Union: n.type = lift(cast(ir.Union)old.type); break;
		case Interface: n.type = lift(cast(ir._Interface)old.type); break;
		default: throw makeUnsupported(old.loc, ir.nodeToString(old.type));
		}

		return n;
	}


	/*
	 *
	 * Special
	 *
	 */

	/**
	 * Copies a Scope but not its stores.
	 */
	ir.Scope copyScope(ir.Scope parent, ir.Node owner, ir.Scope old)
	{
		auto n = new ir.Scope();
		n.parent = parent;
		n.name = old.name;
		n.anon = old.anon;
		n.node = owner;
		n.nestedDepth = old.nestedDepth;
		panicAssert(owner, old.importedModules.length == 0);
		panicAssert(owner, old.importedAccess.length == 0);
		return n;
	}

	void copyStores(ir.Scope n, ir.Scope old)
	{
		foreach (k, v; old.symbols) {
			n.symbols[k] = copyStore(n, v);
		}
	}

	ir.Store copyStore(ir.Scope parent, ir.Store old)
	{
		auto n = new ir.Store();
		n.name = old.name;
		n.parent = parent;
		n.kind = old.kind;
		n.importBindAccess = old.importBindAccess;
		n.node = liftedOrPanic(old.node, "non-lifted node in scope");

		panicAssert(old.node, old.myScope is null);
		panicAssert(old.node, old.functions is null);
		panicAssert(old.node, old.aliases is null);
		panicAssert(old.node, old.myAlias is null);
		return n;
	}
}
