/*#D*/
// Copyright 2015, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volta.parser.errors;

import watt.text.format : format;

import volta.ir.location : Location;
import volta.ir.token : Token, TokenType, tokenToString;
import volta.ir.base : NodeType, nodeToString;


//! Describes a parse failure.
abstract class ParserError
{
public:
	enum Kind
	{
		//! No error.
		Ok = 0,
		//! The parser has made an error.
		Panic = -1,
		//! A token wasn't where we expected it to be.
		UnexpectedToken = 1,
		//! Wrong token was found.
		WrongToken,
		//! A parse failed. That failure will be i-1 on parseErrors.
		ParseFailed,
		//! A feature was used that is unsupported.
		UnsupportedFeature,
		//! An invalid integer literal was supplied.
		InvalidIntegerLiteral,
		//! We expected something and didn't get it.
		Expected,
		//! All arguments must be labelled.
		AllArgumentsMustBeLabelled,
		//! Doc comment applies to multiple nodes.
		DocCommentMultiple,
		//! Start doc comment in token stream.
		StrayDocComment,
		//! new "string without component"
		BadComposableString,
		//! Only bind imports can use multibind.
		BadMultiBind,
	}

public:
	/*!
	 * Every error type uses at least these three.
	 *  type: The type of error that occurred.
	 *  location: Where the error occurred.
	 *  nodeType: The node that was being parsed when the error occured.
	 * @{
	 */
	Kind kind;
	Location loc;
	NodeType nodeType;
	//! @}

	/*!
	 * Keeps track of where the error was raised. For internal debug.
	 * @{
	 */
	string raiseFile;
	int raiseLine;
	//! @}

public:
	this(Kind kind, Location loc, NodeType nodeType,
	     string file, const int line)
	{
		this.kind = kind;
		this.loc = loc;
		this.nodeType = nodeType;
		this.raiseFile = file;
		this.raiseLine = line;
	}

public:
	abstract string errorMessage();
}

class ParserPanic : ParserError
{
public:
	string message;  //!< The panic error message.

public:
	this(ref in Location loc, NodeType nodeType, string message,
	     string file, const int line)
	{
		super(Kind.Panic, loc, nodeType, file, line);
		this.message = message;
	}

	override string errorMessage()
	{
		return message;
	}
}

class ParserUnexpectedToken : ParserError
{
public:
	//! Found this, which is not what we where expecting.
	//! E.g. spanish inquisition.
	string found;

public:
	this(ref in Location loc, NodeType nodeType, string found,
	     string file, const int line)
	{
		super(Kind.UnexpectedToken, loc, nodeType, file, line);
		assert(found !is null);
		this.found = found;
	}

	override string errorMessage()
	{
		return format("unexpected '%s' token, while parsing %s.",
		              found, nodeToString(nodeType));
	}
}

class ParserWrongToken : ParserError
{
public:
	//! Found this, which is not what we were expecting.
	TokenType found;

	//! What we were expecting.
	TokenType expected;

public:
	this(ref in Location loc, NodeType nodeType, TokenType found,
	     TokenType expected, string file, const int line)
	{
		super(Kind.WrongToken, loc, nodeType, file, line);
		this.found = found;
		this.expected = expected;
	}

	override string errorMessage()
	{
		return format("expected '%s', got '%s'.",
		              tokenToString(expected),
		              tokenToString(found));
	}
}

class ParserParseFailed : ParserError
{
public:
	//! The node type that failed to parse.
	NodeType otherNodeType;

public:
	this(ref in Location loc, NodeType nodeType, NodeType otherNodeType,
	     string file, const int line)
	{
		super(Kind.ParseFailed, loc, nodeType, file, line);
		this.otherNodeType = otherNodeType;
	}

	override string errorMessage()
	{
		return format("failed to parse a %s while parsing a %s.",
		              nodeToString(nodeType),
		              nodeToString(otherNodeType));
	}
}

class ParserUnsupportedFeature : ParserError
{
public:
	//! The feature used.
	string description;

public:
	this(ref in Location loc, NodeType nodeType, string description,
	     string file, const int line)
	{
		super(Kind.UnsupportedFeature, loc, nodeType, file, line);
		this.description = description;
	}

	override string errorMessage()
	{
		return format("unsupported feature '%s', while parsing %s.",
		              description, nodeToString(nodeType));
	}
}

class ParserInvalidIntegerLiteral : ParserError
{
public:
	this(ref in Location loc, NodeType nodeType, string file, const int line)
	{
		super(Kind.InvalidIntegerLiteral, loc, nodeType, file, line);
	}

	override string errorMessage()
	{
		return "invalid integer literal.";
	}
}

class ParserAllArgumentsMustBeLabelled : ParserError
{
	this(ref in Location loc, string file, const int line)
	{
		super(Kind.AllArgumentsMustBeLabelled, loc, NodeType.Postfix, file, line);
	}

	override string errorMessage()
	{
		return "all arguments must be labelled.";
	}
}


class ParserExpected : ParserError
{
public:
	string message;  //!< What was expected.

public:
	this(ref in Location loc, NodeType nodeType, string message,
	     string file, const int line)
	{
		super(Kind.Expected, loc, nodeType, file, line);
		this.message = message;
	}

	override string errorMessage()
	{
		return format("expected %s.", message);
	}
}

class ParserDocMultiple : ParserError
{
public:
	this(ref in Location loc, string file, const int line)
	{
		super(Kind.DocCommentMultiple, loc, NodeType.Invalid, file, line);
	}

	override string errorMessage()
	{
		return "doc comment applies to multiple nodes.";
	}
}

class ParserStrayDocComment : ParserError
{
public:
	this(ref in Location loc, string file, const int line)
	{
		super(Kind.StrayDocComment, loc, NodeType.Invalid, file, line);
	}

	override string errorMessage()
	{
		return "stray doc comment.";
	}
}

class ParserNotAComposableString : ParserError
{
public:
	this(ref in Location loc, string file, const int line)
	{
		super(Kind.BadComposableString, loc, NodeType.Invalid, file, line);
	}

	override string errorMessage()
	{
		return `expected a composable string component (${...}) in the string.`;
	}
}


class ParserBadMultiBind : ParserError
{
public:
	this(ref in Location loc, string file, const int line)
	{
		super(Kind.BadMultiBind, loc, NodeType.Invalid, file, line);
	}

	override string errorMessage()
	{
		return "multi import lists (`[foo, bar]`) may only be used in bind imports (`import baz = [foo, bar]`)";
	}
}
