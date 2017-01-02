module test;


fn main() i32
{
	x: i32;
	s: string = "雨aだ";
	foreach (i, c: dchar; s) {
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
	foreach_reverse (i, c: dchar; s) {
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
	return x - 6;
}

