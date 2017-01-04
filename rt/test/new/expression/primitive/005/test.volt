module test;

fn main() i32
{
	if (i8.min != -128) {
		return 1;
	}
	if (i8.max != 127) {
		return 2;
	}
	if (u8.min != 0) {
		return 3;
	}
	if (u8.max != 255) {
		return 4;
	}
	if (i16.min != -32768) {
		return 5;
	}
	if (i16.max != 32767) {
		return 6;
	}
	if (u16.min != 0) {
		return 7;
	}
	if (u16.max != 65535) {
		return 8;
	}
	if (i32.min != -2147483648L) {
		return 9;
	}
	if (i32.max != 2147483647L) {
		return 10;
	}
	if (u32.min != 0) {
		return 11;
	}
	if (u32.max != 4294967295L) {
		return 12;
	}
	if (i64.min != -9223372036854775808UL) {
		return 13;
	}
	if (i64.max != 9223372036854775807UL) {
		return 14;
	}
	if (u64.min != 0) {
		return 15;
	}
	if (u64.max != 18446744073709551615UL) {
		return 16;
	}
	return 0;
}
