//T compiles:yes
//T retval:6
module test;


fn main() int
{
	int x;
	string s = "雨aだ";
	foreach (i, dchar c; s) {
		if (i == 0 && c != '雨') {
			return 0;
		} else if (i == 0) {
			x++;
		}
		if (i == 3 && c != 'a') {
			return 1;
		} else if (i == 3) {
			x++;
		}
		if (i == 4 && c != 'だ') {
			return 2;
		} else if (i == 4) {
			x++;
		}
	}
	foreach_reverse (i, dchar c; s) {
		if (i == 0 && c != '雨') {
			return 0;
		} else if (i == 0) {
			x++;
		}
		if (i == 3 && c != 'a') {
			return 1;
		} else if (i == 3) {
			x++;
		}
		if (i == 4 && c != 'だ') {
			return 2;
		} else if (i == 4) {
			x++;
		}
	}
	return x;
}

