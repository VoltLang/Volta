module test;


fn main() i32
{
	charVar: char;
	wcharVar: wchar;
	dcharVar: dchar;
	uintVar: u32;


	static is (typeof(charVar &  charVar) ==  i32);
	static is (typeof(charVar & wcharVar) ==  i32);
	static is (typeof(charVar & dcharVar) == u32);

	static is (typeof(wcharVar &  charVar) ==  i32);
	static is (typeof(wcharVar & wcharVar) ==  i32);
	static is (typeof(wcharVar & dcharVar) == u32);

	static is (typeof(dcharVar &  charVar) == u32);
	static is (typeof(dcharVar & wcharVar) == u32);
	static is (typeof(dcharVar & dcharVar) == u32);


	static is (typeof( charVar &     0xff) ==  i32);
	static is (typeof(    0xff &  charVar) ==  i32);

	static is (typeof(wcharVar &     0xff) ==  i32);
	static is (typeof(    0xff & wcharVar) ==  i32);

	static is (typeof(dcharVar &     0xff) == u32);
	static is (typeof(    0xff & dcharVar) == u32);

	static is (typeof(dcharVar &  uintVar) == u32);
	static is (typeof( uintVar & dcharVar) == u32);


	return 0;
}
