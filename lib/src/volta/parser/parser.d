/*#D*/
// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volta.parser.parser;

import watt.io.std : writefln;
import watt.text.format : format;

import volta.ir.location : Location;
import volta.token.lexer : lex;
import volta.ir.token : TokenType, tokenToString;
import volta.token.source : Source;

import ir = volta.ir;

import volta.errors;
import volta.interfaces : ErrorSink, Frontend;
import volta.settings : Settings;
import volta.parser.base : ParseStatus, ParserStream, NodeSink;
import volta.parser.errors : ParserPanic;
import volta.parser.toplevel : parseModule;
import volta.parser.statements : parseStatement;
import volta.parser.declaration : parseBlock;


private void checkError(ParserStream ps, ParseStatus status)
{
	if (status) {
		return;
	}

	auto e = ps.parserErrors[0];
	auto msg = e.errorMessage();
	auto p = cast(ParserPanic)e;

	void addExtraInfo() {
		msg = format("%s (peek:%s)", msg, ps.peek.value);
		foreach (err; ps.parserErrors) {
			msg = format("%s\n%s: %s (from %s:%s)",
			              msg, err.loc.toString(),
			              err.errorMessage(),
			              err.raiseFile, err.raiseLine);
		}
	}

	if (p !is null) {
		addExtraInfo();
		panic(ps.errSink, /*#ref*/e.loc, msg, e.raiseFile, e.raiseLine);
		assert(false);  // @todo abortless
	} else {
		debug addExtraInfo();
		errorMsg(ps.errSink, /*#ref*/e.loc, msg, e.raiseFile, e.raiseLine);
		assert(false);  // @todo abortless
	}
}

class Parser : Frontend
{
public:
	bool dumpLex;
	Settings settings;
	ErrorSink errSink;

public:
	this(Settings settings, ErrorSink errSink)
	{
		this.settings = settings;
		this.errSink = errSink;
	}

	override ir.Module parseNewFile(string source, string filename)
	{
		auto src = new Source(source, filename, errSink);
		src.skipScriptLine();

		auto tw = lex(src);
		auto ps = new ParserStream(tw.getTokens(), settings, errSink);
		ps.magicFlagD = tw.magicFlagD;
		if (dumpLex) {
			doDumpLex(ps);
		}

		ps.get(); // Skip, stream already checks for Begin.

		ir.Module mod;
		checkError(ps, parseModule(ps, /*#out*/mod));
		return mod;
	}

	override ir.BlockStatement parseBlockStatement(ref ir.Token[] tokens)
	{
		auto parserStream = new ParserStream(tokens, settings, errSink);
		ir.BlockStatement blockStatement;
		auto parserStatus = parseBlock(parserStream, /*#out*/blockStatement);
		checkError(parserStream, parserStatus);
		return blockStatement;
	}

	override ir.Node[] parseStatements(string source, Location loc)
	{
		auto src = new Source(source, loc.filename, errSink);
		src.changeCurrentLocation(loc.filename, loc.line);

		auto tw = lex(src);
		auto ps = new ParserStream(tw.getTokens(), settings, errSink);
		ps.magicFlagD = tw.magicFlagD;
		if (dumpLex) {
			doDumpLex(ps);
		}

		ps.get(); // Skip, stream already checks for Begin.

		auto sink = new NodeSink();
		while (!ps.eof) {
			checkError(ps, parseStatement(ps, sink.push));
		}
		return sink.array;
	}

	override void close()
	{

	}

protected:
	void doDumpLex(ParserStream ps)
	{
		writefln("Dumping lexing:");

		// Skip first begin
		ps.get();

		ir.Token t;
		while(!ps.eof) {
			string l = t.loc.toString();
			string tStr = t.type.tokenToString();
			string v = t.value;
			writefln("%s %s \"%s\"", l, tStr, v);
		}

		writefln("");

		ps.reset();
	}
}
