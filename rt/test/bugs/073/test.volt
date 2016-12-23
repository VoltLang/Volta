//T compiles:yes
//T retval:12
module test;

enum sss = 24;

struct S {
	int s;
}

struct SS {
	S s;
}

S supplyS()
{
	S s;
	s.s = 12;
	return s;
}

global SS ss;

SS globalS()
{
	return ss;
}

int main() // s
{
	globalS().s.s = 5;
	supplyS().s = sss;
	return supplyS().s + globalS().s.s;
}

