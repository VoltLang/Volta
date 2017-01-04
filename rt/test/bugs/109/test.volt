module test;


struct Block {
	// This field is needed even tho we don't use it.
	// Must be block array or pointer, int doesn't not help.
	blocks: Block*;
}

fn parseBlocks()
{
	elm: Block;
	arr: Block[];
	arr ~= elm; // This is needed.
}

// If we remove the int num arg it passes.
// If we remove the const it passes.
fn writeMarkdownEscaped(ref block: const Block, num: i32)
{
}

fn writeMarkdownEscaped(ln: i32, num: i32)
{
	foo: i32; // Must be a extra arg here.
	writeMarkdownEscaped(foo, num);
}

fn main() i32
{
	return 0;
}
