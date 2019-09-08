# Copyright 2019, Collabora, Ltd.
# SPDX-License-Identifier: BSL-1.0
#
	.arch armv8-a
	.text

#
# fn vrt_eh_personality_v0(...)
#
# This function is needed to work around the compiler getting confused
# about the prototype of vrt_eh_personality_v0, and acient fixed LLD bug.
#
	.align	2
	.p2align 3,,7
	.global	vrt_eh_personality_v0
	.type	vrt_eh_personality_v0, %function
vrt_eh_personality_v0:
	B vrt_eh_personality_v0_real
.Lfunc_end0:
	.size	vrt_eh_personality_v0, .Lfunc_end0-vrt_eh_personality_v0

#
# fn __vrt_push_registers(cb: dg())
#
# Pushes all useful registers to the stack and calls the given delegate.
#
	.align	2
	.p2align 3,,7
	.global	__vrt_push_registers
	.type	__vrt_push_registers, %function
__vrt_push_registers:
	stp	x3,	x4,	[sp, #-256]!
	stp	x5,	x6,	[sp, #16]
	stp	x7,	x8,	[sp, #32]
	stp	x9,	x10,	[sp, #48]
	stp	x11,	x12,	[sp, #64]
	stp	x13,	x14,	[sp, #80]
	stp	x15,	x16,	[sp, #96]
	stp	x17,	x18,	[sp, #112]
	stp	x19,	x20,	[sp, #128]
	stp	x21,	x22,	[sp, #144]
	stp	x23,	x24,	[sp, #160]
	stp	x25,	x26,	[sp, #176]
	stp	x23,	x24,	[sp, #192]
	stp	x25,	x26,	[sp, #208]
	stp	x27,	x28,	[sp, #224]
	stp	x29,	x30,	[sp, #240]
	add	x29,	sp,	#240
	blr	x1
	ldp	x29,	x30,	[sp, #240]
	add	sp,	sp,	#256
	ret
.Lfunc_end1:
	.size	__vrt_push_registers, .Lfunc_end1-__vrt_push_registers
