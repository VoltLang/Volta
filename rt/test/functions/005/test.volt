//T compiles:yes
//T retval:6
module test;

int div(int numerator, int denominator)
{
	return numerator / denominator;
}

int main()
{
	return div(denominator:2, numerator:4) * div(numerator:3, denominator:1);
}