//T macro:expect-failure
//T check:cannot cast a delegate to a pointer
module test;

alias TheDelegate = dg(i32) i32;

fn rundg(ptr: void*, argument: i32) i32 {
	dlgt := cast(TheDelegate)ptr;
	return dlgt(argument);
}

fn compactdg(dlgt: TheDelegate) void* {
	return cast(void*)dlgt;
}

fn main(args: string[]) i32 {
	int multiplier;
	fn ourDelegate(value: i32) i32 {
		return value * multiplier;
	}
	ptr := compactdg(ourDelegate);
	multiplier = 2;
	return rundg(ptr, 11) - 22;
}
