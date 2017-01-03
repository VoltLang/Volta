module test;

fn sproznak(x: i32) i32
{
	return x;
}

@property fn PI() f64
{
	return 3.1415926538;
}

@property fn IGNORE(s: string)
{
}

struct AnotherStruct
{
	@property fn overloadedProp() i32
	{
		return 7;
	}

	@property fn overloadedProp(x: i32)
	{
	}
}

struct Struct
{
	x: i32;
	as: AnotherStruct;

	@property fn block(b: i32) i32
	{
		return x = b;
	}

	@property fn block() i32
	{
		return x;
	}

	fn foo() i32
	{
		block = 7;
		b := block;
		c := as.overloadedProp;
		as.overloadedProp = 54;
		return sproznak(block) + c;
	}
}

fn main() i32
{
	d: f64 = PI;
	IGNORE = "foo";
	s: Struct;
	return s.foo() - 14;
}

