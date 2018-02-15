module vls.util.simpleCache;

import ir = volta.ir;

struct SimpleCache!(K, V)
{
public:
	fn hasResult(path: K) bool
	{
		ptr := path in mCache;
		return ptr !is null;
	}

	fn getResult(path: K) V
	{
		ptr := path in mCache;
		assert(ptr !is null);
		return *ptr;
	}

	fn setResult(path: K, mod: V)
	{
		mCache[path] = mod;
	}

private:
	mCache: V[K];
}

struct SimpleImportCache = mixin SimpleCache!(string, ir.Module);
