module main;

fn aFunction!(T)() i32
{
	static if (is(@keyOf!T == string)) {
		return 2;
	} else {
		return 1;
	}
}

alias A = i32[string];
alias B = bool[i32];
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
