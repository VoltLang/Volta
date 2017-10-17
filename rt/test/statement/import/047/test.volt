//T macro:importfail
//T check:multiple imports contain
module test;

import watt = [m1, m2];

fn main() i32
{
    return watt.exportedVar;
}
