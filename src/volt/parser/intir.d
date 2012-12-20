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

class CommaExp : IntExp
{
public:
	TernaryExp left;
	CommaExp right;  // Optional.
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
	BinOp.Type op;
	UnaryExp left;
	BinExp right;  // Optional.
}

bool isLeftAssociative(BinOp.Type operator)
{
	return operator != BinOp.Type.Assign;
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
}

class NewExp : IntExp
{
public:
	Type type;
	bool isArray;
	BinExp binExp;  // new int[binExp]
	bool hasArgumentList;
	BinExp[] argumentList;  // new int(argumentList)
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
	BinExp[] arguments;  // Optional.
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
		TypeLookup,  // Type.Identifier
		Typeof,
		Typeid,  // If exp !is null, exp. Otherwise type.
		Is,
		ParenExp,        // tlargs
		Traits,
		StructLiteral,
	}

public:
	Type op;
	volt.ir.declaration.Type type;
	Exp exp;
	string _string;      // Optional.
	BinExp[] keys;
	BinExp[] arguments;  // Optional.
	TernaryExp[] tlargs;   // Optional.
	IsExp isExp;  // Optional.
	FunctionLiteral functionLiteral;  // Optional.
}
