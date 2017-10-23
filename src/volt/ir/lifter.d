/*#D*/
// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2016, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.lifter;

import ir = volt.ir.ir;
import volt.errors;


/*!
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
	abstract ir.Alias lift(ir.Alias old);
	abstract ir.FunctionParam lift(ir.FunctionParam old);
	abstract ir.TopLevelBlock lift(ir.TopLevelBlock old);
	abstract ir.Enum lift(ir.Enum old);
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
		case Ternary: return copy(cast(ir.Ternary)n);
		case AssocArray: return copy(cast(ir.AssocArray)n);
		case StringImport: return copy(cast(ir.StringImport)n);
		case IsExp: return copy(cast(ir.IsExp)n);
		case StructLiteral: return copy(cast(ir.StructLiteral)n);
		case VaArgExp: return copy(cast(ir.VaArgExp)n);
		default: throw makeUnsupported(/*#ref*/n.loc, ir.nodeToString(n.nodeType));
		}
	}

	ir.Type copyType(ir.Type n)
	{
		switch (n.nodeType) with (ir.NodeType) {
		case PrimitiveType: return copy(cast(ir.PrimitiveType)n);
		case TypeReference: return copy(cast(ir.TypeReference)n);
		case AutoType: return copy(cast(ir.AutoType)n);
		case ArrayType: return copy(cast(ir.ArrayType)n);
		case AmbiguousArrayType: return copy(cast(ir.AmbiguousArrayType)n);
		case StaticArrayType: return copy(cast(ir.StaticArrayType)n);
		case StorageType: return copy(cast(ir.StorageType)n);
		case DelegateType: return copy(cast(ir.DelegateType)n);
		case FunctionType: return copy(cast(ir.FunctionType)n);
		case PointerType: return copy(cast(ir.PointerType)n);
		case TypeOf: return copy(cast(ir.TypeOf)n);
		case NullType: return copy(cast(ir.NullType)n);
		default: throw makeUnsupported(/*#ref*/n.loc, ir.nodeToString(n.nodeType));
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
		case Function: return lift(cast(ir.Function)n);
		case ExpStatement: return copy(cast(ir.ExpStatement)n);
		case BreakStatement: return copy(cast(ir.BreakStatement)n);
		case ContinueStatement: return copy(cast(ir.ContinueStatement)n);
		case ReturnStatement: return copy(parent, cast(ir.ReturnStatement)n);
		case AssertStatement: return copy(cast(ir.AssertStatement)n);
		case GotoStatement: return copy(cast(ir.GotoStatement)n);
		case WithStatement: return copy(parent, cast(ir.WithStatement)n);
		case ThrowStatement: return copy(cast(ir.ThrowStatement)n);
		case TryStatement: return copy(parent, cast(ir.TryStatement)n);
		default:
			throw panic(n, ir.nodeToString(n));
		}
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

	ir.QualifiedName copyQualifiedName(ir.QualifiedName old)
	{
		return copy(old);
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

	ir.IsExp copy(ir.IsExp old)
	{
		auto n = new ir.IsExp(old);
		n.type = copyType(old.type);
		if (old.specType !is null) {
			n.specType = copyType(old.specType);
		}
		return n;
	}

	ir.VaArgExp copy(ir.VaArgExp old)
	{
		auto n = new ir.VaArgExp(old);
		n.arg = copyExp(old.arg);
		n.type = copyType(old.type);
		return n;
	}

	ir.StructLiteral copy(ir.StructLiteral old)
	{
		auto n = new ir.StructLiteral(old);
		foreach (i; 0 .. old.exps.length) {
			n.exps[i] = copyExp(old.exps[i]);
		}
		if (old.type !is null) {
			n.type = copyType(old.type);
		}
		return n;
	}

	ir.StringImport copy(ir.StringImport old)
	{
		auto n = new ir.StringImport(old);
		n.filename = copyExp(old.filename);
		return n;
	}

	ir.AssocArray copy(ir.AssocArray old)
	{
		auto n = new ir.AssocArray(old);
		foreach (i; 0 .. old.pairs.length) {
			n.pairs[i] = copy(old.pairs[i]);
		}
		if (old.type !is null) {
			n.type = copyType(old.type);
		}
		return n;
	}

	ir.AAPair copy(ir.AAPair old)
	{
		auto n = new ir.AAPair(old);
		n.key = copyExp(old.key);
		n.value = copyExp(old.value);
		return n;
	}

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
		if (old.type !is null) {
			n.type = copyType(old.type);
		}
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
		if (old.value !is null) {
			n.value = copyExp(old.value);
		}
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

	ir.AssertStatement copy(ir.AssertStatement old)
	{
		auto as = new ir.AssertStatement(old);
		as.condition = copyExp(old.condition);
		if (old.message !is null) {
			as.message = copyExp(old.message);
		}
		return as;
	}

	ir.GotoStatement copy(ir.GotoStatement old)
	{
		auto gs = new ir.GotoStatement(old);
		if (old.exp !is null) {
			gs.exp = copyExp(old.exp);
		}
		return gs;
	}

	ir.ThrowStatement copy(ir.ThrowStatement old)
	{
		auto ts = new ir.ThrowStatement(old);
		ts.exp = copyExp(old.exp);
		return ts;
	}

	ir.StorageType copy(ir.StorageType old)
	{
		auto st = new ir.StorageType(old);
		if (old.base !is null) {
			st.base = copyType(old.base);
		}
		return st;
	}

	ir.TryStatement copy(ir.Scope parent, ir.TryStatement old)
	{
		assert(old.catchVars.length == old.catchBlocks.length);

		auto ts = new ir.TryStatement(old);
		ts.tryBlock = copy(parent, old.tryBlock);

		for (size_t i = 0; i < old.catchVars.length; ++i) {
			assert(old.catchBlocks[i].statements.length > 0);
			assert(old.catchBlocks[i].statements[0] is old.catchVars[i]);

			ts.catchBlocks[i] = copy(parent, old.catchBlocks[i]);

			auto var = cast(ir.Variable)ts.catchBlocks[i].statements[0];
			ts.catchVars[i] = var;
		}

		if (old.catchAll !is null) {
			ts.catchAll = copy(parent, old.catchAll);
		}
		if (old.finallyBlock !is null) {
			ts.finallyBlock = copy(parent, old.finallyBlock);
		}
		return ts;
	}

	ir.WithStatement copy(ir.Scope parent, ir.WithStatement old)
	{
		auto ws = new ir.WithStatement(old);
		ws.exp = copyExp(old.exp);
		ws.block = copy(parent, old.block);
		return ws;
	}

	ir.IfStatement copy(ir.Scope parent, ir.IfStatement old)
	{
		auto ifs = new ir.IfStatement(old);
		ifs.exp = copyExp(old.exp);
		ifs.thenState = copy(parent, old.thenState);
		if (old.elseState !is null) {
			ifs.elseState = copy(parent, old.elseState);
		}
		return ifs;
	}

	ir.WhileStatement copy(ir.Scope parent, ir.WhileStatement old)
	{
		auto ws = new ir.WhileStatement(old);
		ws.condition = copyExp(old.condition);
		ws.block = copy(parent, old.block);
		return ws;
	}

	ir.DoStatement copy(ir.Scope parent, ir.DoStatement old)
	{
		auto ws = new ir.DoStatement(old);
		ws.condition = copyExp(old.condition);
		ws.block = copy(parent, old.block);
		return ws;
	}

	ir.SwitchStatement copy(ir.Scope parent, ir.SwitchStatement old)
	{
		auto ss = new ir.SwitchStatement(old);
		ss.condition = copyExp(old.condition);
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
		auto fes = new ir.ForeachStatement(old);
		if (old.itervars.length > 0) {
			fes.itervars = new ir.Variable[](old.itervars.length);
			foreach (i; 0 .. old.itervars.length) {
				fes.itervars[i] = lift(old.itervars[i]);
			}
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
		auto fs = new ir.ForStatement(old);
		foreach (i; 0 .. old.initVars.length) {
			fs.initVars[i] = lift(old.initVars[i]);
		}
		foreach (i; 0 .. old.initExps.length) {
			fs.initExps[i] = copyExp(old.initExps[i]);
		}
		if (old.test !is null) {
			fs.test = copyExp(old.test);
		}
		foreach (i; 0 .. fs.increments.length) {
			fs.increments[i] = copyExp(old.increments[i]);
		}
		fs.block = copy(parent, old.block);
		return fs;
	}


	/*
	 *
	 * Types
	 *
	 */

	ir.AliasStaticIf copyAliasStaticIf(ir.AliasStaticIf old)
	{
		auto asi = new ir.AliasStaticIf(old);
		foreach (ref condition; asi.conditions) {
			condition = copyExp(condition);
		}
		foreach (ref type; asi.types) {
			type = copyType(type);
		}
		return asi;
	}

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

		if (old.type !is null) {
			switch (old.type.nodeType) with (ir.NodeType) {
			case Class: n.type = lift(cast(ir.Class)old.type); break;
			case Struct: n.type = lift(cast(ir.Struct)old.type); break;
			case Union: n.type = lift(cast(ir.Union)old.type); break;
			case Interface: n.type = lift(cast(ir._Interface)old.type); break;
			case Enum: n.type = lift(cast(ir.Enum)old.type); break;
			default: throw makeUnsupported(/*#ref*/old.loc, ir.nodeToString(old.type));
			}
		}

		return n;
	}

	ir.AutoType copy(ir.AutoType old)
	{
		auto at = new ir.AutoType(old);
		if (old.explicitType !is null) {
			at.explicitType = copyType(old.explicitType);
		}
		return at;
	}

	ir.StaticArrayType copy(ir.StaticArrayType old)
	{
		auto sat = new ir.StaticArrayType(old);
		if (old.base !is null) {
			sat.base = copyType(old.base);
		}
		return sat;
	}

	ir.AmbiguousArrayType copy(ir.AmbiguousArrayType old)
	{
		auto aat = new ir.AmbiguousArrayType(old);
		if (old.base !is null) {
			aat.base = copyType(old.base);
		}
		if (old.child !is null) {
			aat.child = copyExp(old.child);
		}
		return aat;
	}

	ir.ArrayType copy(ir.ArrayType old)
	{
		auto at = new ir.ArrayType(old);
		if (old.base !is null) {
			at.base = copyType(old.base);
		}
		return at;
	}

	ir.DelegateType copy(ir.DelegateType old)
	{
		auto dt = new ir.DelegateType(old);
		return cast(ir.DelegateType)copy(dt, old);
	}

	ir.CallableType copy(ir.CallableType ct, ir.CallableType old)
	{
		ct.ret = copyType(old.ret);
		for (size_t i = 0; i < old.params.length; ++i) {
			ct.params[i] = copyType(old.params[i]);
			assert(ct.params[i] !is null);
		}
		if (old.varArgsTypeids !is null) {
			ct.varArgsTypeids = lift(old.varArgsTypeids);
		}
		if (old.varArgsArgs !is null) {
			ct.varArgsArgs = lift(old.varArgsArgs);
		}
		if (old.typeInfo !is null) {
			ct.typeInfo = lift(old.typeInfo);
		}
		return ct;
	}

	ir.PointerType copy(ir.PointerType old)
	{
		auto pt = new ir.PointerType(old);
		pt.base = copyType(old.base);
		return pt;
	}

	ir.TypeOf copy(ir.TypeOf old)
	{
		auto to = new ir.TypeOf(old);
		to.exp = copyExp(old.exp);
		return to;
	}

	ir.NullType copy(ir.NullType old)
	{
		auto nt = new ir.NullType(old);
		return nt;
	}


	/*
	 *
	 * Special
	 *
	 */

	/*!
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
