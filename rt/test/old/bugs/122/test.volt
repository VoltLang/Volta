//T compiles:yes
//T retval:2
module test;


// The array literal gets the wrong type and turn into a int[].
// Probably the typer overriding the type, which it shouldn't.
global ubyte[] arr = [
	0x01, 0x02, 0x03
];

int main()
{
	return arr[1];
}
