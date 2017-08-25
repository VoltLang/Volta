//T macro:import
module test;

import bug_031_m1;
import bug_031_m2;


int main()
{
	return func() - 42;
}
