module volt.main;

import watt.io;
import watt.conv : toString;

import volt.exceptions;
import volt.token.source;
import volt.token.lexer;
import volt.token.token;
import volt.parser.toplevel;
import ir = volt.ir.ir;

int main(string[] args)
{
	try {
		return realMain(args);
	} catch (object.Exception e) {
		output.writefln("\nException\n%s:%s: '%s'", e.file, e.line, e.message);
		return 1;
	} catch (object.Throwable e) {
		output.writefln("\nThrowable\n%s:%s: '%s'", toString(e.throwFile), e.throwLine, e.message);
		return 1;
	}
	assert(false);
}

int realMain(string[] args)
{
	if (args.length == 1) {
		output.writefln("usage: %s [files]\n", args[0]);
		return 1;
	}
	foreach (arg; args[1 .. args.length]) {
		try {
			doFile(arg);
		} catch (object.Exception e) {
			output.writefln("\nException\n%s:%s: '%s'", e.file, e.line, e.message);
		} catch (object.Throwable e) {
			output.writefln("\nThrowable\n%s:%s: '%s'", toString(e.throwFile), e.throwLine, e.message);
		}
	}
	return 0;
}

void doFile(string arg)
{
	auto src = new Source(arg);
	output.writef("  VIV    %s", arg);
	output.flush();
	auto ts = lex(src);
	ts.get();  // Eat TokenType.Begin.
	auto mod = parseModule(ts);
	output.writefln(" ... done");
}
