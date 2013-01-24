//T compiles:no
module test_017;

int main()
{
  char c;
  scope int* p;
  p = &c;
  return 3;
}
