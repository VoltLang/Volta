// Tests mutable indirection detection.
module test;


fn a() i32
{
	tinfo := typeid(i32);
	if (tinfo.mutableIndirection) {
		return 2;
	} else {
		return 4;
	}
}

fn b() i32
{
	tinfo := typeid(i32*);
	if (tinfo.mutableIndirection) {
		return 6;
	} else {
		return 8;
	}
}

struct StructA
{
	a: i32;
	b: i32;
}

struct StructB
{
	a: i32;
	b: i32*;
}

fn c() i32
{
	tinfo := typeid(StructA);
	if (tinfo.mutableIndirection) {
		return 10;
	} else {
		return 12;
	}
}

fn d() i32
{
	tinfo := typeid(StructB);
	if (tinfo.mutableIndirection) {
		return 14;
	} else {
		return 16;
	}
}

fn main() i32
{
	return a() + b() + c() + d() - 36;
}
