//T compiles:yes
//T retval:4
// Tests TypeInfo lowering.
module test_001;

int main()
{
	object.TypeInfo tinfo = typeid(int);
	return cast(int) tinfo.size;
}
