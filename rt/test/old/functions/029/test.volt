//T compiles:yes
//T retval:3
module test;

fn three(out a : i32)
{
	a = 3;
}

fn callfptr(fp : fn!Volt(out i32), out i : i32)
{
	fp(out i);
}

fn main() i32
{
	a : (fn!Volt(out i32))[] = new (fn!Volt(out i32))[](1);
	a[0] = three;
	i32 i;
	callfptr(a[0], out i);
	return i;
}
