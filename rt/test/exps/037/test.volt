//T compiles:yes
//T retval:23
module test;

int main()
{
	size_t x = typeid(int).size;
	x += typeid(short[]).base.size;
	x += typeid(short[3]).staticArrayLength;
	x += typeid(byte[long]).key.size + typeid(short[long]).value.size;
	x += typeid(short function(byte, short)).ret.size + typeid(short function(byte, short)).args.length;
	return cast(int) x;
}

