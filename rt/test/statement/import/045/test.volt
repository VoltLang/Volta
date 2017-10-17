//T macro:import
module test;

import watt = [m1, m13];

fn main() i32
{
    return watt.exportedVar - (watt.retval + 1);
}
