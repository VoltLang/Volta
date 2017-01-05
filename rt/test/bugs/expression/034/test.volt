//T default:no
//T macro:expect-failure
module test;

class Base {}

class Sub : Base {}

fn func() Base[]
{
	return null;
}

fn main() i32
{
	// This ends up in the backend and not being caught earlier.
	Base[] = cast(Base)func();
	return 0;
}
