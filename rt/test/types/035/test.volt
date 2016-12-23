//T compiles:yes
//T retval:42
module test;


int main()
{
	// (m)utable (c)onst (P)ointer (I)int (B)ool
	const(const(int)*) cPcI;
	const(int)* mPcI;
	int* mPmI;
	bool mB;


	static is (typeof(mB ? *mPmI : *mPmI) == int);
	static is (typeof(mB ? *mPmI : *mPcI) == int);
	static is (typeof(mB ? *mPmI : *cPcI) == int);

	static is (typeof(mB ? *mPcI : *mPmI) == int);
	static is (typeof(mB ? *mPcI : *mPcI) == int);
	static is (typeof(mB ? *mPcI : *cPcI) == int);

	static is (typeof(mB ? *cPcI : *mPmI) == int);
	static is (typeof(mB ? *cPcI : *mPcI) == int);
	static is (typeof(mB ? *cPcI : *cPcI) == int);

/*
	static is (typeof(mB ? mPmI : mPmI) == int*);
	static is (typeof(mB ? mPmI : mPcI) == const(int)*);
	static is (typeof(mB ? mPmI : cPcI) == const(int)*);

	static is (typeof(mB ? mPcI : mPmI) == const(int)*);
	static is (typeof(mB ? mPcI : mPcI) == const(int)*);
	static is (typeof(mB ? mPcI : cPcI) == const(int)*);

	static is (typeof(mB ? cPcI : mPmI) == const(int)*);
	static is (typeof(mB ? cPcI : mPcI) == const(int)*);
	static is (typeof(mB ? cPcI : cPcI) == const(int)*);
*/

	return 42;
}
