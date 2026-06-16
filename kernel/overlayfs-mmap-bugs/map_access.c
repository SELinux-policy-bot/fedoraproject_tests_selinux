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
	int rdonly, execmem, flags, prot, fd, ctxfd, ret;

	if (argc < 4  || argc > 5 ||
	    (strcmp(argv[2], "RDONLY") && strcmp(argv[2], "RDWR")) ||
	    (strcmp(argv[3], "SHARED") && strcmp(argv[3], "PRIVATE"))
	   ) {
		fprintf(stderr, "Usage %s <file> RDONLY|RDWR\n", argv[0]);
		return EINVAL;
	}

	file = argv[1];
	rdonly = strcmp(argv[2], "RDONLY") == 0;
	execmem = strcmp(argv[3], "PRIVATE") == 0;
	flags = strcmp(argv[3], "PRIVATE") == 0 ? MAP_PRIVATE : MAP_SHARED;
	prot = PROT_READ | (!rdonly || execmem ? PROT_WRITE : 0) | (execmem ? PROT_EXEC : 0);
	context = argc >= 5 ? argv[4] : NULL;

	fd = open(file, rdonly ? O_RDONLY : O_RDWR);
	if (fd == -1) {
		perror("open");
		return 2;
	}

	/* try direct mmap */
	ptr = mmap(NULL, 1, prot, flags, fd, 0);
	if (ptr == MAP_FAILED) {
		perror("mmap");
		return 3;
	}
	munmap(ptr, 1);

	/* try mmap with PROT_NONE followed by mprotect with full access */
	ptr = mmap(NULL, 1, PROT_NONE, flags, fd, 0);
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

	ret = mprotect(ptr, 1, prot);
	if (ret == -1) {
		perror("mprotect");
		return 5;
	}

	munmap(ptr, 1);
	close(fd);
	return 0;
}
