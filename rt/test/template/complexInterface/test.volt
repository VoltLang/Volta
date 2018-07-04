module main;

interface IStack!(T)
{
	@property fn length() size_t;
	fn pop() i32;
	fn push(T);
}

// Templated class implementing template.
class SimpleStack!(T, I) : I
{
	array: T[];

	override @property fn length() size_t
	{
		return array.length;
	}

	override fn pop() i32
	{
		v := array[$-1];
		array = array[0 .. $-1];
		// Traits expressions do in fact still exist.
		static if (is(T == @isArray)) {
			return cast(i32)v.length;
		} else {
			return v;
		}
	}

	override fn push(val: T)
	{
		array ~= val;
	}
}

interface IIntegerStack  = IStack!i32;
interface IStringStack   = IStack!string;
class SimpleIntegerStack = SimpleStack!(i32, IIntegerStack);
class SimpleStringStack  = SimpleStack!(string, IStringStack);

fn sumStack!(StackInterface)(stack: StackInterface) i32
{
	s: i32;
	while (stack.length > 0) {
		s += stack.pop();
	}
	return s;
}

// Overloading template instance taking templates.
fn sum = sumStack!IIntegerStack;
fn sum = sumStack!IStringStack;

fn main() i32
{
	sis := new SimpleIntegerStack();
	sis.push(5); sis.push(3); sis.push(-2); sis.push(12);
	if (sum(sis) - 18 != 0) {
		return 1;
	}

	sss := new SimpleStringStack();
	sss.push("abc"); sss.push("cdef"); sss.push("g"); sss.push(null);
	if (sum(sss) - 8 != 0) {
		return 2;
	}

	return 0;
}
