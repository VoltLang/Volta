//T compiles:yes
//T retval:42
module test;


int main()
{
	char charVar;
	wchar wcharVar;
	dchar dcharVar;
	uint uintVar;


	static is (typeof(charVar &  charVar) ==  int);
	static is (typeof(charVar & wcharVar) ==  int);
	static is (typeof(charVar & dcharVar) == uint);

	static is (typeof(wcharVar &  charVar) ==  int);
	static is (typeof(wcharVar & wcharVar) ==  int);
	static is (typeof(wcharVar & dcharVar) == uint);

	static is (typeof(dcharVar &  charVar) == uint);
	static is (typeof(dcharVar & wcharVar) == uint);
	static is (typeof(dcharVar & dcharVar) == uint);


	static is (typeof( charVar &     0xff) ==  int);
	static is (typeof(    0xff &  charVar) ==  int);

	static is (typeof(wcharVar &     0xff) ==  int);
	static is (typeof(    0xff & wcharVar) ==  int);

	static is (typeof(dcharVar &     0xff) == uint);
	static is (typeof(    0xff & dcharVar) == uint);

	static is (typeof(dcharVar &  uintVar) == uint);
	static is (typeof( uintVar & dcharVar) == uint);


	return 42;
}
