module watt.text.utf;

public import std.utf : decode, validate;
private import std.conv : to;
private import std.utf : utfencode = encode;
private import std.utf;

string encode(dchar d) { return to!string(d); }
string encode(dchar[] s) { return toUTF8(s); }
void encode(ref char[] s, dchar c) { utfencode(s, c); }

void encode(void delegate(scope const(char)[]) sink, dchar c)
{
	char[4] sbuf;
	sink(sbuf[0 .. utfencode(sbuf, c)]);
}
