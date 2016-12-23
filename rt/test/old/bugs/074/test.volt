//T compiles:yes
//T retval:0
module test;

struct Struct
{
	int x;
}

global Struct _struct;

@property Struct theStruct()
{
	return _struct;
}

int main()
{
	theStruct.x = 15;
	return _struct.x;
}

