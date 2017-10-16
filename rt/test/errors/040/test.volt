//T macro:expect-failure
//T check:specified multiple times
module test;

fn foo(x: u32, y: u32) {}

fn main() i32
{
    // Notice two x.
    foo(x: 1, x: 2);
    return 0;
}
