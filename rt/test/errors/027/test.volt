//T macro:expect-failure
//T check:differs from overloaded function
module test;

private fn func(i32) i32
{
    return 1;
}

public fn func() i32
{
    return 0;
}

fn main() i32
{
    return func();
}
