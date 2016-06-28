//T compiles:yes
//T has-passed:yes
module doblock;


void main()
{
	auto i = 0;
	do
	{
		i++;
		if (i == 1)
			continue;
		break; // FIXME: should be implicit
	};
	do
	{
		break;
		continue;
	};
	assert(i == 2);
}
