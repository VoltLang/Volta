//T compiles:yes
//T retval:0
module test;


int main()
{
	char charVar;
	byte byteVar;
	ubyte ubyteVar;
	short shortVar;
	ushort ushortVar;
	int intVar;
	uint uintVar;
	long longVar;
	ulong ulongVar;

	auto t1 = charVar + 1;
	auto t2 = byteVar + 1;
	auto t3 = ubyteVar + 1;
	auto t4 = shortVar + 1;
	auto t5 = ushortVar + 1;
	auto t6 = intVar + 1;
	auto t7 = uintVar + 1;
	auto t8 = longVar + 1;
	auto t9 = ulongVar + 1;

	static is (typeof(t1) == int);
	static is (typeof(t2) == int);
	static is (typeof(t3) == int);
	static is (typeof(t4) == int);
	static is (typeof(t5) == int);
	static is (typeof(t6) == int);
	static is (typeof(t7) == uint);
	static is (typeof(t8) == long);
	static is (typeof(t9) == ulong);

	// Any combination of char, byte, ubyte, short, ushort, int
	// should result in a type of int. Notice uint is missing.
	static is (typeof(charVar   + charVar) == int);
	static is (typeof(byteVar   + charVar) == int);
	static is (typeof(ubyteVar  + charVar) == int);
	static is (typeof(shortVar  + charVar) == int);
	static is (typeof(ushortVar + charVar) == int);
	static is (typeof(intVar    + charVar) == int);
	static is (typeof(uintVar   + charVar) == uint);
	static is (typeof(longVar   + charVar) == long);
	static is (typeof(ulongVar  + charVar) == ulong);

	static is (typeof(charVar   + byteVar) == int);
	static is (typeof(byteVar   + byteVar) == int);
	static is (typeof(ubyteVar  + byteVar) == int);
	static is (typeof(shortVar  + byteVar) == int);
	static is (typeof(ushortVar + byteVar) == int);
	static is (typeof(intVar    + byteVar) == int);
//	static is (typeof(uintVar   + byteVar) == uint);     // Error in volt
	static is (typeof(longVar   + byteVar) == long);
//	static is (typeof(ulongVar  + byteVar) == ulong);    // Error in volt

	static is (typeof(charVar   + ubyteVar) == int);
	static is (typeof(byteVar   + ubyteVar) == int);
	static is (typeof(ubyteVar  + ubyteVar) == int);
	static is (typeof(shortVar  + ubyteVar) == int);
	static is (typeof(ushortVar + ubyteVar) == int);
	static is (typeof(intVar    + ubyteVar) == int);
	static is (typeof(uintVar   + ubyteVar) == uint);
	static is (typeof(longVar   + ubyteVar) == long);
	static is (typeof(ulongVar  + ubyteVar) == ulong);

	static is (typeof(charVar   + shortVar) == int);
	static is (typeof(byteVar   + shortVar) == int);
	static is (typeof(ubyteVar  + shortVar) == int);
	static is (typeof(shortVar  + shortVar) == int);
	static is (typeof(ushortVar + shortVar) == int);
	static is (typeof(intVar    + shortVar) == int);
//	static is (typeof(uintVar   + shortVar) == uint);     // Error in volt
	static is (typeof(longVar   + shortVar) == long);
//	static is (typeof(ulongVar  + shortVar) == ulong);    // Error in volt

	static is (typeof(charVar   + ushortVar) == int);
	static is (typeof(byteVar   + ushortVar) == int);
	static is (typeof(ubyteVar  + ushortVar) == int);
	static is (typeof(shortVar  + ushortVar) == int);
	static is (typeof(ushortVar + ushortVar) == int);
	static is (typeof(intVar    + ushortVar) == int);
	static is (typeof(uintVar   + ushortVar) == uint);
	static is (typeof(longVar   + ushortVar) == long);
	static is (typeof(ulongVar  + ushortVar) == ulong);

	static is (typeof(charVar   + intVar) == int);
	static is (typeof(byteVar   + intVar) == int);
	static is (typeof(ubyteVar  + intVar) == int);
	static is (typeof(shortVar  + intVar) == int);
	static is (typeof(ushortVar + intVar) == int);
	static is (typeof(intVar    + intVar) == int);
//	static is (typeof(uintVar   + intVar) == uint);     // Error in volt
	static is (typeof(longVar   + intVar) == long);
//	static is (typeof(ulongVar  + intVar) == ulong);    // Error in volt

	static is (typeof(charVar   + uintVar) == uint);
//	static is (typeof(byteVar   + uintVar) == uint);    // Error in volt
	static is (typeof(ubyteVar  + uintVar) == uint);
//	static is (typeof(shortVar  + uintVar) == uint);    // Error in volt
	static is (typeof(ushortVar + uintVar) == uint);
//	static is (typeof(intVar    + uintVar) == uint);    // Error in volt
	static is (typeof(uintVar   + uintVar) == uint);
//	static is (typeof(longVar   + uintVar) == long);    // Error in volt
	static is (typeof(ulongVar  + uintVar) == ulong);

	static is (typeof(charVar   + longVar) == long);
	static is (typeof(byteVar   + longVar) == long);
	static is (typeof(ubyteVar  + longVar) == long);
	static is (typeof(shortVar  + longVar) == long);
	static is (typeof(ushortVar + longVar) == long);
	static is (typeof(intVar    + longVar) == long);
//	static is (typeof(uintVar   + longVar) == long);    // Error in volt
	static is (typeof(longVar   + longVar) == long);
//	static is (typeof(ulongVar  + longVar) == ulong);   // Error in volt

	static is (typeof(charVar   + ulongVar) == ulong);
//	static is (typeof(byteVar   + ulongVar) == ulong);  // Error in volt
	static is (typeof(ubyteVar  + ulongVar) == ulong);
//	static is (typeof(shortVar  + ulongVar) == ulong);  // Error in volt
	static is (typeof(ushortVar + ulongVar) == ulong);
//	static is (typeof(intVar    + ulongVar) == ulong);  // Error in volt
	static is (typeof(uintVar   + ulongVar) == ulong);
//	static is (typeof(longVar   + ulongVar) == ulong);  // Error in volt
	static is (typeof(ulongVar  + ulongVar) == ulong);

	return 0;
}
