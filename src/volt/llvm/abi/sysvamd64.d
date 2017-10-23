/*#D*/
// Copyright © 2017, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Provides a solution for implementing structs passed by value.
 *
 * This module could be called 'dothethingthatclangdoestocfunctions.volt', but
 * that's a lot longer to type. Technically it's implementing the System V
 * AMD64 ABI.
 *
 * At any rate, here's how it breaks down.
 *
 * ## ABI Fundamentals
 *
 * There are three ways that a struct can be passed to a C function.
 *
 * - *MEMORY*: This is the regular by-value way you get if you just make the
 * parameter the parameter type. Pushed on the stack on AMD64.
 *
 * - *INTEGER*: Passed like an integer value, in pieces. These are passed
 * in six registers in the SysV AMD64 ABI:  
 * RDI, RSI, RDX, RCX, R8, and R9. In that order, but that doesn't matter
 * for our purposes. The important thing to note is that there
 * are six (6) INTEGER registers.
 *
 * - *FLOAT*: Like INTEGER, but passed in float registers.  
 * The registers that the SysV AMD64 ABI uses are:  
 * XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6, and XMM7.
 * Again, not concerned with the order, but the number.  
 * There are eight (8) FLOAT registers.
 *
 * _(Note that while AMD64 processors have other ways to pass floating
 * point values, the ABI spec either passes them in XMM* registers, or
 * as MEMORY values.)_
 *
 * ## Classification
 *
 * For primitive types, classification is fairly simple. (Note that this
 * is a gross over-simplification of the SysV ABI. We're
 * only including what Volta cares about here.)
 *
 * - Integers, (`i*`, `u*`, `*char`, `bool`) and pointers are INTEGER.
 * - Floats (`f32`, `f64`) are FLOAT.
 * - Anything else, MEMORY.
 *
 * LLVM will handle the normal parameters, hence why the above is so simplified.
 * But LLVM doesn't handle aggregate types (`struct`s and `union`s), and left
 * to its own devices, will pass them all as MEMORY, but that's not what the
 * C ABI expects.
 *
 * The alignment of an aggregate is equal to the strictest alignment (i.e. the
 * largest) of one of its constituent members.
 *
 * The classifications have priority. If one type has a classification of MEMORY
 * in a given group, then the whole group has MEMORY. If there is an INTEGER member
 * in a group of FLOATs, then that group is an INTEGER.
 *
 * If the size of the aggregate is less than or equal to a single `u64`
 * (the ABI documentation uses the term `eightbytes`, but I'll stick to Volt
 * terminology here) then that type is treated as normal parameter. If it's
 * MEMORY, then it is treated as a normal struct, but if it is a FLOAT, then
 * it's just an LLVM `float` or `double`. (Note that floating point values only
 * have two sizes as far as we're concerned, 4 and 8 bytes, and they can't
 * coexist in a group with an integer).
 * If it's an integer it's an LLVM `iN`,
 * where `N` is the largest value <= 64, rounded up to alignment boundaries.
 *
 * I'll repeat the last point, it's important. It is treated as a normal parameter.
 * Remember what I said about LLVM handling normal parameters? It applies here.
 * If registers are exhausted, they still get decomposed to the float/integer.
 * (Unless they're MEMORY, obviously)
 *
 * If the aggregate is larger than 16 bytes (two `u64`s), then the whole thing is
 * MEMORY.
 *
 * Any remaining aggregates are considered in two eight byte (`u64`) chunks.
 * *Those chunks are classified separately*. That is to say, if you have the
 * struct
 * ```volt
 * struct S {
 *     d: f64;
 *     i: i8;
 *     f: f32;
 * }
 * ```
 * Then that struct gets broken down into two eightbyte chunks for consideration:
 *     [[dddddddd]][[i    ][ffff]]
 * Remember what I said about alignment and precedence? That applies here. So
 * the first chunk is considered as a group, and is a FLOAT that fits in a `double`.
 * The second chunk is an INTEGER and a FLOAT, so it's decomposed into
 * `double, i64` when being passed into a C function. The second chunk may only be
 * 5 bytes, but due to alignment, it rounds up to 8. And as a FLOAT can't exist with
 * any other type, it becomes an INTEGER; hence, `i8`+`f32` (in this instance) == `i64`.
 *
 * If an eightbyte chunk is composed of two `f32`s, then it is vectorized to LLVM (`<2 x float>`)
 * This is considered to take up one FLOAT register.
 *
 * ## Register exhaustion
 *
 * So the above isn't too complicated, once you get down to it. Go over the functions parameters
 * left to right, if you hit an aggregate, evaluate it according to the above rules,
 * and modify the function parameters and calls accordingly.
 *
 * But it's not so simple. There are a limited number of registers for parameters to be placed into.
 * And once a multiparameter aggregate is exploded, LLVM doesn't know what type it was
 * originally and can't push it onto the stack (the same doesn't apply for aggregates
 * that become a single INTEGER/FLOAT. They contribute to exhaustion, but they're
 * always decomposed.) Registers are allocated for parameters left-to-right, and once
 * an aggregate can't be entirely allocated, it has to become MEMORY, every chunk.
 *
 * So remember, 6 integer registers, 8 float registers. For *every* parameter,
 * subtract how many registers it'll take. The last example would
 * take one integer, and one float register. If you go to allocate a register group,
 * and it is at zero registers, then the entire aggregate, every eightbyte chunk,
 * becomes MEMORY. Any integer size is considered to take a single register, so
 * if you start a function with six by-value structs with a single `u8` field,
 * any complex aggregate that would become INTEGER in one of its chunks would
 * have to be MEMORY.
 *
 * Individual float parameters are not vectorized, and are considered to take a
 * FLOAT register each. That is to say, a function starting `(float, float, float, float`
 * has 4 float registers remaining, while one that starts `({float, float}, {float, float}`
 * has 6 remaining.
 *
 * ## Argument coercion.
 *
 * ### Single argument ({u64} -> u64, {f64} -> double etc )
 *
 * This one is fairly simple.
 * Where as before, the code generated is
 *
 * ```
 * a = load TheStruct from TheStruct*
 * call func(a)
 * ```
 *
 * It becomes
 *
 * ```
 * ptr = gep TheStruct* 0 0  // TheStruct*
 * load = i64 from i64* ptr
 * ```
 *
 * Basically, `func(str)` becomes `func(*(cast(i64*)&str))`.
 *
 * ### Vectorised floats
 *
 * So if `{ f32, f32 }` is vectorized into a `<2 x float>` parameter, the
 * code for call is similar to the previous case, but slightly different.
 *
 * The original call becomes
 *
 * ```
 * ptr = bitcast TheStruct* to <2 float>*
 * a = load <2 x float> from ptr
 * func(a)
 * ```
 *
 * Which is the same concept as before, but with an explicit cast. I
 * expect this method would work for the other other types too, so
 * you might want to investigate using this path for the above case
 * too.
 *
 * ### Other decompositions
 *
 * So this is an aggregate that is bigger than 8 bytes, but less than or
 * equal to 16.
 *
 * Step one is to create an aggregate that has the two members, these
 * will be the two parameters we're decomposing down to.
 *
 * If your initial aggregate is (say) `{ u32, u32, u32, u32 }`, then create
 * an aggregate of `{ u64, u64 }`.  
 * If your initial aggregate is (say) `{ u32, u32, f32, f32 }`, then create
 * an aggregate of `{ u64, <2 x float> }`.
 *
 * Then the remainder of the method is basically a combination of the last
 * two.
 *
 * ```
 * sptr = bitcast TheStruct* to { u64, <2 x float> }*   // or w/e
 * aptr = gep sptr 0 0   // u64*
 * a = load u64* aptr  // u64
 * bptr = gep sptr 0 1   // <2 x float>*
 * b = load <2 x float>* bptr  // <2 x float>
 * func(a, b);
 * ```
 */
 module volt.llvm.abi.sysvamd64;
 
 import lib.llvm.core;
 
 import ir = volt.ir.ir;
 
 import volt.errors;
 import volt.interfaces;
 import volt.semantic.classify : calcAlignment;
 import volt.llvm.interfaces;
 import volt.llvm.type;
 import volt.llvm.abi.base;
 
 enum Classification
 {
	 Memory,
	 Integer,
	 Float,
	 CoercedStructSingle,
	 CoercedStructDouble,
 }
 
 enum AMD64_SYSV_INTEGER_REGISTERS = 6;
 enum AMD64_SYSV_FLOAT_REGISTERS   = 8;
 enum AMD64_SYSV_MAX_COERCIBLE_SZ  = 128;  // In bits.
 enum AMD64_SYSV_WORD_SZ           = 64;   // In bits.
 enum AMD64_SYSV_HALFWORD_SZ       = 32;   // In bits.
 enum NOT_FLOAT                    = -1;
 enum ONE_FLOAT                    = 1;
 enum TWO_FLOATS                   = 2;
 enum ONE_DOUBLE                   = 3;
 
 void sysvAmd64AbiCoerceParameters(State state, ir.FunctionType ft, ref LLVMTypeRef retType, ref LLVMTypeRef[] params)
 {
	 int integerRegisters = AMD64_SYSV_INTEGER_REGISTERS;
	 int floatRegisters   = AMD64_SYSV_FLOAT_REGISTERS;
 
	 LLVMTypeRef[] types;
 
	 foreach (param; params) {
		 LLVMTypeRef[] structTypes;
		 auto classification = classifyType(state, param, /*#out*/structTypes);
		 if (classification == Classification.Memory) {
			 types ~= param;
			 ft.abiData ~= cast(void*[])null;
			 continue;
		 }
		 if (classification == Classification.Integer) {
			 integerRegisters--;
			 types ~= param;
			 ft.abiData ~= cast(void*[])null;
		 } else if (classification == Classification.Float) {
			 floatRegisters--;
			 types ~= param;
			 ft.abiData ~= cast(void*[])null;
		 } else {
			 consumeRegisters(state, structTypes, /*#ref*/integerRegisters, /*#ref*/floatRegisters);
			 if (classification == Classification.CoercedStructSingle ||
				 (integerRegisters >= 0 && floatRegisters >= 0)) {
				 ft.abiModified = true;
				 types ~= structTypes;
				 ft.abiData ~= cast(void*[])structTypes;
				 if (structTypes.length == 2) {
					 /* In order to make the code that modifies the prologue and
					  * call simpler, ensure that abiData will have the effective length
					  * of the expanded call list.
					  */
					 ft.abiData ~= cast(void*[])null;
				 }
			 } else {
				 types ~= param;
				 ft.abiData ~= cast(void*[])null;
			 }
		 }
	 }
 
	 params = types;
 }
 
 void consumeRegisters(State state, LLVMTypeRef[] types, ref int integerRegisters, ref int floatRegisters)
 {
	 foreach (type; types) {
		 LLVMTypeRef[] structTypes;
		 auto classification = classifyType(state, type, /*#out*/structTypes);
		 if (classification == Classification.Memory) {
			 continue;
		 }
		 if (classification == Classification.Integer) {
			 integerRegisters--;
		 } else if (classification == Classification.Float) {
			 floatRegisters--;
		 } else {
			 consumeRegisters(state, structTypes, /*#ref*/integerRegisters, /*#ref*/floatRegisters);
		 }
	 }
 }
 
 
 Classification classifyType(State state, LLVMTypeRef type, out LLVMTypeRef[] structTypes)
 {
	 auto kind = LLVMGetTypeKind(type);
	 final switch(kind) with (LLVMTypeKind) {
	 case Void, Half, X86_FP80, FP128, PPC_FP128, Label,
		 Function, Array, Vector, Metadata, X86_MMX, Token:
		 return Classification.Memory;
	 case Float, Double:
		 return Classification.Float;
	 case Integer, Pointer:
		 return Classification.Integer;
	 case Struct:
		 return classifyStructType(state, type, /*#out*/structTypes);
	 }
 }
 
 Classification classifyStructType(State state, LLVMTypeRef type, out LLVMTypeRef[] structTypes)
 {
	 auto name = LLVMGetStructName(type);
 
	 uint elementCount = LLVMCountStructElementTypes(type);
	 auto elements = new LLVMTypeRef[](elementCount);
 
	 // The size of this struct, in bits.
	 size_t sz;
	 size_t firstWidth;
	 // The struct alignment is equal to the strictest alignment of a member.
	 size_t alignment;
	 /* If a portion is <= `0`, that 8 byte segment is not FLOAT.
	  * Otherwise, 1 == 1 float, 2 == 2 floats, 3 == 1 double.
	  */
	 int[2] floats;
	 // A pointer will take up an entire section.
	 // If a section is filled by a pointer, what type does it point to? Otherwise null.
	 LLVMTypeRef[2] pointees;
	 // Are we up to the second segment yet?
	 bool secondSegment;
 
	 // Update the above values for a member of the given size (bytes) and floatness.
	 void addSize(size_t val, Classification classification, LLVMTypeRef pointer = null)
	 {
		 bool floating = classification == Classification.Float;
		 if (!floating) {
			 floats[secondSegment] = NOT_FLOAT;
		 }
		 if (floating && floats[secondSegment] != NOT_FLOAT) {
			 assert(val == AMD64_SYSV_HALFWORD_SZ || val == AMD64_SYSV_WORD_SZ);
			 if (val == AMD64_SYSV_HALFWORD_SZ) {
				 floats[secondSegment]++;
			 } else if (val == AMD64_SYSV_WORD_SZ) {
				 if (floats[secondSegment] != 0) {
					 floats[secondSegment] = NOT_FLOAT;
				 } else {
					 floats[secondSegment] = ONE_DOUBLE;
				 }
			 }
		 }
		 if (val > alignment) {
			 alignment = val;
		 }
		 if (sz + val > AMD64_SYSV_WORD_SZ && !secondSegment) {
			 firstWidth = sz;
			 sz = AMD64_SYSV_WORD_SZ + val;
			 secondSegment = true;
			 if (!floating) {
				 floats[secondSegment] = NOT_FLOAT;
			 }
		 } else {
			 sz += val;
			 pointees[secondSegment] = pointer;  // If pointer is null, that's fine too.
			 if (sz == AMD64_SYSV_WORD_SZ) {
				 alignment = 0;  // Each eightbyte is treated separately.
				 secondSegment = true;
			 }
		 }
	 }
 
	 bool addElements(LLVMTypeRef[] theElements)
	 {
		 foreach (i, element; theElements) {
			 LLVMTypeKind ekind = LLVMGetTypeKind(element);
			 final switch(ekind) with (LLVMTypeKind) {
			 case Void, Half, X86_FP80, FP128, PPC_FP128, Label,
				 Function, Vector, Metadata, X86_MMX, Token:
				 return false;
			 case Array:
				 auto len = LLVMGetArrayLength(element);
				 auto base = LLVMGetElementType(element);
				 auto types = new LLVMTypeRef[](len);
				 foreach (ref type; types) {
					 type = base;
				 }
				 if (!addElements(types)) {
					 return false;
				 }
				 break;
			 case Float:
				 addSize(AMD64_SYSV_HALFWORD_SZ, Classification.Float);
				 break;
			 case Double:
				 addSize(AMD64_SYSV_WORD_SZ, Classification.Float);
				 break;
			 case Integer:
				 auto width = LLVMGetIntTypeWidth(element);
				 addSize(width, Classification.Integer);
				 break;
			 case Pointer:
				 addSize(AMD64_SYSV_WORD_SZ, Classification.Integer, LLVMGetElementType(element));
				 break;
			 case Struct:
				 LLVMTypeRef[] types;
				 classifyStructType(state, element, /*#out*/types);
				 if (types.length == 0) {
					 return false;
				 } else {
					 addElements(types);
				 }
				 break;
			 }
		 }
		 return true;
	 }
 
	 LLVMGetStructElementTypes(type, elements.ptr);
	 if (!addElements(elements)) {
		 return Classification.Memory;
	 }
 
	 if (alignment != 0) {
		 sz = calcAlignment(alignment, sz);
	 }
 
	 if (sz > AMD64_SYSV_MAX_COERCIBLE_SZ) {
		 return Classification.Memory;
	 }
 
	 LLVMTypeRef[] getSegmentType(size_t segment)
	 {
		 switch (floats[segment]) {
		 case ONE_FLOAT:
			 return [LLVMFloatTypeInContext(state.context)];
		 case TWO_FLOATS:
			 auto t = LLVMFloatTypeInContext(state.context);
			 return [LLVMVectorType(t, 2)];
		 case ONE_DOUBLE:
			 return [LLVMDoubleTypeInContext(state.context)];
		 default:
			 if (pointees[segment] !is null) {
				 return [LLVMPointerType(pointees[segment], 0)];
			 }
			 size_t segmentSize;
			 if (segment == 0) {
				 if (sz >= AMD64_SYSV_WORD_SZ) {
					 segmentSize = AMD64_SYSV_WORD_SZ;
				 } else {
					 segmentSize = sz;
				 }
			 } else {
				 segmentSize = sz - AMD64_SYSV_WORD_SZ;
			 }
			 return [LLVMIntTypeInContext(state.context, cast(uint)segmentSize)];
		 }
	 }
 
	 if (sz <= AMD64_SYSV_WORD_SZ) {
		 structTypes = getSegmentType(0);
		 return Classification.CoercedStructSingle;
	 }
 
	 structTypes = getSegmentType(0) ~ getSegmentType(1);
 
	 return Classification.CoercedStructDouble;
 }
 
 void sysvAmd64AbiCoerceArguments(State state, ir.CallableType ct, ref LLVMValueRef[] args)
 {
	 for (size_t i = 0; i < args.length; ++i) {
		 // We need a pointer. If it is a value, alloca and store.
		 if (ct.abiData[i].length != 0 &&
			 LLVMGetTypeKind(LLVMTypeOf(args[i])) != LLVMTypeKind.Pointer) {
			 auto _alloca = state.buildAlloca(LLVMTypeOf(args[i]), "");
			 LLVMBuildStore(state.builder, args[i], _alloca);
			 args[i] = _alloca;
		 }
		 if (ct.abiData[i].length == 1) {
			 auto lt = cast(LLVMTypeRef[])ct.abiData[i];
			 auto bc = LLVMBuildBitCast(state.builder, args[i],
				 LLVMPointerType(lt[0], 0), "");
			 args[i] = LLVMBuildLoad(state.builder, bc, "");
		 } else if (ct.abiData[i].length == 2) {
			 auto vkind = LLVMGetValueKind(args[i]);
			 auto lts = cast(LLVMTypeRef[])ct.abiData[i];
			 auto _struct = LLVMStructTypeInContext(state.context, lts.ptr, cast(uint)lts.length, false);
			 auto bc = LLVMBuildBitCast(state.builder, args[i], LLVMPointerType(_struct, 0), "");
			 auto agep = buildGep(state, bc, 0, 0);
			 args[i] = LLVMBuildLoad(state.builder, agep, "");
 
			 auto bgep = buildGep(state, bc, 0, 1);
			 auto load = LLVMBuildLoad(state.builder, bgep, "");
			 args = args[0 .. i] ~ [args[i], load] ~ args[i+1 .. $];
			 i++;
		 }
	 }
 }
 
