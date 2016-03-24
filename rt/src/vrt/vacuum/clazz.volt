module vrt.vacuum.clazz;


extern(C) void* vrt_handle_cast(void* obj, object.TypeInfo tinfo)
{
	if (obj is null)
		return null;

	auto list = **cast(object.ClassInfo[]**)obj;
	for (size_t i = 0u; i < list.length; i++) {
		if (list[i] is tinfo) {
			return obj;
		}
		if (tinfo.type == object.TYPE_INTERFACE) {
			auto cinfo = list[i];
			foreach (iface; cinfo.interfaces) {
				if (iface.mangledName == tinfo.mangledName) {
					ubyte* ptr = cast(ubyte*)obj;
					return cast(void*)(ptr + iface.offset);
				}
			}
		}
	}
	return null;
}
