//T default:no
//T macro:import
module test;

import m4 : exportedVar;


int main()
{
	return exportedVar - 42;
}
