//T compiles:no
module test;

int div(int numerator, int denominator)
{
	return numerator / denominator;
}

int main()
{
	return div(denominator:2, foo:4);
}
