//T macro:expect-failure
//T check:'ifn' is already defined in this scope
module main;

fn ident!(T)(val: T) T
{
	return val;
}

struct S!(T)
{
	x: T;
}

fn ifn = mixin ident!i32;
fn ifn = mixin ident!string;
struct ifn = mixin S!i32;

fn main() i32
{
	goodMorning := ifn("おはようございます");
	if (goodMorning != "おはようございます") {
		return 1;
	}
	return ifn(12) - 12;
}
