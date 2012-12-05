module test1;

void main()
{
    int[] a;
    a.length = cast(uint) 10;
    short s;
    a[0] = s;
    a[$-1] = 1;
}