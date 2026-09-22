#include <iostream>
#include <cstdio>
#include <cstring>
#include <unistd.h>
#include <string>
#include <stdexcept>

#ifdef __ANDROID__
#include <android/log.h>
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "LC0_FFI", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "LC0_FFI", __VA_ARGS__)
#else
#define LOGD(...) fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n")
#define LOGE(...) fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n")
#endif

#include "ffi.h"

// lc0 main function declaration
int main(int argc, const char** argv);

// Pipe management for stdin/stdout redirection
#define NUM_PIPES 2
#define PARENT_WRITE_PIPE 0
#define PARENT_READ_PIPE 1
#define READ_FD 0
#define WRITE_FD 1
#define PARENT_READ_FD (pipes[PARENT_READ_PIPE][READ_FD])
#define PARENT_WRITE_FD (pipes[PARENT_WRITE_PIPE][WRITE_FD])
#define CHILD_READ_FD (pipes[PARENT_WRITE_PIPE][READ_FD])
#define CHILD_WRITE_FD (pipes[PARENT_READ_PIPE][WRITE_FD])

static const char *QUITOK = "quitok\n";
static int pipes[NUM_PIPES][2] = {{-1, -1}, {-1, -1}};
static char buffer[4096];
static std::string weightsPath;
static bool pipesInitialized = false;

static void closeFd(int& fd)
{
    if (fd >= 0) {
        close(fd);
        fd = -1;
    }
}

static void closePipes()
{
    for (int i = 0; i < NUM_PIPES; ++i) {
        closeFd(pipes[i][READ_FD]);
        closeFd(pipes[i][WRITE_FD]);
    }
    pipesInitialized = false;
}

static void restoreFd(int savedFd, int targetFd)
{
    if (savedFd >= 0) {
        dup2(savedFd, targetFd);
        close(savedFd);
    }
}

extern "C" {

int lc0_init()
{
    LOGD("lc0_init() called");
    closePipes();
    weightsPath.clear();
    if (pipe(pipes[PARENT_READ_PIPE]) != 0) {
        LOGE("Failed to create PARENT_READ_PIPE");
        return -1;
    }
    if (pipe(pipes[PARENT_WRITE_PIPE]) != 0) {
        LOGE("Failed to create PARENT_WRITE_PIPE");
        closePipes();
        return -2;
    }
    pipesInitialized = true;
    LOGD("lc0_init() completed successfully");
    return 0;
}

void lc0_set_weights(const char* path)
{
    if (path != nullptr) {
        weightsPath = path;
        LOGD("lc0_set_weights() set path to: %s", path);
    } else {
        LOGE("lc0_set_weights() called with null path");
    }
}

int lc0_main()
{
    LOGD("lc0_main() called, weightsPath=%s", weightsPath.c_str());
    if (!pipesInitialized) {
        LOGE("lc0_main() called before lc0_init()");
        return -3;
    }

    // Redirect stdin/stdout to pipes
    // On Android, keep stderr going to logcat for debugging
    LOGD("Redirecting stdin/stdout to pipes...");
    int originalStdin = dup(STDIN_FILENO);
    int originalStdout = dup(STDOUT_FILENO);
#ifndef __ANDROID__
    int originalStderr = dup(STDERR_FILENO);
#endif
    dup2(CHILD_READ_FD, STDIN_FILENO);
    dup2(CHILD_WRITE_FD, STDOUT_FILENO);
#ifndef __ANDROID__
    // On non-Android (iOS), also redirect stderr
    dup2(CHILD_WRITE_FD, STDERR_FILENO);
#endif
    LOGD("Pipe redirection complete, about to call main()...");

    int exitCode;

    try {
        if (!weightsPath.empty()) {
            FILE* f = fopen(weightsPath.c_str(), "r");
            if (f) {
                fclose(f);
                LOGD("Weights file exists and is readable");
            } else {
                LOGE("WARNING: Cannot open weights file: %s", weightsPath.c_str());
            }

            // Just pass weights, let lc0 use DEFAULT_BACKEND
            std::string weightsArg = "--weights=" + weightsPath;
            LOGD("Calling lc0 main with args: lc0 %s", weightsArg.c_str());
            const char *argv[] = {"lc0", weightsArg.c_str()};
            exitCode = main(2, argv);
        } else {
            LOGD("Calling lc0 main without weights");
            const char *argv[] = {"lc0"};
            exitCode = main(1, argv);
        }
    } catch (std::exception& e) {
        LOGE("lc0 main threw exception: %s", e.what());
        exitCode = 1;
    } catch (...) {
        LOGE("lc0 main threw unknown exception");
        exitCode = 1;
    }

    LOGD("lc0 main returned with exitCode=%d", exitCode);
    std::cout << QUITOK << std::flush;
    restoreFd(originalStdin, STDIN_FILENO);
    restoreFd(originalStdout, STDOUT_FILENO);
#ifndef __ANDROID__
    restoreFd(originalStderr, STDERR_FILENO);
#endif
    closePipes();

    return exitCode;
}

ssize_t lc0_stdin_write(char *data)
{
    if (data == nullptr || !pipesInitialized) {
        return 0;
    }
    return write(PARENT_WRITE_FD, data, strlen(data));
}

char *lc0_stdout_read()
{
    size_t total = 0;
    while (total < sizeof(buffer) - 1) {
        char ch;
        ssize_t count = read(PARENT_READ_FD, &ch, 1);
        if (count <= 0) {
            if (total == 0) {
                return nullptr;
            }
            break;
        }
        buffer[total++] = ch;
        if (ch == '\n') {
            break;
        }
    }

    buffer[total] = '\0';
    if (strcmp(buffer, QUITOK) == 0) {
        return nullptr;
    }

    return buffer;
}

} // extern "C"
