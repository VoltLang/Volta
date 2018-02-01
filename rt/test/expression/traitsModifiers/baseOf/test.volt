module main;

fn aFunction!(T)() i32
{
	static if (is(@baseOf!T == @isImmutable)) {
		return 2;
	} else {
		return 1;
	}
}

alias A = immutable(i32)*;
alias B = const(i32)*;
fn a = mixin aFunction!(A);
fn b = mixin aFunction!(B);

fn main() i32
{
	if (a() != 2) {
		return 1;
	}
	if (b() != 1) {
		return 2;
	}
	return 0;
}
