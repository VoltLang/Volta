module test;


fn main() i32
{
	// (m)utable (c)onst (P)ointer (I)i32 (B)ool
	cPcI: const(const(i32)*);
	mPcI: const(i32)*;
	mPmI: i32*;
	mB: bool;


	static is (typeof(mB ? *mPmI : *mPmI) == i32);
	static is (typeof(mB ? *mPmI : *mPcI) == i32);
	static is (typeof(mB ? *mPmI : *cPcI) == i32);

	static is (typeof(mB ? *mPcI : *mPmI) == i32);
	static is (typeof(mB ? *mPcI : *mPcI) == i32);
	static is (typeof(mB ? *mPcI : *cPcI) == i32);

	static is (typeof(mB ? *cPcI : *mPmI) == i32);
	static is (typeof(mB ? *cPcI : *mPcI) == i32);
	static is (typeof(mB ? *cPcI : *cPcI) == i32);

/*
	static is (typeof(mB ? mPmI : mPmI) == i32*);
	static is (typeof(mB ? mPmI : mPcI) == const(i32)*);
	static is (typeof(mB ? mPmI : cPcI) == const(i32)*);

	static is (typeof(mB ? mPcI : mPmI) == const(i32)*);
	static is (typeof(mB ? mPcI : mPcI) == const(i32)*);
	static is (typeof(mB ? mPcI : cPcI) == const(i32)*);

	static is (typeof(mB ? cPcI : mPmI) == const(i32)*);
	static is (typeof(mB ? cPcI : mPcI) == const(i32)*);
	static is (typeof(mB ? cPcI : cPcI) == const(i32)*);
*/

	return 0;
}
