/// Shared pagination constants and helpers for repository layer.
const kDefaultPageLimit = 20;
const kMaxPageLimit = 100;

int safeLimit(int limit) => limit.clamp(1, kMaxPageLimit);
int safeOffset(int offset) => offset < 0 ? 0 : offset;
