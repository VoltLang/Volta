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

import volt.errors : makeError, panic;
import volt.interfaces : Frontend;
import volt.parser.base : ParseStatus, ParserStream, ParserPanic;
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
		msg ~= format(" (peek:%s)", ps.peek.value);
		foreach (err; ps.parserErrors) {
			msg ~= format("\n%s: %s (from %s:%s)",
			              err.location.toString(),
			              err.errorMessage(),
			              err.raiseFile, err.raiseLine);
		}
	}

	if (p !is null) {
		addExtraInfo();
		throw panic(e.location, msg, e.raiseFile, e.raiseLine);
	} else {
		debug addExtraInfo();
		throw makeError(e.location, msg, e.raiseFile, e.raiseLine);
	}
}

class Parser : Frontend
{
public:
	bool dumpLex;

public:
	ir.Module parseNewFile(string source, Location loc)
	{
		auto src = new Source(source, loc);
		src.skipScriptLine();
		auto ps = new ParserStream(lex(src));
		if (dumpLex)
			doDumpLex(ps);

		ps.get(); // Skip, stream already checks for Begin.

		ir.Module mod;
		checkError(ps, parseModule(ps, mod));
		return mod;
	}

	ir.Node[] parseStatements(string source, Location loc)
	{
		auto src = new Source(source, loc);
		auto ps = new ParserStream(lex(src));
		if (dumpLex)
			doDumpLex(ps);

		ps.get(); // Skip, stream already checks for Begin.

		ir.Node[] ret;
		while (ps != TokenType.End) {
			ir.Node[] nodes;
			checkError(ps, parseStatement(ps, nodes));
			ret ~= nodes;
		}

		return ret;
	}

	void close()
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
			string l = t.location.toString();
			string tStr = t.type.tokenToString;
			string v = t.value;
			writefln("%s %s \"%s\"", l, tStr, v);
		}

		writefln("");

		ps.reset();
	}
}