CoercedStatus sysvAmd64AbiCoercePrologueParameter(State state, LLVMValueRef llvmFunc, ir.Function func, ir.CallableType ct,
	 LLVMValueRef val, size_t index, ref size_t offset)
 {
	 if (ct.abiData[index+offset].length != 1 && ct.abiData[index+offset].length != 2) {
		 return NotCoerced;
	 }
	 auto p = func.params[index];
	 auto lts = cast(LLVMTypeRef[])ct.abiData[index+offset];
	 auto type = state.fromIr(p.type);
	 auto a = state.getVariableValue(p, /*#out*/type);
	 if (ct.abiData[index+offset].length == 1) {
		 auto bc = LLVMBuildBitCast(state.builder, a, LLVMPointerType(lts[0], 0), "");
		 LLVMBuildStore(state.builder, val, bc);
	 } else if (ct.abiData[index+offset].length == 2) {
		 auto _struct = LLVMStructTypeInContext(state.context, lts.ptr, cast(uint)lts.length, false);
		 auto bc = LLVMBuildBitCast(state.builder, a, LLVMPointerType(_struct, 0), "");
		 auto agep = buildGep(state, bc, 0, 0);
		 LLVMBuildStore(state.builder, val, agep);
		 offset++;
		 auto v2 = LLVMGetParam(llvmFunc, cast(uint)(index + offset));
		 auto bgep = buildGep(state, bc, 0, 1);
		 LLVMBuildStore(state.builder, v2, bgep);
	 } else {
		 panicAssert(ct, false);
	 }
	 return Coerced;
 }
 