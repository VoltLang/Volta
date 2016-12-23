//T compiles:yes
//T retval:38
module test;

int[50] ichi()
{
	int[50] x;
	x[4] = 35;
	return x;
}

int[] ni()
{
	auto x = new int[](50);
	x[4] = 3;
	return x;
}

int main() {
	auto hitotu = ichi();
	auto futatu = ni();
	return hitotu[4] + futatu[4];
}

