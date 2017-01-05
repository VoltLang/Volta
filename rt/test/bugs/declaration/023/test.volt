module simple;

class Base {}
class Sub : Base {}

fn main() i32
{
	b: Base;
	s: Sub;
	// These generate bad llvm code, think its the extyper not casting s.
	// Because replacing 's' with 'cast(Base)s' fixes the errors.
	b !is s;
	b is s;

	return 0;
}
