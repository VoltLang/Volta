// Copyright © 2012, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.intir;

import volt.ir.base;
import volt.ir.type;
import volt.ir.declaration;
import volt.ir.expression;


/*
 * This file contains an internal pre IR (AST) representation of IR nodes
 * to aid in parsing.
 */


class IntExp
{
public:
	Location location;
}

class AssignExp : IntExp
{
	BinOp.Op op;
	TernaryExp left;
	AssignExp right;  // Optional.
	bool taggedRef;
	bool taggedOut;
}

class TernaryExp : IntExp
{
public:
	bool isTernary;  // Otherwise, it's just a pass-through to a BinExp.
	BinExp condition;
	TernaryExp ifTrue;  // Optional.
	TernaryExp ifFalse;  // Optional.
}

class BinExp : IntExp
{
public:
	BinOp.Op op;
	UnaryExp left;
	BinExp right;  // Optional.
}

bool isLeftAssociative(BinOp.Op operator)
{
	return operator != BinOp.Op.Assign;
}

int getPrecedence(BinOp.Op operator)
{
	switch (operator) with (BinOp.Op) {
	case Pow:
		return 11;
	case Mul, Div, Mod:
		return 10;
	case Add, Sub, Cat:
		return 9;
	case LS, SRS, RS:
		return 8;
	case Less, LessEqual, GreaterEqual, Greater, In, NotIn:
		return 7;
	case Equal, NotEqual, Is, NotIs:
		return 6;
	case And:
		return 5;
	case Xor:
		return 4;
	case Or:
		return 3;
	case AndAnd:
		return 2;
	case OrOr:
		return 1;
	case Assign, AddAssign, SubAssign, MulAssign,
		 DivAssign, ModAssign, AndAssign, OrAssign,
		 XorAssign, CatAssign, LSAssign, SRSAssign,
		 RSAssign, PowAssign:
		return 0;
	default:
		assert(false);
	}
}

class UnaryExp : IntExp
{
public:
	/*
	 * I guess this may warrant some explanation.
	 * If the op is not UnaryExp.Type.None, then any data needed
	 * for that op is contained in this node, then another UnaryExp is
	 * parsed into unaryExp. This is because you can chain them,
	 *     +*a;  // For example.
	 */
	Unary.Op op;
	UnaryExp unaryExp;   // Optional.
	PostfixExp postExp;  // Optional.
	NewExp newExp;       // Optional.
	CastExp castExp;     // Optional.
	DupExp dupExp;       // Optional.
}

class NewExp : IntExp
{
public:
	Type type;
	bool isArray;
	TernaryExp exp;  // new int[binExp]
	bool hasArgumentList;
	AssignExp[] argumentList;  // new int(argumentList)
}

// new foo[3 .. 6];  // duplicate array foo.
class DupExp : IntExp
{
public:
	QualifiedName name;    // new FOO[beginning .. end]
	TernaryExp beginning;  // new foo[BEGINNING .. end]
	TernaryExp end;        // new foo[beginning .. END]
	bool shorthand;
}

class CastExp : IntExp
{
public:
	Type type;
	UnaryExp unaryExp;
}

class PostfixExp : IntExp
{
public:
	Postfix.Op op;
	PrimaryExp primary;  // Only in parent postfixes.
	PostfixExp postfix;  // Optional.
	AssignExp[] arguments;  // Optional.
	string[] labels;     // Optional, only in calls (func(a:1, b:3)).
	Identifier identifier;  // Optional.
}

class PrimaryExp : IntExp
{
public:
	enum Type
	{
		Identifier,      // _string
		DotIdentifier,   // _string
		This,
		Super,
		Null,
		True,
		False,
		Dollar,
		IntegerLiteral,  // _string
		FloatLiteral,    // _string
		CharLiteral,     // _string
		StringLiteral,   // _string
		ArrayLiteral,    // arguments
		AssocArrayLiteral,  // keys & arguments, keys.length == arguments.length
		FunctionLiteral,
		Assert,          // arguments (length == 1 or 2)
		Import,
		Type,
		Typeof,
		Typeid,          // If exp !is null, exp. Otherwise type.
		Is,
		ParenExp,        // tlargs
		Traits,
		StructLiteral,
		TemplateInstance,
		FunctionName,
		PrettyFunctionName,
		File,
		Line,
		VaArg,
	}

public:
	Type op;
	.Type type;
	Exp exp;
	string _string;      // Optional.
	AssignExp[] keys;
	AssignExp[] arguments;  // Optional.
	AssignExp[] tlargs;   // Optional.
	IsExp isExp;  // Optional.
	FunctionLiteral functionLiteral;  // Optional.
	TraitsExp trait;  // If op == Traits.
	TemplateInstanceExp _template;  // If op == TemplateInstance.
	VaArgExp vaexp;  // If op == VaArg.
}
