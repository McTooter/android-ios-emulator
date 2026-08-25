#include "EmulatorCore.h"
#include <cassert>
#include <cstring>
#include <iostream>

int main() {
    EmulatorCore *core = emulator_core_create();
    assert(core != nullptr);

    EmulatorCoreProfile profile{};
    profile.memory_mb = 2048;
    profile.cpu_threads = 4;
    profile.frame_rate_limit = 60;
    profile.resolution_scale_percent = 100;
    profile.graphics_backend = 0;
    profile.execution_mode = 0;

    int start_result = emulator_core_start(core, "sample.apk", "profile-1", &profile);
    assert(start_result == 1);

    EmulatorCoreSnapshot snapshot{};
    int snapshot_result = emulator_core_snapshot(core, &snapshot);
    assert(snapshot_result == 0);
    assert(snapshot.status == EMULATOR_STATUS_FAILED);
    assert(std::strlen(snapshot.message) > 0);
    if (snapshot_result != 0 || snapshot.status != EMULATOR_STATUS_FAILED || snapshot.message[0] == '\0') {
        std::cerr << "core snapshot validation failed\n";
        return 1;
    }

    assert(emulator_core_stop(core) == 0);
    emulator_core_destroy(core);
    std::cout << "core smoke test passed: " << snapshot.message << "\n";
    return 0;
}
