module test;


fn main() i32
{
	charVar: char;
	byteVar: i8;
	ubyteVar: u8;
	shortVar: i16;
	ushortVar: u16;
	intVar: i32;
	uintVar: u32;
	longVar: i64;
	ulongVar: u64;

	t1 := charVar + 1;
	t2 := byteVar + 1;
	t3 := ubyteVar + 1;
	t4 := shortVar + 1;
	t5 := ushortVar + 1;
	t6 := intVar + 1;
	t7 := uintVar + 1;
	t8 := longVar + 1;
	t9 := ulongVar + 1;

	static is (typeof(t1) == i32);
	static is (typeof(t2) == i32);
	static is (typeof(t3) == i32);
	static is (typeof(t4) == i32);
	static is (typeof(t5) == i32);
	static is (typeof(t6) == i32);
	static is (typeof(t7) == u32);
	static is (typeof(t8) == i64);
	static is (typeof(t9) == u64);

	// Any combination of char, byte, ubyte, short, ushort, int
	// should result in a type of int. Notice uint is missing.
	static is (typeof(charVar   + charVar) == i32);
	static is (typeof(byteVar   + charVar) == i32);
	static is (typeof(ubyteVar  + charVar) == i32);
	static is (typeof(shortVar  + charVar) == i32);
	static is (typeof(ushortVar + charVar) == i32);
	static is (typeof(intVar    + charVar) == i32);
	static is (typeof(uintVar   + charVar) == u32);
	static is (typeof(longVar   + charVar) == i64);
	static is (typeof(ulongVar  + charVar) == u64);

	static is (typeof(charVar   + byteVar) == i32);
	static is (typeof(byteVar   + byteVar) == i32);
	static is (typeof(ubyteVar  + byteVar) == i32);
	static is (typeof(shortVar  + byteVar) == i32);
	static is (typeof(ushortVar + byteVar) == i32);
	static is (typeof(intVar    + byteVar) == i32);
//	static is (typeof(uintVar   + byteVar) == u32);     // Error in volt
	static is (typeof(longVar   + byteVar) == i64);
//	static is (typeof(ulongVar  + byteVar) == u64);    // Error in volt

	static is (typeof(charVar   + ubyteVar) == i32);
	static is (typeof(byteVar   + ubyteVar) == i32);
	static is (typeof(ubyteVar  + ubyteVar) == i32);
	static is (typeof(shortVar  + ubyteVar) == i32);
	static is (typeof(ushortVar + ubyteVar) == i32);
	static is (typeof(intVar    + ubyteVar) == i32);
	static is (typeof(uintVar   + ubyteVar) == u32);
	static is (typeof(longVar   + ubyteVar) == i64);
	static is (typeof(ulongVar  + ubyteVar) == u64);

	static is (typeof(charVar   + shortVar) == i32);
	static is (typeof(byteVar   + shortVar) == i32);
	static is (typeof(ubyteVar  + shortVar) == i32);
	static is (typeof(shortVar  + shortVar) == i32);
	static is (typeof(ushortVar + shortVar) == i32);
	static is (typeof(intVar    + shortVar) == i32);
//	static is (typeof(uintVar   + shortVar) == u32);     // Error in volt
	static is (typeof(longVar   + shortVar) == i64);
//	static is (typeof(ulongVar  + shortVar) == u64);    // Error in volt

	static is (typeof(charVar   + ushortVar) == i32);
	static is (typeof(byteVar   + ushortVar) == i32);
	static is (typeof(ubyteVar  + ushortVar) == i32);
	static is (typeof(shortVar  + ushortVar) == i32);
	static is (typeof(ushortVar + ushortVar) == i32);
	static is (typeof(intVar    + ushortVar) == i32);
	static is (typeof(uintVar   + ushortVar) == u32);
	static is (typeof(longVar   + ushortVar) == i64);
	static is (typeof(ulongVar  + ushortVar) == u64);

	static is (typeof(charVar   + intVar) == i32);
	static is (typeof(byteVar   + intVar) == i32);
	static is (typeof(ubyteVar  + intVar) == i32);
	static is (typeof(shortVar  + intVar) == i32);
	static is (typeof(ushortVar + intVar) == i32);
	static is (typeof(intVar    + intVar) == i32);
//	static is (typeof(uintVar   + intVar) == u32);     // Error in volt
	static is (typeof(longVar   + intVar) == i64);
//	static is (typeof(ulongVar  + intVar) == u64);    // Error in volt

	static is (typeof(charVar   + uintVar) == u32);
//	static is (typeof(byteVar   + uintVar) == u32);    // Error in volt
	static is (typeof(ubyteVar  + uintVar) == u32);
//	static is (typeof(shortVar  + uintVar) == u32);    // Error in volt
	static is (typeof(ushortVar + uintVar) == u32);
//	static is (typeof(intVar    + uintVar) == u32);    // Error in volt
	static is (typeof(uintVar   + uintVar) == u32);
//	static is (typeof(longVar   + uintVar) == i64);    // Error in volt
	static is (typeof(ulongVar  + uintVar) == u64);

	static is (typeof(charVar   + longVar) == i64);
	static is (typeof(byteVar   + longVar) == i64);
	static is (typeof(ubyteVar  + longVar) == i64);
	static is (typeof(shortVar  + longVar) == i64);
	static is (typeof(ushortVar + longVar) == i64);
	static is (typeof(intVar    + longVar) == i64);
//	static is (typeof(uintVar   + longVar) == i64);    // Error in volt
	static is (typeof(longVar   + longVar) == i64);
//	static is (typeof(ulongVar  + longVar) == u64);   // Error in volt

	static is (typeof(charVar   + ulongVar) == u64);
//	static is (typeof(byteVar   + ulongVar) == u64);  // Error in volt
	static is (typeof(ubyteVar  + ulongVar) == u64);
//	static is (typeof(shortVar  + ulongVar) == u64);  // Error in volt
	static is (typeof(ushortVar + ulongVar) == u64);
//	static is (typeof(intVar    + ulongVar) == u64);  // Error in volt
	static is (typeof(uintVar   + ulongVar) == u64);
//	static is (typeof(longVar   + ulongVar) == u64);  // Error in volt
	static is (typeof(ulongVar  + ulongVar) == u64);

	return 0;
}
