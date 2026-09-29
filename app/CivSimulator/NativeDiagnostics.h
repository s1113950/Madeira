// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#define IOS_RPM_GUARD() ((void)0) // Native build uses libc malloc, not rpmalloc.
// The pinned FEX fork's Core.cpp logs these PE-module counters even in its
// native Mach-O build, but only declares them for FEX_IOS_HOST. That switch
// also enables Windows-only VirtualQuery code. The Simulator ELF probe has
// neither ARM64EC callbacks nor FFS bypasses, so these diagnostic counters
// remain zero. No instruction, memory, syscall or test-result path is stubbed.
// Keep this build adapter outside FEX; do not submit AI changes upstream.
#ifdef __cplusplus
#include <cstdint>
#include <cstddef>
#include <mach/mach.h>
inline uint64_t IosFfsBypassLog[4] {};
inline uint64_t IosCbEntryLog[8] {};

// Another unguarded diagnostic, IosLogUnimplementedCASPAL, asks VirtualQuery
// about a faulting address. Supply real Mach region information for that log.
// These names are never used by the guest memory manager in this native build.
using LPCVOID = const void *;
inline constexpr uint32_t MEM_IMAGE = 0x1000000, MEM_MAPPED = 0x40000;
struct MEMORY_BASIC_INFORMATION {
    void *BaseAddress {};
    size_t RegionSize {};
    uint32_t Protect {}, Type {}, State {};
};
inline size_t VirtualQuery(LPCVOID pointer, MEMORY_BASIC_INFORMATION *out, size_t length) {
    if (length < sizeof(*out)) return 0;
    vm_address_t address = reinterpret_cast<vm_address_t>(pointer);
    const auto requested = address;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info {};
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object = MACH_PORT_NULL;
    const auto result = vm_region_64(mach_task_self(), &address, &size, VM_REGION_BASIC_INFO_64,
                                    reinterpret_cast<vm_region_info_t>(&info), &count, &object);
    if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), object);
    if (result != KERN_SUCCESS || address > requested) return 0;
    out->BaseAddress = reinterpret_cast<void *>(address);
    out->RegionSize = size;
    out->Protect = info.protection; // Mach protection flags, for diagnostics only.
    out->Type = MEM_MAPPED;
    out->State = info.reserved;
    return sizeof(*out);
}
#endif
