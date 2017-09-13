//T macro:expect-failure
module test;

fn main() i32
{
    for (i: size_t 0; i < 10; ++i) {
    }
    return 0;
}