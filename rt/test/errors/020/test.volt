//T macro:expect-failure
//T check:use 'is' for
module test;

fn main() i32
{
    ptr: void*;
    b := ptr == null;
    return 0;
}
