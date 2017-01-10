module a;

private global variable: i32 = 2;

private fn func() i32
{
	return 2;
}

private alias _alias = i32;

private enum
{
	ENUM
}

private enum NAMED
{
	ENUM
}

private interface _interface
{
	fn foo() i32;
}

private struct _struct
{
	x: i32;
}

public struct _struct2
{
	private x: i32;
}

private class _class
{
	x: i32;
}

class _class2
{
protected:
	x: i32;

private:
	z: i32;
}

private global p: void*;
alias palias = p;

