//T compiles:yes
//T retval:7
// Tests New Lowering
module test_002;

int main()
{
	int* ip = new int;
	*ip = 7;
	return *ip;
}
