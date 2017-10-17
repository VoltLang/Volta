//T macro:import
module test;

import watt = [m1, m14];

fn main() i32
{
    return watt.uniqueVar - 2;  // Error should be on failed lookup, not mere presence of collisions.
}
