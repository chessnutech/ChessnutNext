#include <iostream>
#include <stdio.h>
#include <unistd.h>

#include "../Stockfish/src/bitboard.h"
#include "../Stockfish/src/misc.h"
#include "../Stockfish/src/position.h"
#include "../Stockfish/src/types.h"
#include "../Stockfish/src/uci.h"
#include "../Stockfish/src/tune.h"

#include "ffi.h"

// https://jineshkj.wordpress.com/2006/12/22/how-to-capture-stdin-stdout-and-stderr-of-child-program/
#define NUM_PIPES 2
#define PARENT_WRITE_PIPE 0
#define PARENT_READ_PIPE 1
#define READ_FD 0
#define WRITE_FD 1
#define PARENT_READ_FD (pipes[PARENT_READ_PIPE][READ_FD])
#define PARENT_WRITE_FD (pipes[PARENT_WRITE_PIPE][WRITE_FD])
#define CHILD_READ_FD (pipes[PARENT_WRITE_PIPE][READ_FD])
#define CHILD_WRITE_FD (pipes[PARENT_READ_PIPE][WRITE_FD])

int main(int, char **);

const char *QUITOK = "quitok\n";
int pipes[NUM_PIPES][2] = {{-1, -1}, {-1, -1}};
char buffer[80];
bool pipesInitialized = false;

void closeFd(int& fd)
{
  if (fd >= 0)
  {
    close(fd);
    fd = -1;
  }
}

void closePipes()
{
  for (int i = 0; i < NUM_PIPES; ++i)
  {
    closeFd(pipes[i][READ_FD]);
    closeFd(pipes[i][WRITE_FD]);
  }
  pipesInitialized = false;
}

void restoreFd(int savedFd, int targetFd)
{
  if (savedFd >= 0)
  {
    dup2(savedFd, targetFd);
    close(savedFd);
  }
}

int stockfish_init()
{
  closePipes();
  pipe(pipes[PARENT_READ_PIPE]);
  pipe(pipes[PARENT_WRITE_PIPE]);
  pipesInitialized = true;

  return 0;
}

int stockfish_main()
{
  if (!pipesInitialized)
  {
    return -1;
  }

  int originalStdin = dup(STDIN_FILENO);
  int originalStdout = dup(STDOUT_FILENO);
  dup2(CHILD_READ_FD, STDIN_FILENO);
  dup2(CHILD_WRITE_FD, STDOUT_FILENO);

  int argc = 1;
  char *argv[] = {""};
  int exitCode = main(argc, argv);

  std::cout << QUITOK << std::flush;
  restoreFd(originalStdin, STDIN_FILENO);
  restoreFd(originalStdout, STDOUT_FILENO);
  closePipes();

  return exitCode;
}

ssize_t stockfish_stdin_write(char *data)
{
  if (data == nullptr || !pipesInitialized)
  {
    return 0;
  }
  return write(PARENT_WRITE_FD, data, strlen(data));
}

char *stockfish_stdout_read()
{
  ssize_t count = read(PARENT_READ_FD, buffer, sizeof(buffer) - 1);
  if (count <= 0)
  {
    return NULL;
  }

  buffer[count] = 0;
  if (strcmp(buffer, QUITOK) == 0)
  {
    return NULL;
  }

  return buffer;
}
