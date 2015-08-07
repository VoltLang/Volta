module watt.text.diff;

import watt.io.std;
import watt.text.string;

/**
 * Print the difference between two strings, line-by-line, to stdout.
 */
void diff(const(char)[] a, const(char)[] b)
{
	size_t[] c;
	size_t w;
	auto A = " " ~ split(a, '\n');
	auto B = " " ~ split(b, '\n');
	lcs(A, B, c, w);
	printDiff(c, w, A, B, A.length-1, B.length-1);
}

private void printDiff(size_t[] c, size_t w,
                       const(char)[][] a, const(char)[][] b, size_t i, size_t j)
{
	if (i > 0 && j > 0 && a[i] == b[j]) {
		printDiff(c, w, a, b, i-1, j-1);
		writefln("%s", a[i]);
	} else if (j > 0 && (i == 0 || c[i*w+(j-1)] >= c[(i-1)*w+j])) {
		printDiff(c, w, a, b, i, j-1);
		writefln("+%s", b[j]);
	} else if (i > 0 && (j == 0 || c[i*w+(j-1)] < c[(i-1)*w+j])) {
		printDiff(c, w, a, b, i-1, j);
		writefln("-%s", a[i]);
	}
}

/**
 * Generate a longest common substring (LCS) matrix.
 * c contains the values, w contains the width of the matrix.
 */
private void lcs(const(char)[][] a, const(char)[][] b,
                 out size_t[] c, out size_t w)
{
	w = b.length;
	c = new size_t[](a.length * b.length);
	for (size_t i = 1; i < a.length; ++i) {
		for (size_t j = 1; j < b.length; ++j) {
			if (a[i] == b[j]) {
				c[i*w+j] = c[(i-1)*w+(j-1)]+1;
			} else {
				auto l = c[i*w+(j-1)];
				auto r = c[(i-1)*w+j];
				c[i*w+j] = l > r ? l : r;
			}
		}
	}
}

