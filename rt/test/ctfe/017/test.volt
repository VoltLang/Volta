//T compiles:yes
//T retval:6
module test;

f32 foo()
{
	return 0.0f + 0.5f;
}

int main()
{
	return (#run foo()) >= 0.25f ? 6 : 3;
}
