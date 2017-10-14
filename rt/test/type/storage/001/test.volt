//T macro:expect-failure
module test;

fn main() i32
{
    i: i32 = 12;
    ip: immutable(i32)* = &i;
    i = 6;
    return *ip - 6;
}
