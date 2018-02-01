//T macro:expect-failure
//T check:is not a valid traits modifier
module main;

fn aFunction!(T)() i32
{
	static if (!is(@elementzOf!T == char)) {
		return 2;
	} else {
		return 1;
	}
}

alias A = char;
alias B = char[];
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
