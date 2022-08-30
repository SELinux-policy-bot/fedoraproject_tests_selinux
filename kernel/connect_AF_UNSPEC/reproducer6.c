#include <sys/types.h>
#include <sys/socket.h>

#include <netinet/in.h>

#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

int main(int argc, char **argv)
{
	int fd;
	struct sockaddr_in6 addr;
	struct sockaddr addr_unspec;

	if (argc < 2)
		return 2;

	fd = socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
	if (fd < 0) {
		perror(argv[0]);
		return 1;
	}

	memset(&addr, 0, sizeof(addr));
	addr.sin6_family = AF_INET6;
	addr.sin6_port = htons(atoi(argv[1]));
	addr.sin6_addr = (struct in6_addr)IN6ADDR_LOOPBACK_INIT;

	if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
		perror(argv[0]);
		close(fd);
		return 1;
	}

	memset(&addr_unspec, 0, sizeof(addr_unspec));
	addr_unspec.sa_family = AF_UNSPEC;
	if (connect(fd, (struct sockaddr *)&addr_unspec, sizeof(addr_unspec)) < 0) {
		perror(argv[0]);
		close(fd);
		return 1;
	}

	close(fd);
	return 0;
}
