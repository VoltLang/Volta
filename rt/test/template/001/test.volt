//T default:no
//T macro:syntax-only
module test;

struct Struct!(T)
{
	t: T;
}

union Union!(T)
{
	t: T;
}

class Class!(T)
{
	t: T;
}

interface Iface!(T)
{
	fn t() T;
}

fn Function!(T)(a: T) T
{
	return a;
}

struct OmitParens!T
{
	T t;
}

struct MultipleParams!(T, J)
{
	t: T;
	j: J;
}

