//T compiles:yes
//T retval:1
module test;

alias BOOLEAN_TYPE_ALIAS_TOP_SECRET = bool;

int main()
{
	return BOOLEAN_TYPE_ALIAS_TOP_SECRET.max;
}
