#include <unistd.h>
#include <fcntl.h>

#include <sys/mman.h>

#include <stdio.h>
#include <string.h>
#include <errno.h>

int main(int argc, const char **argv)
{
	const char *file, *context;
	void *ptr;
	int rdonly, fd, ctxfd, ret;

	if (argc < 3  || argc > 4 || (strcmp(argv[2], "RDONLY") && strcmp(argv[2], "RDWR"))) {
		fprintf(stderr, "Usage %s <file> RDONLY|RDWR\n", argv[0]);
		return EINVAL;
	}

	file = argv[1];
	rdonly = strcmp(argv[2], "RDONLY") == 0;
	context = argc >= 4 ? argv[3] : NULL;

	fd = open(file, rdonly ? O_RDONLY : O_RDWR);
	if (fd == -1) {
		perror("open");
		return 2;
	}

	/* try direct mmap */
	ptr = mmap(NULL, 1, rdonly ? PROT_READ : PROT_READ|PROT_WRITE,
		   MAP_SHARED, fd, 0);
	if (ptr == MAP_FAILED) {
		perror("mmap");
		return 3;
	}
	munmap(ptr, 1);

	/* try mmap with PROT_NONE followed by mprotect with full access */
	ptr = mmap(NULL, 1, PROT_NONE, MAP_SHARED, fd, 0);
	if (ptr == MAP_FAILED) {
		perror("mmap PROT_NONE");
		return 4;
	}

	if (context) {
		ctxfd = open("/proc/self/attr/current", O_RDWR);
		if (ctxfd == -1) {
			perror("open");
			return 6;
		}
		ret = write(ctxfd, context, strlen(context));
		if (ret == -1) {
			perror("write");
			return 7;
		}
		close(ctxfd);
	}

	ret = mprotect(ptr, 1, rdonly ? PROT_READ : PROT_READ|PROT_WRITE);
	if (ret == -1) {
		perror("mprotect");
		return 5;
	}

	munmap(ptr, 1);
	close(fd);
	return 0;
}
