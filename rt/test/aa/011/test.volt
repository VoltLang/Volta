// Reset AAs.
module test;

import core.exception : Throwable;

int main()
{
	aa := [3:42];
	aa = [];
	try {
		return aa[3];
	} catch (Throwable) {
		return 0;
	}
	return 1;
}
