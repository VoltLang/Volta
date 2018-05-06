module main;

fn ident!(T)(val: T) T
{
	return val;
}

fn ifn = mixin ident!i32;
fn ifn = mixin ident!string;

fn main() i32
{
	goodMorning := ifn("おはようございます");
	if (goodMorning != "おはようございます") {
		return 1;
	}
	return ifn(12) - 12;
}
