//T compiles:yes
//T retval:42
module test;

int main()
{
	if (byte.min != -128) {
		return 1;
	}
	if (byte.max != 127) {
		return 2;
	}
	if (ubyte.min != 0) {
		return 3;
	}
	if (ubyte.max != 255) {
		return 4;
	}
	if (short.min != -32768) {
		return 5;
	}
	if (short.max != 32767) {
		return 6;
	}
	if (ushort.min != 0) {
		return 7;
	}
	if (ushort.max != 65535) {
		return 8;
	}
	if (int.min != -2147483648L) {
		return 9;
	}
	if (int.max != 2147483647L) {
		return 10;
	}
	if (uint.min != 0) {
		return 11;
	}
	if (uint.max != 4294967295L) {
		return 12;
	}
	if (long.min != -9223372036854775808UL) {
		return 13;
	}
	if (long.max != 9223372036854775807UL) {
		return 14;
	}
	if (ulong.min != 0) {
		return 15;
	}
	if (ulong.max != 18446744073709551615UL) {
		return 16;
	}
	return 42;
}
