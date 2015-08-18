//T compiles:yes
//T retval:42
//T has-passed:no
module test;

void a(out int c){}
void b(int c){}

int main()
{
	return 42;
}
