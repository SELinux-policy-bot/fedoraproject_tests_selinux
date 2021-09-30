#include <assert.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static void test_assert(int cond) {
  if (!cond) {
     abort();
  }
}

static void do_child(int sock) {
  int fd;
  struct msghdr msg;
  char mbuf;
  struct iovec iov = { &mbuf, 1 };
  char cbuf[CMSG_SPACE(sizeof(fd))];
  const struct cmsghdr* cmsg;

  memset(&msg, 0, sizeof(msg));
  msg.msg_iov = &iov;
  msg.msg_iovlen = 1;
  msg.msg_control = cbuf;
  msg.msg_controllen = sizeof(cbuf);

  test_assert(recvmsg(sock, &msg, 0) == 1);
  test_assert(mbuf == 'x');

  test_assert(!(msg.msg_flags & MSG_CTRUNC));
  test_assert(msg.msg_controllen == CMSG_SPACE(sizeof(fd)));
  cmsg = CMSG_FIRSTHDR(&msg);
  test_assert(SOL_SOCKET == cmsg->cmsg_level && SCM_RIGHTS == cmsg->cmsg_type);
  memcpy(&fd, CMSG_DATA(cmsg), sizeof(fd));

  printf("fd=%d\n", fd);
}

#define USER_MODE_ONLY 1

int main(void) {
  int sockfds[2];
  pid_t child;
  int fd;
  struct msghdr msg;
  struct iovec iov = { "x", 1 };
  char cbuf[CMSG_SPACE(sizeof(fd))];
  struct cmsghdr* cmsg;
  ssize_t nsent;
  int status;

  test_assert(0 == socketpair(AF_LOCAL, SOCK_STREAM, 0, sockfds));

  if (0 == (child = fork())) {
    do_child(sockfds[1]);
    return 0;
  }

  fd = syscall(SYS_userfaultfd, USER_MODE_ONLY);
  test_assert(fd >= 0);

  memset(&msg, 0, sizeof(msg));
  msg.msg_iov = &iov;
  msg.msg_iovlen = 1;
  msg.msg_control = cbuf;
  msg.msg_controllen = sizeof(cbuf);
  cmsg = CMSG_FIRSTHDR(&msg);
  cmsg->cmsg_level = SOL_SOCKET;
  cmsg->cmsg_type = SCM_RIGHTS;
  cmsg->cmsg_len = CMSG_LEN(sizeof(fd));
  memcpy(CMSG_DATA(cmsg), &fd, sizeof(fd));

  test_assert(sendmsg(sockfds[0], &msg, 0) == 1);

  test_assert(child == waitpid(child, &status, 0));
  test_assert(WIFEXITED(status) && 0 == WEXITSTATUS(status));

  return 0;
}
