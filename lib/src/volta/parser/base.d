/*#D*/
// Copyright 2010-2011, Bernard Helyer.
// Copyright 2010, Jakob Ovrum.
// Copyright 2012, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volta.parser.base;

import watt.text.format : format;
import watt.text.string : strip, indexOf;
import watt.text.sink : StringSink;
import watt.text.vdoc : cleanComment;

import ir = volta.ir;

import volta.interfaces : ErrorSink;
import volta.settings : Settings;
public import volta.ir.token : Token, TokenType, tokenToString;
import volta.ir.tokenstream : TokenStream;
import volta.ir.location : Location;
import volta.errors;
import volta.parser.errors;
import volta.visitor.setExpLocationVisitor;


/*
 *
 * Misc.
 *
 */

enum ParseStatus {
	Succeeded = 1,
	Failed = 0
}
alias Succeeded = ParseStatus.Succeeded;
alias Failed = ParseStatus.Failed;

/*!
 * Just for convenience.
 */
alias NodeSinkDg = void delegate(ir.Node n);

/*!
 * Used as a sink for functions that return multiple nodes.
 */
class NodeSink
{
private:
	ir.Node[16] mInlineStorage;
	ir.Node[] mArray;
	size_t mNum;

public:
	this()
	{
		mArray = mInlineStorage;
		mNum = 0;
	}

	version (D_Version2) {
		final NodeSinkDg push() { return &push; }
	}

	void push(ir.Node n)
	{
		if (mNum + 1 > mArray.length) {
			auto t = new ir.Node[](mArray.length * 2);
			t[0 .. mNum] = mArray[0 .. mNum];
			mArray = t;
		}
		mArray[mNum++] = n;
	}

	void pushNodes(ir.Node[] nodes)
	{
		while (mNum + nodes.length + 1 > mArray.length) {
			auto t = new ir.Node[](mArray.length * 2);
			t[0 .. mNum] = mArray[0 .. mNum];
			mArray = t;
		}
		mArray[mNum .. nodes.length] = nodes[];
		mNum += nodes.length;
	}

	@property ir.Node[] array()
	{
		if (mArray.length > 16) {
			return mArray[0 .. mNum];
		}

		version (Volt) {
			return new ir.Node[](mArray[0 .. mNum]);
		} else {
			return mArray[0 .. mNum].dup;
		}
	}
}


/*
 *
 * Stream error rasing functions.
 *
 */

ParseStatus parsePanic(ParserStream ps, ref in Location loc,
                       ir.NodeType nodeType, string message,
                       string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserPanic(/*#ref*/loc, nodeType, message, file, line);
	ps.parserErrors ~= e;
	ps.neverIgnoreError = true;
	return Failed;
}

