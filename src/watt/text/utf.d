module watt.text.utf;

import std.utf : decode, validate;
private import std.conv : to;
private import std.utf : toUTF8, utfencode = encode;

string encode(dchar d) { return to!string(d); }
string encode(dchar[] s) { return toUTF8(s); }
void encode(ref char[] s, dchar c) { utfencode(s, c); }

void encode(void delegate(scope const(char)[]) sink, dchar c)
{
	char[] outString;
	encode(outString, c);
	sink(outString);
}
