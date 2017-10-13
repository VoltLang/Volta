// struct return sanity test

#include <stdint.h>

typedef struct
{
	int32_t x;
} S;

S getTwelve()
{
	S s;
	s.x = 12;
	return s;
}

