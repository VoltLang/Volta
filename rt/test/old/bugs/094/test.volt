//T compiles:yes
//T retval:15
module simple;

class Base {}
class Sub : Base {}

int main()
{
	Base b;
	Sub s;
	// These generate bad llvm code, think its the extyper not casting s.
	// Because replacing 's' with 'cast(Base)s' fixes the errors.
	b !is s;
	b is s;

	return 15;
}
