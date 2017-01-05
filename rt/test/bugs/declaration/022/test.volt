module test;

class Base {}
class Sub : Base {}

int main()
{
	baseArr: Base[];
	subArr: Sub[];
	baseArr ~ subArr;
	// The extyper adds a extra erroneue cast like this:
	// baseArr ~ cast(Base)cast(Base[])subArr
	// Typing "baseArr ~ cast(Base[])subArr;" instead avoids the bug.
	// Remember to check ~= version as well.
	return 0;
}
