// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.parser;

import watt.io.std : writefln;
import watt.text.format : format;

import volt.token.location : Location;
import volt.token.lexer : lex;
import volt.token.token : TokenType, tokenToString;
import volt.token.source : Source;

import ir = volt.ir.ir;

import volt.arg : Settings;
import volt.errors : makeError, panic;
import volt.interfaces : Frontend;
import volt.parser.base : ParseStatus, ParserStream, NodeSink;
import volt.parser.errors : ParserPanic;
import volt.parser.toplevel : parseModule;
import volt.parser.statements : parseStatement;


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
		throw panic(e.loc, msg, e.raiseFile, e.raiseLine);
	} else {
		debug addExtraInfo();
		throw makeError(e.loc, msg, e.raiseFile, e.raiseLine);
	}
}

class Parser : Frontend
{
public:
	bool dumpLex;
	Settings settings;

public:
	this(Settings settings)
	{
		this.settings = settings;
	}

	override ir.Module parseNewFile(string source, string filename)
	{
		auto src = new Source(source, filename);
		src.skipScriptLine();

		auto tw = lex(src);
		auto ps = new ParserStream(tw.getTokens(), settings);
		ps.magicFlagD = tw.magicFlagD;
		if (dumpLex) {
			doDumpLex(ps);
		}

		ps.get(); // Skip, stream already checks for Begin.

		ir.Module mod;
		checkError(ps, parseModule(ps, mod));
		return mod;
	}

	override ir.Node[] parseStatements(string source, Location loc)
	{
		auto src = new Source(source, loc.filename);
		src.changeCurrentLocation(loc.filename, loc.line);

		auto tw = lex(src);
		auto ps = new ParserStream(tw.getTokens(), settings);
		ps.magicFlagD = tw.magicFlagD;
		if (dumpLex) {
			doDumpLex(ps);
		}

		ps.get(); // Skip, stream already checks for Begin.

		auto sink = new NodeSink();
		while (ps != TokenType.End) {
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
		while((t = ps.get()).type != TokenType.End) {
			string l = t.loc.toString();
			string tStr = t.type.tokenToString();
			string v = t.value;
			writefln("%s %s \"%s\"", l, tStr, v);
		}

		writefln("");

		ps.reset();
	}
}
