//T macro:import
module test;

import watt = [m1, m2];

fn main() i32
{
    return 0;  // Error should occur on lookup.
}
