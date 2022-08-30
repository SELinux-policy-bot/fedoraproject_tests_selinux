#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>

int main(void)
{
	int fd, r;

	fd = open("/proc/self/attr/keycreate", O_WRONLY);
	if (fd < 0) {
		perror("open");
	}

	r = write(fd, "", 0);
	if (r < 0) {
		perror("write");
	}

	return !!r;
}
