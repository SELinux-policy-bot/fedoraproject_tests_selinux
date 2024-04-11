// SPDX-License-Identifier: GPL-2.0
/*
 * A reproducer that checks that CIPSO options are cleared properly
 * by NetLabel when it is configured to send unabeled traffic.
 *
 * Copyright (c) 2024 Red Hat, Inc.
 * Author: Ondrej Mosnacek <omosnace@redhat.com>
 */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

int run_test(int csock, int ssock, const struct addrinfo *clientinfo,
	     int tnum, size_t expected_opt_length)
{
	char byte;
	struct iovec iov;
	struct msghdr msg;
	struct cmsghdr *cmsg;
	union {
		struct cmsghdr cmsghdr;
		char buf[CMSG_SPACE(256)];
	} control;
	int ret, i, result;

	printf("TEST #%i\n", tnum);

	byte = 0;
	ret = sendto(csock, &byte, 1, 0, clientinfo->ai_addr, clientinfo->ai_addrlen);
	if (ret < 0) {
		perror("sendto");
		exit(2);
	}

	memset(&iov, 0, sizeof(iov));
	iov.iov_base = &byte;
	iov.iov_len = 1;
	memset(&msg, 0, sizeof(msg));
	msg.msg_iov = &iov;
	msg.msg_iovlen = 1;
	msg.msg_control = &control;
	msg.msg_controllen = sizeof(control);
	ret = recvmsg(ssock, &msg, 0);
	if (ret < 0) {
		perror("recvmsg");
		exit(2);
	}
	for (cmsg = CMSG_FIRSTHDR(&msg); cmsg;
	     cmsg = CMSG_NXTHDR(&msg, cmsg)) {
		if (cmsg->cmsg_level != SOL_IP ||
		    cmsg->cmsg_type != IP_RECVOPTS)
			continue;

		if (cmsg->cmsg_len - sizeof(struct cmsghdr) > 0) {
			printf("  options: ");
			for (i = 0; i < cmsg->cmsg_len - sizeof(struct cmsghdr); i++) {
				printf("%02x ", (unsigned)(CMSG_DATA(cmsg)[i]));
			}
			printf("\n");
			result = expected_opt_length == cmsg->cmsg_len - sizeof(struct cmsghdr);
			goto done;
		}
	}
	printf("  no IP options\n");
	result = expected_opt_length == 0;

done:
	if (result)
		printf("  PASS\n");
	else
		printf("  FAIL\n");
	return result;
}

int main(int argc, char **argv)
{
	static const unsigned char TEST_OPTION[] = {
		1,           // NOP
		158,         // option type - Experimental
		5,           // option length
		0x12, 0x34, 0x56, // dummy data
		1,           // NOP
		134,         // option type - CIPSO
		11,          // option length
		0, 0, 0, 16, // DOI
		1,           // tag type 1
		5,           // tag length
		0,           // alignment octet
		1,           // sensitivity
		0xff,        // bitmap of categories
		1,           // NOP
		158,         // option type - Experimental
		5,           // option length
		0x12, 0x34, 0x56, // dummy data
	};
	static const size_t TEST_OPTION_CIPSO_OFF = 7;
	static const size_t TEST_OPTION_CIPSO_LEN = 11;

	int ret, result, csock, ssock, on = 1;
	struct addrinfo hints, *serverinfo, *clientinfo;

	if (argc != 3) {
		fprintf(stderr, "need 2 arguments!\n");
		exit(2);
	}

	memset(&hints, 0, sizeof(struct addrinfo));

	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_DGRAM;
	hints.ai_protocol = IPPROTO_UDP;

	ret = getaddrinfo(argv[1], argv[2], &hints, &clientinfo);
	if (ret < 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(ret));
		exit(2);
	}

	ret = getaddrinfo(NULL, argv[2], &hints, &serverinfo);
	if (ret < 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(ret));
		exit(2);
	}

	csock = socket(clientinfo->ai_family, clientinfo->ai_socktype,
		       IPPROTO_UDP);
	if (csock < 0) {
		perror("client socket");
		exit(2);
	}

	ssock = socket(serverinfo->ai_family, serverinfo->ai_socktype,
		       IPPROTO_UDP);
	if (ssock < 0) {
		perror("server socket");
		exit(2);
	}

	ret = setsockopt(ssock, SOL_IP, IP_RECVOPTS, &on, sizeof(on));
	if (ret < 0) {
		perror("server setsockopt: IP_RECVOPTS");
		exit(2);
	}

	if (bind(ssock, serverinfo->ai_addr, serverinfo->ai_addrlen) < 0) {
		perror("server bind");
		exit(2);
	}

	result = 1;

	/* TEST 1 - only CIPSO */
	ret = setsockopt(csock, SOL_IP, IP_OPTIONS,
			 TEST_OPTION + TEST_OPTION_CIPSO_OFF,
			 TEST_OPTION_CIPSO_LEN);
	if (ret < 0) {
		perror("client setsockopt: IP_OPTIONS");
		exit(2);
	}
	if (!run_test(csock, ssock, clientinfo, 1, 0))
		result = 0;

	/* TEST 2 - CIPSO surrounded by other options */
	ret = setsockopt(csock, SOL_IP, IP_OPTIONS,
			 TEST_OPTION, sizeof(TEST_OPTION));
	if (ret < 0) {
		perror("client setsockopt: IP_OPTIONS");
		exit(2);
	}
	if (!run_test(csock, ssock, clientinfo, 2,
		      (sizeof(TEST_OPTION) - TEST_OPTION_CIPSO_LEN) + 3) & 3)
		result = 0;

	return result ? 0 : 1;
}
