/* SPDX-License-Identifier: GPLv2 */
/* Copyright (c) 2026 Red Hat, Inc. */
/* Author: Ondrej Mosnacek <omosnace@redhat.com> */

#define _GNU_SOURCE

#include <errno.h>
#include <string.h>
#include <stdio.h>

#include <fcntl.h>
#include <unistd.h>

#include <sys/fanotify.h>

int main(int argc, char **argv)
{
	int ffd, ret, rc, pfd[2];

	ret = pipe2(pfd, O_CLOEXEC);
	if (ret == -1) {
		perror("pipe2");
		rc = 2;
		goto exit;
	}

	ffd = fanotify_init(FAN_CLASS_NOTIF, O_RDONLY);
	if (ffd == -1) {
		perror("fanotify_init");
		rc = 2;
		goto exit_close_pipes;
	}

	rc = 0;

	ret = fanotify_mark(ffd, FAN_MARK_ADD | FAN_MARK_MOUNT, FAN_ACCESS,
			    pfd[0], NULL);
	if (ret == 0) {
		printf("FAIL: fanotify_mark() with FAN_MARK_MOUNT succeeded\n");
		rc = 1;
	} else if (errno == EINVAL) {
		printf("PASS: fanotify_mark() with FAN_MARK_MOUNT failed with EINVAL as expected\n");
	} else {
		printf("FAIL: fanotify_mark() with FAN_MARK_MOUNT failed with %s\n", strerror(errno));
		rc = 1;
	}

	ret = fanotify_mark(ffd, FAN_MARK_ADD | FAN_MARK_FILESYSTEM, FAN_ACCESS,
			    pfd[0], NULL);
	if (ret == 0) {
		printf("FAIL: fanotify_mark() with FAN_MARK_FILESYSTEM succeeded\n");
		rc = 1;
	} else if (errno == EINVAL) {
		printf("PASS: fanotify_mark() with FAN_MARK_FILESYSTEM failed with EINVAL as expected\n");
	} else {
		printf("FAIL: fanotify_mark() with FAN_MARK_FILESYSTEM failed with %s\n", strerror(errno));
		rc = 1;
	}

	close(ffd);
exit_close_pipes:
	close(pfd[0]);
	close(pfd[1]);
exit:
	return rc;
}
