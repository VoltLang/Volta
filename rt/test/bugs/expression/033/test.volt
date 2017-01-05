module test;

class Base {}

class Sub : Base {}

fn main() i32
{
	arr: Base[];
	ins: Sub;
	ins ~ arr;
	// Extyper fails to add a cast for the concat operation above.
	// cast(Base)obj ~ arr; is what it should look like after the extyper
	// has run. And writing it in code avoids the bug.
	return 0;
}
