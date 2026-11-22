#pragma once
#include <math.h>
#include <stdbool.h>

/* Native adaptation of C2006L/dafeiyu scripts/ollama-pet-server.mjs:
 * work -> rest -> work. No timers, storage, network or animation delays here.
 * startedAt and now are Unix seconds, never uptime or milliseconds.
 * The persisted active session is immutable; saved config applies next start.
 */
typedef enum {
    MowangDaFeiYuPetPomoIdle = 0,
    MowangDaFeiYuPetPomoWork = 1,
    MowangDaFeiYuPetPomoRest = 2
} MowangDaFeiYuPetPomoPhase;

typedef struct {
    MowangDaFeiYuPetPomoPhase phase;
    unsigned remainingSeconds; /* ceil, nonzero for an active phase */
    double cycleIndex;         /* zero-based completed work/rest cycles */
    double phaseStartedAt;
    double endsAt;
} MowangDaFeiYuPetPomoSnapshot;

static inline bool mowang_dafeiyupet_pomo_validMinutes(int minutes) {
    return minutes >= 1 && minutes <= 600;
}

static inline MowangDaFeiYuPetPomoSnapshot mowang_dafeiyupet_pomo_snapshot(
        double startedAt, int workMin, int restMin, double now) {
    MowangDaFeiYuPetPomoSnapshot s = {0};
    if (!isfinite(startedAt) || startedAt <= 0 || !isfinite(now) ||
        !mowang_dafeiyupet_pomo_validMinutes(workMin) ||
        !mowang_dafeiyupet_pomo_validMinutes(restMin)) return s;
    double elapsed = now - startedAt;
    if (!isfinite(elapsed)) return s;
    /* A backwards wall clock clamps to the beginning rather than underflowing. */
    if (elapsed < 0) elapsed = 0;
    double work = workMin * 60.0, rest = restMin * 60.0, cycle = work + rest;
    double position = fmod(elapsed, cycle);
    s.cycleIndex = floor(elapsed / cycle);
    s.phase = position < work ? MowangDaFeiYuPetPomoWork : MowangDaFeiYuPetPomoRest;
    double phaseElapsed = s.phase == MowangDaFeiYuPetPomoWork ? position : position - work;
    double duration = s.phase == MowangDaFeiYuPetPomoWork ? work : rest;
    s.remainingSeconds = (unsigned)ceil(duration - phaseElapsed);
    double anchor = now < startedAt ? startedAt : now;
    s.phaseStartedAt = anchor - phaseElapsed;
    s.endsAt = s.phaseStartedAt + duration;
    return s;
}
