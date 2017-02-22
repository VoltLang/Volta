module a36;

private global integer: i32;

private global pPointer: i32*;

alias pointer = pPointer;

global this()
{
	integer = 4;
	pPointer = &integer;
}
