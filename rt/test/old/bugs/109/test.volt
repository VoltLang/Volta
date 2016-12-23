//T compiles:yes
//T retval:7
module test;


struct Block {
	// This field is needed even tho we don't use it.
	// Must be block array or pointer, int doesn't not help.
	Block* blocks;
}

void parseBlocks()
{
	Block elm;
	Block[] arr;
	arr ~= elm; // This is needed.
}

// If we remove the int num arg it passes.
// If we remove the const it passes.
void writeMarkdownEscaped(ref const Block block, int num)
{
}

void writeMarkdownEscaped(int ln, int num)
{
	int foo; // Must be a extra arg here.
	writeMarkdownEscaped(foo, num);
}

int main()
{
	return 7;
}
