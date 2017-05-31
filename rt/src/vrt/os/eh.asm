
%ifidn __OUTPUT_FORMAT__, macho64
%define PERS      _vrt_eh_personality_v0
%define PERS_REAL _vrt_eh_personality_v0_real
%else
%define PERS      vrt_eh_personality_v0
%define PERS_REAL vrt_eh_personality_v0_real
%endif

global PERS
extern PERS_REAL

section .text
PERS:
	jmp PERS_REAL
