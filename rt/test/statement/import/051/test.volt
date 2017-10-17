//T macro:importfail
//T check:can't find module 'm34349'
module test;

import watt = [m1, m34349];

fn main() i32
{
    return 0;
}
