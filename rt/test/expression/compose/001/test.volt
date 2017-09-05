/*! 
 * A composable string proposal that doubles
 * as a test case.
 */
module test;

fn main() i32
{
	str := "${3 - 2} + ${-1+2} = ${1*2}";
	assert(str == "1 + 1 = 2");
	a := "hello world";
	assert(a == "hello world");
	b := new "hello ${a} world";
	assert(b == "hello hello world world");
	c := new "hello ${b} world";
	assert(c == "hello hello hello world world world");
	d := "$ {1+1}";
	assert(d == "$ {1+1}");
	e := "\${1}";
	assert(e == `${1}`);
	test2();
	test3();
	return 0;
}

enum FRUIT = "banana";
enum SENT  = "Time flies like a ${FRUIT}.";

enum EnumName
{
	MemberZero,
	MemberOne,
}

fn test2()
{
	assert(SENT == "Time flies like a banana.");

	a := EnumName.MemberZero;
	b := new "A=${a}";
	assert(b == "A=MemberZero");
	c := new "B=${cast(EnumName)1}";
	assert(c == "B=MemberOne");

	assert("${1" == `${1`);
}

struct Point2D
{
	x: i32;
	y: i32;

	fn thisFunctionDoesNothing()
	{
	}
}

struct Point2D2
{
	x: i32;
	y: i32;

	fn toString() string
	{
		return new "(${x}, ${y})";
	}
}


class TestObject
{
	override fn toString() string
	{
		return "${12*2}";
	}
}

fn test3()
{
	a := "${0xFF}";
	assert(a == "255");

	b := "${3.1415926538}";
	assert(b[0 .. 4] == "3.14");

	ptr: void* = cast(void*)0x0F;
	c := new "${ptr}";
	assert(c[0] == '0' && c[$-1] == 'F');

	arr := [1, 2, 3];
	assert(new "${arr}" == "[1, 2, 3]");

	aa: string[string];
	aa["hello"] = "world";
	aa["apple"] = "banana";
	assert(new "${aa}" == "[\"hello\":\"world\", \"apple\":\"banana\"]" ||
		   new "${aa}" == "[\"apple\":\"banana\", \"hello\":\"world\"]");

	playerLocation: Point2D;
	playerLocation.x = 12;
	assert(new "${playerLocation}" == "Point2D");
	pl: Point2D2;
	pl.x = 3;
	pl.y = 4;
	assert(new "${pl}" == "(3, 4)");

	to := new TestObject();
	assert(new "${to}" == "24");

	assert("${true}" == "true" && "${!true}" == "false");
	assert(new "${true}" == "true" && new "${!true}" == "false");
	
	val: u64 = 32;
	assert(new "${val}" == "32");
	flyingPie := 3.1415926538f;
	extraPie := 3.1415926538;
//	assert(new "${flyingPie}" == "${3.1415926538f}");
//	assert(new "${extraPie}" == "${3.1415926538}");
	
	assert("'${'a'}'" == "'a'");
	assert("'${'火'}'" == "'火'");
	_char := 'a';
	_bchar := '水';
	assert(new "'${_char}'" == "'a'");
	assert(new "'${_bchar}'" == "'水'");
}
