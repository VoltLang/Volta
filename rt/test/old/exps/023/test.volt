//T compiles:yes
//T retval:16
// Unary not.
module test;

int main()
{
	if (~0x0 != -1) {
		return 0;
	}
	if (~0x1 != -2) {
		return 1;
	}
	if (~0x2 != -3) {
		return 2;
	}
	if (~0x3 != -4) {
		return 3;
	}
	if (~0x4 != -5) {
		return 4;
	}
	if (~0x5 != -6) {
		return 5;
	}
	if (~0x6 != -7) {
		return 6;
	}
	if (~0x7 != -8) {
		return 7;
	}
	if (~0x8 != -9) {
		return 8;
	}
	if (~0x9 != -10) {
		return 9;
	}
	if (~0xA != -11) {
		return 10;
	}
	if (~0xB != -12) {
		return 11;
	}
	if (~0xC != -13) {
		return 12;
	}
	if (~0xD != -14) {
		return 13;
	}
	if (~0xE != -15) {
		return 14;
	}
	if (~0xF != -16) {
		return 15;
	}
	return 16;
}
