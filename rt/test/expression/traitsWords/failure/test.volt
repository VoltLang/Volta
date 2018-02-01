//T macro:expect-failure
//T check:not a valid traits word
module main;

fn aFunction!(T)() i32
{
	arg: T;
	static if (is(T == @isArrays)){ 
		static if (is(typeof(arg[0]) == @isImmutable)) {
			return 2;
		} else {
			return 3;
		}
	} else {
		return 1;
	}
}

fn a = mixin aFunction!(string);
fn b = mixin aFunction!(i32[string]);

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
