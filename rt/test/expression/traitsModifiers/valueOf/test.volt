module main;

fn aFunction!(T)() i32
{
	static if (is(@valueOf!T == i32)) {
		return 2;
	} else {
		return 1;
	}
}

alias A = i32[string];
alias B = bool[string];
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
