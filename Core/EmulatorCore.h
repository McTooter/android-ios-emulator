#ifndef EMULATOR_CORE_H
#define EMULATOR_CORE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct EmulatorCore EmulatorCore;

typedef enum EmulatorCoreStatus {
    EMULATOR_STATUS_STOPPED = 0,
    EMULATOR_STATUS_STARTING = 1,
    EMULATOR_STATUS_RUNNING = 2,
    EMULATOR_STATUS_PAUSED = 3,
    EMULATOR_STATUS_FAILED = 4
} EmulatorCoreStatus;

typedef struct EmulatorCoreProfile {
    uint32_t memory_mb;
    uint32_t cpu_threads;
    uint32_t frame_rate_limit;
    uint32_t resolution_scale_percent;
    uint32_t graphics_backend; // 0 = Metal translation, 1 = software fallback
    uint32_t execution_mode;   // 0 = interpreter, 1 = externally enabled acceleration
} EmulatorCoreProfile;

typedef struct EmulatorCoreSnapshot {
    EmulatorCoreStatus status;
    uint64_t frames_rendered;
    uint64_t guest_memory_bytes;
    uint32_t guest_cpu_percent;
    uint32_t guest_fps;
    char message[256];
} EmulatorCoreSnapshot;

EmulatorCore *emulator_core_create(void);
void emulator_core_destroy(EmulatorCore *core);
int emulator_core_start(
    EmulatorCore *core,
    const char *apk_path,
    const char *storage_path,
    const EmulatorCoreProfile *profile
);
int emulator_core_pause(EmulatorCore *core);
int emulator_core_resume(EmulatorCore *core);
int emulator_core_stop(EmulatorCore *core);
int emulator_core_snapshot(
    const EmulatorCore *core,
    EmulatorCoreSnapshot *snapshot
);

#ifdef __cplusplus
}
#endif

#endif
