module main;

fn ident!(T)(val: T) T
{
	return val;
}

fn ident1 = mixin ident!i32;
fn ident2 = mixin ident!string;
alias afn = ident1;
alias afn = ident2;

fn main() i32
{
	goodMorning := afn("おはようございます");
	if (goodMorning != "おはようございます") {
		return 1;
	}
	return afn(12) - 12;
}
