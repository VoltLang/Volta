//T macro:importfail
//T check:may only be used in bind imports
module test;

import [m1, m14];

fn main() i32
{
    return uniqueVar - 2;
}