ParseStatus unexpectedToken(ParserStream ps, ir.NodeType ntype,
                            string file = __FILE__, const int line = __LINE__)
{
	string found = tokenToString(ps.peek.type);
	auto e = new ParserUnexpectedToken(/*#ref*/ps.peek.loc, ntype, found,
	                                   file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus unexpectedToken(ParserStream ps, ir.Node n,
                            string file = __FILE__, const int line = __LINE__)
{
	return unexpectedToken(ps, n.nodeType, file, line);
}

ParseStatus wrongToken(ParserStream ps, ir.NodeType ntype,
                       Token found, TokenType expected,
                       string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserWrongToken(/*#ref*/found.loc, ntype, found.type,
	                              expected, file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus parseFailed(ParserStream ps, ir.NodeType ntype,
                        string file = __FILE__, const int line = __LINE__)
{
	assert(ps.parserErrors.length >= 1);
	auto ntype2 = ps.parserErrors[$-1].nodeType;
	auto e = new ParserParseFailed(/*#ref*/ps.peek.loc, ntype, ntype2,
	                               file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus parseFailed(ParserStream ps, ir.Node n,
                        string file = __FILE__, const int line = __LINE__)
{
	return parseFailed(ps, n.nodeType, file, line);
}

ParseStatus parseFailed(ParserStream ps, ir.NodeType ntype, ir.NodeType ntype2,
                        string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserParseFailed(/*#ref*/ps.peek.loc, ntype, ntype2,
	                               file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus unsupportedFeature(ParserStream ps, ir.Node n, string s,
                               string file = __FILE__, const int l = __LINE__)
{
	auto e = new ParserUnsupportedFeature(/*#ref*/n.loc, n.nodeType, s, file, l);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus invalidIntegerLiteral(ParserStream ps, ref in Location loc,
                                  string file = __FILE__,
                                  const int line = __LINE__)
{
	auto e = new ParserInvalidIntegerLiteral(/*#ref*/loc, ir.NodeType.Constant,
	                                         file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus parseExpected(ParserStream ps, ref in Location loc,
                          ir.NodeType nodeType, string message,
                          string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserExpected(/*#ref*/loc, nodeType, message, file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus parseExpected(ParserStream ps, ref in Location loc,
                          ir.Node n, string message,
                          string file = __FILE__, const int line = __LINE__)
{
	return parseExpected(ps, /*#ref*/loc, n.nodeType, message, file, line);
}

ParseStatus allArgumentsMustBeLabelled(ParserStream ps, ref in Location loc,
                                       string file = __FILE__,
                                       const int line = __LINE__)
{
	auto e = new ParserAllArgumentsMustBeLabelled(/*#ref*/loc, file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus docCommentMultiple(ParserStream ps, ref in Location loc,
                               string file = __FILE__,
                               const int line = __LINE__)
{
	auto e = new ParserDocMultiple(/*#ref*/loc, file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus strayDocComment(ParserStream ps, ref in Location loc,
                            string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserStrayDocComment(/*#ref*/loc, file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus badComposable(ParserStream ps, ref in Location loc,
						  string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserNotAComposableString(/*#ref*/loc, file, line);
	ps.parserErrors ~= e;
	return Failed;
}

ParseStatus badMultiBind(ParserStream ps, ref in Location loc,
						 string file = __FILE__, const int line = __LINE__)
{
	auto e = new ParserBadMultiBind(/*#ref*/loc, file, line);
	ps.parserErrors ~= e;
	return Failed;
}

/*
 *
 * Stream checks helper functions.
 *
 */

/*!
 * Match the current token on the parserstream @ps against @type.
 * Does not advance the parserstream.
 *
 * Side-effects:
 *     If token is not type raises a unexpected token error.
 */
ParseStatus checkToken(ParserStream ps, ir.NodeType ntype, TokenType type,
                       string file = __FILE__, const int line = __LINE__)
{
	if (ps == type) {
		return Succeeded;
	}

	return wrongToken(ps, ntype, ps.peek, type, file, line);
}

/*!
 * Match the current token on the parserstream @ps against @type.
 * Does not advance the parserstream.
 *
 * Side-effects:
 *     If token is not type raises a unexpected token error.
 */
ParseStatus checkTokens(ParserStream ps, ir.NodeType ntype, scope const(TokenType)[] types,
                        string file = __FILE__, const int line = __LINE__)
{
	bool eof;
	size_t i;
	for (; i < types.length; i++) {
		if (ps.lookahead(i, /*#out*/eof).type != types[i]) {
			break;
		}
	}

	// Did the counter reach the end, all tokens checked.
	if (types.length == i) {
		return Succeeded;
	}

	return wrongToken(ps, ntype, ps.lookahead(i, /*#out*/eof), types[i], file, line);
}

/*!
 * Match the current Token on the ParserStream @ps against @type.
 *
 * Side-effects:
 *     Advances the ParserStream if the current Token is of @type.
 *     If the Token is not @type an unexpected token error is raised.
 */
ParseStatus match(ParserStream ps, ir.NodeType ntype, TokenType type,
                  string file = __FILE__, const int line = __LINE__)
{
	if (ps == type) {
		ps.get();
		return Succeeded;
	}

	return wrongToken(ps, ntype, ps.peek, type, file, line);
}

/*!
 * Match the current token on the parserstream @ps against @type.
 *
 * Side-effects:
 *     Advances the tokenstream if current token is of @type.
 *     If token is not type raises a unexpected token error.
 */
ParseStatus match(ParserStream ps, ir.Node node, TokenType type,
                  string file = __FILE__, const int line = __LINE__)
{
	if (ps == type) {
		ps.get();
		return Succeeded;
	}

	return wrongToken(ps, node.nodeType, ps.peek, type, file, line);
}

/*!
 * Match the current tokens on the parserstream @ps against @types.
 *
 * Side-effects:
 *     Advances the tokenstream if all the tokens matches @types.
 *     If token is not type raises a unexpected token error.
 */
ParseStatus match(ParserStream ps, ir.NodeType ntype, scope const(TokenType)[] types,
                  string file = __FILE__, const int line = __LINE__)
{
	bool eof;
	size_t i;
	for (; i < types.length; i++) {
		if (ps.lookahead(i, /*#out*/eof).type != types[i]) {
			break;
		}
	}

	// Did the counter reach the end, all tokens checked.
	if (types.length == i) {
		for (size_t k; k < i; k++) {
			ps.get();
		}
		return Succeeded;
	}

	return wrongToken(ps, ntype, ps.lookahead(i, /*#out*/eof), types[i], file, line);
}

/*!
 * Match the current token on the parserstream @ps against @type.
 *
 * Side-effects:
 *     Advances the tokenstream if current token is of @type.
 *     If token is not type raises a unexpected token error.
 */
ParseStatus match(ParserStream ps, ir.Node n, TokenType type, out Token tok,
                  string file = __FILE__, const int line = __LINE__)
{
	return match(ps, n.nodeType, type, /*#out*/tok, file, line);
}

/*!
 * Match the current token on the parserstream @ps against @type.
 *
 * Side-effects:
 *     Advances the tokenstream if current token is of @type.
 *     If token is not type raises a unexpected token error.
 */
ParseStatus match(ParserStream ps, ir.NodeType nodeType, TokenType type, out Token tok,
                  string file = __FILE__, const int line = __LINE__)
{
	if (ps == type) {
		tok = ps.get();
		return Succeeded;
	}

	return wrongToken(ps, nodeType, ps.peek, type, file, line);
}

/*!
 * Matches the current token on the parserstream @ps against @type
 * and if they matches gets it from the stream.
 *
 * Side-effects:
 *     None
 */
bool matchIf(ParserStream ps, TokenType type)
{
	if (ps.peek.type == type) {
		ps.get();
		return true;
	} else {
		return false;
	}
}

/*!
 * Add all doccomment tokens to the current comment level.
 */
ParseStatus eatComments(ParserStream ps)
{
	while ((ps.peek.type == TokenType.DocComment || ps.peek.type == TokenType.BackwardsDocComment) && !ps.eof) {
		auto commentTok = ps.get();
		if (commentTok.value.indexOf("@defgroup") >= 0) {
			ps.globalDocComments ~= commentTok.value;
		} else if (commentTok.type == TokenType.BackwardsDocComment) {
			if (ps.retroComment is null) {
				return strayDocComment(ps, /*#ref*/commentTok.loc);
			} else {
				ps.retroComment.docComment = commentTok.value;
			}
		} else {
			ps.addComment(commentTok);
		}
	}
	return Succeeded;
}


/*
 *
 * Common parse functions.
 *
 */


/*!
 * Parse a QualifiedName, leadingDot optinal.
 */
ParseStatus parseQualifiedName(ParserStream ps, out ir.QualifiedName name,
                               bool allowLeadingDot = false)
{
	name = new ir.QualifiedName();
	auto t = ps.peek;
	auto startLocation = t.loc;

	// Consume any leading dots if allowed, if not allowed error.
	if (allowLeadingDot && t.type == TokenType.Dot) {
		t = ps.get();
		name.leadingDot = true;
	} else if (!allowLeadingDot && t.type == TokenType.Dot) {
		return unexpectedToken(ps, ir.NodeType.QualifiedName);
	}

	// Consume all identifier dot pairs.
	do {
		ir.Identifier ident;
		auto succeeded = parseIdentifier(ps, /*#out*/ident);
		if (!succeeded) {
			return parseFailed(ps, ir.NodeType.QualifiedName);
		}
		name.identifiers ~= ident;

		if (ps == TokenType.Dot) {
			ps.get();
		} else {
			break;
		}
	} while(true);

	name.loc = t.loc - startLocation;

	return Succeeded;
}

/*!
 * Parse a single Identifier.
 */
ParseStatus parseIdentifier(ParserStream ps, out ir.Identifier i)
{
	if (ps.peek.type != TokenType.Identifier) {
		return wrongToken(ps, ir.NodeType.Identifier,
		                  ps.peek, TokenType.Identifier);
	}
	auto t = ps.get();
	i = new ir.Identifier();

	i.value = t.value;
	i.loc = t.loc;

	return Succeeded;
}

/*!
 * Returns true if the ParserStream is in a state where there is a colon
 * (along with optional identifiers and commas) before a semicolon.
 * Basically, returns true if we're at a new-style (a : i32) variable declaration.
 */
bool isColonDeclaration(ParserStream ps)
{
	bool eof;
	bool colonDeclaration = (ps.lookahead(1, /*#out*/eof).type == TokenType.Colon ||
		ps.lookahead(1, /*#out*/eof).type == TokenType.ColonAssign);
	size_t i = 1;
	while (!eof && !colonDeclaration && (ps.lookahead(i, /*#out*/eof).type == TokenType.Identifier ||
	       ps.lookahead(i, /*#out*/eof).type == TokenType.Comma)) {
		i++;
		colonDeclaration = (ps.lookahead(i, /*#out*/eof).type == TokenType.Colon ||
			ps.lookahead(i, /*#out*/eof).type == TokenType.ColonAssign);
	}
	return colonDeclaration;
}

/*!
 * Collects a an array of tokens by counting the number open/close braces, used
 * when parsing functions to delay the parsing of the function bodies.
 */
ParseStatus parseBraceCountedTokenList(ParserStream ps, out ir.Token[] tokens, ir.Node owner)
{
	if (ps.peek.type != TokenType.OpenBrace) {
		return parseFailed(ps, ir.NodeType.Function);
	}

	size_t index = ps.saveTokens();

	int braceDepth;
	do {
		auto t = ps.get();
		if (t.type == TokenType.OpenBrace) {
			braceDepth++;
		} else if (t.type == TokenType.CloseBrace) {
			braceDepth--;
		} else if (ps.eof) {
			return parseExpected(ps, /*#ref*/ps.peek.loc, owner, "closing brace");
		}
	} while (braceDepth > 0);

	tokens = ps.doneSavingTokens(index);

	return Succeeded;
}

/*!
 * Function bodies are parsed in several places, functions, ctors/dtors and
 * template functions.
 */
ParseStatus parseFunctionBody(ParserStream ps, ir.Function func)
{
	ParseStatus succeeded;

	bool inBlocks = true;
	while (inBlocks) {
		bool _in, _out;
		auto lastTokenType = ps.peek.type;
		switch (lastTokenType) {
		case TokenType.In:
			ps.get(); // <in>

			if (_in) {
				return parseExpected(ps, /*#ref*/ps.peek.loc, func, "only one in block");
			}

			_in = true;
			succeeded = parseBraceCountedTokenList(ps, /*#out*/func.tokensIn, func);
			if (!succeeded) {
				return parseFailed(ps, func);
			}
			break;
		case TokenType.Out:
			ps.get(); // <out>

			if (_out) {
				return parseExpected(ps, /*#ref*/ps.peek.loc, func, "only one out block");
			}

			_out = true;
			if (ps.peek.type == TokenType.OpenParen) {
				ps.get();
				// out <(result)>
				if (ps != [TokenType.Identifier, TokenType.CloseParen]) {
					return unexpectedToken(ps, func);
				}
				auto identTok = ps.get();
				func.outParameter = identTok.value;
				ps.get();
			}

			succeeded = parseBraceCountedTokenList(ps, /*#out*/func.tokensOut, func);
			if (!succeeded) {
				return parseFailed(ps, func);
			}
			break;
		case TokenType.Do: // D2 function bodies
		case TokenType.Body: // Volt function bodies
			ps.get(); // <body> / <do>
			goto case;
		case TokenType.OpenBrace:
			inBlocks = false;
			succeeded = parseBraceCountedTokenList(ps, /*#out*/func.tokensBody, func);
			if (!succeeded) {
				return parseFailed(ps, func);
			}
			break;
		default:
			return parseExpected(ps, /*#ref*/ps.peek.loc, func, "block declaration");
		}
	}

	return Succeeded;
}


/*
 *
 * Common class(es).
 *
 */

class ParserStream : TokenStream
{
public:
	ParserError[] parserErrors;

	//! Error raised shouldn't be ignored.
	bool neverIgnoreError;

	Token lastDocComment;
	ir.Node retroComment;  //!< For backwards doc comments (like this one).
	int multiDepth;

	Settings settings;

	//! Comments for defgroup and other commands.
	string[] globalDocComments;

	//! Did the lexer pick up a /*#D*/ magic flag?
	bool magicFlagD;

	//! Used when parsing composable strings.
	SetExpLocationVisitor setExpLocationVisitor;


private:
	string[] mComment;

public:
	this(Token[] tokens, Settings settings, ErrorSink errSink)
	{
		this.settings = settings;
		this.setExpLocationVisitor = new SetExpLocationVisitor();
		pushCommentLevel();
		super(tokens, errSink);
	}

	final @property bool eof()
	{
		return mIndex >= mTokens.length - 1;
	}

	final bool eofIndex(size_t i)
	{
		return i >= mTokens.length - 1;
	}

	/*!
	 * Get the current token and advances the stream to the next token.
	 *
	 * Side-effects:
	 *   Increments mIndex.
	 */
	final Token get()
	{
		doDocCommentBlocks();
		auto retval = mTokens[mIndex];
		if (mIndex < mTokens.length - 1) {
			mIndex++;
		}
		return retval;
	}

	size_t saveTokens()
	{
		return mIndex;
	}

	Token[] doneSavingTokens(size_t startIndex)
	{
		return mTokens[startIndex .. mIndex];
	}

	void resetErrors()
	{
		parserErrors = null;
	}

	final void pushCommentLevel()
	{
		if (inMultiCommentBlock && mComment.length > 0) {
			auto oldComment = mComment[$-1];
			mComment ~= oldComment;
		} else {
			mComment ~= [""];
		}
	}

	final void popCommentLevel()
	{
		assert(mComment.length > 0);
		string oldComment;
		if (inMultiCommentBlock) {
			oldComment = mComment[$-1];
		}
		if (mComment[$-1].length && !inMultiCommentBlock) {
			assert(lastDocComment.type != TokenType.None);
			warning(/*#ref*/lastDocComment.loc, "stray doccomment");
			return;
		}
		if (mComment.length >= 0) {
			mComment[$-1] = oldComment;
		}
	}

	//! Add a comment to the current comment level.
	final void addComment(Token comment)
	{
		assert(comment.type == TokenType.DocComment);
		auto raw = strip(comment.value);
		if (raw == "@{" || raw == "@}" || inMultiCommentBlock) {
			return;
		}
		StringSink sink;
		sink.sink(mComment[$-1]);
		sink.sink(comment.value);
		mComment[$-1] = sink.toString();
		lastDocComment = comment;
	}

	//! Retrieve and clear the current comment.
	final string comment()
	{
		assert(mComment.length >= 1);
		auto str = mComment[$-1];
		if (!inMultiCommentBlock) {
			mComment[$-1] = "";
		}
		return str;
	}

	/*!
	 * True if we found @ { on its own, so apply the last doccomment
	 * multiple times, until we see a matching number of @ }s.
	 */
	final @property bool inMultiCommentBlock()
	{
		return multiDepth > 0;
	}

private:
	final void doDocCommentBlocks()
	{
		if (mTokens[mIndex].type != TokenType.DocComment) {
			return;
		}
		auto openIndex = mTokens[mIndex].value.indexOf("@{");
		if (openIndex >= 0) {
			auto precomment = strip(mTokens[mIndex].value[0 .. openIndex]);
			if (precomment.length > 0) {
				StringSink sink;
				sink.sink(mComment[$-1]);
				sink.sink(precomment);
				mComment[$-1] = sink.toString();
			}
			multiDepth++;
			return;
		}
		if (mTokens[mIndex].value.indexOf("@}") >= 0) {
			if (!inMultiCommentBlock) {
				warning(/*#ref*/mTokens[mIndex].loc, "@} outside of multicomment block.");
				return;
			}
			multiDepth--;
			if (multiDepth == 0 && mComment.length > 0) {
				mComment[$-1] = "";
			}
		}
	}
}
