//T compiles:yes
//T retval:16
// The nested transforms should not interfere with implicit casting.    
module test;

int main() {
	long x = 4;
	short func() { return cast(short)(12 + x); }
	return func();
}
