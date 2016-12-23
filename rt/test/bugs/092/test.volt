//T compiles:yes
//T retval:9
module test;

class Base {}

class Sub : Base {}

int main()
{
	Base[] arr;
	Sub ins;
	ins ~ arr;
	// Extyper fails to add a cast for the concat operation above.
	// cast(Base)obj ~ arr; is what it should look like after the extyper
	// has run. And writing it in code avoids the bug.
	return 9;
}
