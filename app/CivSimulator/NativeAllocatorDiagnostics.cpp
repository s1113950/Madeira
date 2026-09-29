// SPDX-License-Identifier: GPL-3.0-or-later
// FEX's native Apple allocator is libc. There is no rpmalloc remote-free
// snapshot to drain; its optional diagnostic hook must report "no snapshot".
extern "C" {
struct rpm_cas_snapshot;
int rpm_cas_snapshot_take(struct rpm_cas_snapshot *) { return 0; }
}
