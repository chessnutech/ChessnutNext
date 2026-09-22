#ifndef LC0_FFI_H
#define LC0_FFI_H

#ifdef __cplusplus
extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif
int
lc0_init();

#ifdef __cplusplus
extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif
void
lc0_set_weights(const char* path);

#ifdef __cplusplus
extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif
int
lc0_main();

#ifdef __cplusplus
extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif
ssize_t
lc0_stdin_write(char *data);

#ifdef __cplusplus
extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif
char *
lc0_stdout_read();

#endif // LC0_FFI_H
