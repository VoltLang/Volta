module vrt.vacuum.clazz;

import core.typeinfo : TypeInfo, ClassInfo, Type;


extern(C) void* vrt_handle_cast(void* obj, TypeInfo tinfo)
{
	if (obj is null)
		return null;

	auto list = **cast(ClassInfo[]**)obj;
	for (size_t i = 0u; i < list.length; i++) {
		if (list[i] is tinfo) {
			return obj;
		}
		if (tinfo.type == Type.Interface) {
			auto cinfo = list[i];
			foreach (iface; cinfo.interfaces) {
				if (iface.info is tinfo) {
					ubyte* ptr = cast(ubyte*)obj;
					return cast(void*)(ptr + iface.offset);
				}
			}
		}
	}
	return null;
}
