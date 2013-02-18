// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.ir.copy;

import ir = volt.ir.ir;
import volt.ir.util;


ir.Constant copy(ir.Constant cnst)
{
	auto c = new ir.Constant();
	c.location = cnst.location;
	c.type = copyType(cnst.type);
	c._ulong = cnst._ulong;
	c._string = cnst._string;
	return c;
}

ir.BlockStatement copy(ir.BlockStatement bs)
{
	auto b = new ir.BlockStatement();
	b.location = bs.location;
	b.statements = bs.statements;

	foreach (ref stat; b.statements) {
		stat = copyNode(stat);
	}

	return b;
}

ir.ReturnStatement copy(ir.ReturnStatement rs)
{
	auto r = new ir.ReturnStatement();
	r.location = rs.location;
	r.exp = copyExp(rs.exp);
	return r;
}

/**
 * Helper function that takes care of up
 * casting the return from copyDeep.
 */
ir.Type copyType(ir.Type t)
{
	/// @todo use copyDeep.
	return copyTypeSmart(t.location, t);
}

/**
 * Helper function that takes care of up
 * casting the return from copyDeep.
 */
ir.Exp copyExp(ir.Exp exp)
{
	auto n = copyNode(exp);
	exp = cast(ir.Exp)n;
	assert(exp !is null);
	return exp;
}

/**
 * Copies a node and all its children nodes.
 */
ir.Node copyNode(ir.Node n)
{
	final switch (n.nodeType) with (ir.NodeType) {
	case Invalid:
		assert(false, "invalid node");
	case NonVisiting:
		assert(false, "non-visiting node");
	case Constant:
		auto c = cast(ir.Constant)n;
		return copy(c);
	case BlockStatement:
		auto bs = cast(ir.BlockStatement)n;
		return copy(bs);
	case ReturnStatement:
		auto rs = cast(ir.ReturnStatement)n;
		return copy(rs);
	case QualifiedName:
	case Identifier:
	case Module:
	case TopLevelBlock:
	case Import:
	case Unittest:
	case Struct:
	case Class:
	case Interface:
	case Union:
	case Enum:
	case EnumMember:
	case Attribute:
	case StaticAssert:
	case MixinTemplate:
	case MixinFunction:
	case UserAttribute:
	case EmptyTopLevel:
	case Condition:
	case ConditionTopLevel:
	case FunctionDecl:
	case FunctionBody:
	case PrimitiveType:
	case TypeReference:
	case PointerType:
	case NullType:
	case ArrayType:
	case StaticArrayType:
	case AAType:
	case AAPair:
	case FunctionType:
	case DelegateType:
	case StorageType:
	case TypeOf:
	case Variable:
	case Alias:
	case Function:
	case FunctionParameter:
	case AsmStatement:
	case IfStatement:
	case WhileStatement:
	case DoStatement:
	case ForStatement:
	case LabelStatement:
	case ExpStatement:
	case SwitchStatement:
	case SwitchCase:
	case ContinueStatement:
	case BreakStatement:
	case GotoStatement:
	case WithStatement:
	case SynchronizedStatement:
	case TryStatement:
	case ThrowStatement:
	case ScopeStatement:
	case PragmaStatement:
	case EmptyStatement:
	case ConditionStatement:
	case MixinStatement:
	case Comma:
	case BinOp:
	case Ternary:
	case Unary:
	case Postfix:
	case ArrayLiteral:
	case AssocArray:
	case IdentifierExp:
	case Assert:
	case StringImport:
	case Typeid:
	case IsExp:
	case TraitsExp:
	case FunctionLiteral:
	case ExpReference:
	case StructLiteral:
	case ClassLiteral:
		goto case Invalid;
	}
}
