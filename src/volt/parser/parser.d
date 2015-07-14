// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.parser.parser;

import watt.io.std : writefln;

import volt.token.location : Location;
import volt.token.lexer : lex;
import volt.token.token : TokenType, tokenToString;
import volt.token.source : Source;

import ir = volt.ir.ir;

import volt.interfaces : Frontend;
import volt.parser.base : match;
import volt.parser.stream : ParserStream;
import volt.parser.toplevel : parseModule;
import volt.parser.statements : parseStatement;


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

		// Skip Begin.
		match(ps, TokenType.Begin);

		return .parseModule(ps);
	}

	ir.Node[] parseStatements(string source, Location loc)
	{
		auto src = new Source(source, loc);
		auto ps = new ParserStream(lex(src));
		if (dumpLex)
			doDumpLex(ps);

		match(ps, TokenType.Begin);

		ir.Node[] ret;
		while (ps != TokenType.End) {
			ret ~= parseStatement(ps);
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
