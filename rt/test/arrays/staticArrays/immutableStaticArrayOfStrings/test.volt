module main;


global tagNames: immutable(char)[][20] = [
	"END",
	"CMDLINE",
	"BOOT_LOADER_NAME",
	"MODULE",
	"BASIC_MEMINFO",
	"BOOTDEV",
	"MMAP",
	"VBE",
	"FRAMEBUFFER",
	"ELF_SECTIONS",
	"APM",
	"EFI32",
	"EFI64",
	"SMBIOS",
	"ACPI_OLD",
	"ACPI_NEW",
	"NETWORK",
	"EFI_MMAP",
	"EFI_BS",
	"UNKOWN",
];

fn main() i32
{
	tagNames = ["hi"];
	return 0;
}
