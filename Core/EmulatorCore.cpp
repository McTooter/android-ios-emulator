#include "EmulatorCore.h"

#include <cstdio>
#include <cstring>
#include <new>

struct EmulatorCore {
    EmulatorCoreStatus status = EMULATOR_STATUS_STOPPED;
    uint64_t frames_rendered = 0;
    EmulatorCoreProfile profile{};
    char message[256] = "Android runtime core is not linked";
};

static void set_message(EmulatorCore *core, const char *message) {
    if (!core) return;
    std::snprintf(core->message, sizeof(core->message), "%s", message);
}

EmulatorCore *emulator_core_create(void) {
    return new (std::nothrow) EmulatorCore();
}

void emulator_core_destroy(EmulatorCore *core) {
    delete core;
}

int emulator_core_start(
    EmulatorCore *core,
    const char *apk_path,
    const char *storage_path,
    const EmulatorCoreProfile *profile
) {
    if (!core || !apk_path || !storage_path || !profile) return -1;
    core->profile = *profile;
    core->status = EMULATOR_STATUS_FAILED;
    set_message(core, "Stub only: link a licensed Android/QEMU runtime backend");
    return 1;
}

int emulator_core_pause(EmulatorCore *core) {
    if (!core) return -1;
    if (core->status == EMULATOR_STATUS_RUNNING) {
        core->status = EMULATOR_STATUS_PAUSED;
        set_message(core, "Paused");
        return 0;
    }
    return 1;
}

int emulator_core_resume(EmulatorCore *core) {
    if (!core) return -1;
    if (core->status == EMULATOR_STATUS_PAUSED) {
        core->status = EMULATOR_STATUS_RUNNING;
        set_message(core, "Running");
        return 0;
    }
    return 1;
}

int emulator_core_stop(EmulatorCore *core) {
    if (!core) return -1;
    core->status = EMULATOR_STATUS_STOPPED;
    set_message(core, "Stopped");
    return 0;
}

int emulator_core_snapshot(
    const EmulatorCore *core,
    EmulatorCoreSnapshot *snapshot
) {
    if (!core || !snapshot) return -1;
    std::memset(snapshot, 0, sizeof(*snapshot));
    snapshot->status = core->status;
    snapshot->frames_rendered = core->frames_rendered;
    snapshot->guest_memory_bytes = static_cast<uint64_t>(core->profile.memory_mb) * 1024ULL * 1024ULL;
    std::snprintf(snapshot->message, sizeof(snapshot->message), "%s", core->message);
    return 0;
}
