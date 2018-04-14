; Copyright 2016-2017, Bernard Helyer
; Copyright 2016-2017, Jakob Bornecrantz.
; SPDX-License-Identifier: BSL-1.0

global __vrt_push_registers

section .text
%ifidn __BITS__, 32
__vrt_push_registers:
	sub esp, 28
	mov eax, [esp + 32]
	mov ecx, [esp + 36]

	; Make sure all the callee saved registers that may have a pointer are saved.
	; ESP and EBP are probably not needed here, but debugging this stuff is hard,
	; so best to err on the side of safety rather than speed.
	mov [esp + 24], esp
	mov [esp + 20], ebp
	mov [esp + 16], edi
	mov [esp + 12], esi
	mov [esp + 8], ebx

	mov [esp + 4], ecx
	mov [esp], eax
	push dword [esp]
	call [esp + 8]
	add esp, 32  ; Our stackframe + the argument to the delegate.
	ret
%else
__vrt_push_registers:
; We could actually make things faster by not pushing the base and stack pointers
; but this is not performance critical and need to be rock solid.
; For some reason, clang seems to use rbp, but gcc rbx (?) so we will do it
; the clang way and push rbx to the stack as a parameter.
	push	rbp
	mov	rbp, rsp
; Not using push to make sure I not messup with stack alignement.
; Also sub + mov is usually faster than push (not that it matters much here).
%ifidn __OUTPUT_FORMAT__, win64
	sub	rsp, 72
%else
	sub	rsp, 48
%endif
; Register r12 to r15 are callee saved so can have live values.
; Other registers are trash or already saved on the stack.
	mov	[rbp -  8], rbx
	mov	[rbp - 16], r12
	mov	[rbp - 24], r13
	mov	[rbp - 32], r14
	mov	[rbp - 40], r15
%ifidn __OUTPUT_FORMAT__, win64
	mov	[rbp - 48], rsp
	mov	[rbp - 56], rdi
	mov	[rbp - 64], rsi
%endif
%ifidn __OUTPUT_FORMAT__, win64
	; On windows, the delegate struct becomes a pointer.
	; The second member is the function, so load that into RAX,
	; Then load the first member into RCX (the integer parameter).
	; Both RAX and RCX are volatile, so no need to save.
	lea rax, [rcx+8]
	mov rcx, [rcx]
	call [rax]
%else
	; This method is passed a delegate. rdi contains the context as a first argument
	; and rsi, the second argument is the function pointer. rdi do not need any special
	; threatement as it is also the first argument when calling the delegate.
	call rsi
%endif
; rsp and rbp are the only callee saved register we modified, no need to restore others.
	mov rsp, rbp
	pop rbp
	ret
%endif
