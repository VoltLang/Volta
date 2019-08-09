	.arch armv8-a
	.text

	.align	2
	.p2align 3,,7
	.global	vrt_eh_personality_v0
	.type	vrt_eh_personality_v0, %function
vrt_eh_personality_v0:
	B vrt_eh_personality_v0_real
.Lfunc_end0:
	.size	vrt_eh_personality_v0, .Lfunc_end0-vrt_eh_personality_v0

	.align	2
	.p2align 3,,7
	.global	__vrt_push_registers
	.type	__vrt_push_registers, %function
__vrt_push_registers:
	BR x1
.Lfunc_end1:
	.size	__vrt_push_registers, .Lfunc_end1-__vrt_push_registers
