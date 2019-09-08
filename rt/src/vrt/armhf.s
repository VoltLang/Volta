# Copyright 2019, Collabora, Ltd.
# SPDX-License-Identifier: BSL-1.0
#
	.arch armv7-a
	.text
	.fpu	vfpv3-d16

#
# fn vrt_eh_personality_v0(...)
#
# This function is needed to work around the compiler getting confused
# about the prototype of vrt_eh_personality_v0, and acient fixed LLD bug.
#
	.p2align 2
	.global	vrt_eh_personality_v0
	.type	vrt_eh_personality_v0, %function
	.code	32
vrt_eh_personality_v0:
	.fnstart
	b vrt_eh_personality_v0_real
.Lfunc_end0:
	.size	vrt_eh_personality_v0, .Lfunc_end0-vrt_eh_personality_v0
	.fnend


#
# fn __vrt_push_registers(cb: dg())
#
# Pushes all useful registers to the stack and calls the given delegate.
#
	.p2align 2
	.globl	__vrt_push_registers
	.type	__vrt_push_registers, %function
	.code	32
__vrt_push_registers:
	.fnstart
	.save	{r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, lr}
	push	{r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, lr}
	.setfp	r11, sp, #40
	add	r11, sp, #40
	blx	r1
	sub	sp, r11, #40
	pop	{r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, pc}
.Lfunc_end1:
	.size	__vrt_push_registers, .Lfunc_end1-__vrt_push_registers
	.fnend
