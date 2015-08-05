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
import volt.parser.base : ParseStatus, ParserStream, ParserPanic, NodeSink;
import volt.parser.toplevel : parseModule;
import volt.parser.statements : parseStatement;


void checkError(ParserStream ps, ParseStatus status)
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
	override ir.Module parseNewFile(string source, string filename)
	{
		auto src = new Source(source, filename);
		src.skipScriptLine();

		auto ps = new ParserStream(lex(src));
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

		auto ps = new ParserStream(lex(src));
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
			string l = t.location.toString();
			string tStr = t.type.tokenToString();
			string v = t.value;
			writefln("%s %s \"%s\"", l, tStr, v);
		}

		writefln("");

		ps.reset();
	}
}
