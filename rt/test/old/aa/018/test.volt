//T compiles:yes
//T retval:3
module test;

int main()
{
	string[string] aa = ["volt":"rox"];
	return cast(int)aa["volt"].length;
}

