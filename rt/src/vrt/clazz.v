module vrt.clazz;


extern(C) void* vrt_handle_cast(void* obj, object.TypeInfo tinfo)
{
	if (obj is null)
		return null;

	auto list = **cast(object.TypeInfo[]**)obj;
	for (size_t i = 0u; i < list.length; i++) {
		if (list[i] is tinfo) {
			return obj;
		}
	}
	return null;
}
