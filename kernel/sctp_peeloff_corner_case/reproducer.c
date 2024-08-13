// SPDX-License-Identifier: GPLv2
/*
 * Copyright (c) 2024 Red Hat, Inc.
 * Author: Ondrej Mosnacek <omosnace@redhat.com>
 */

#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/sctp.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>
#include <netdb.h>

#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>

static const char * const TEST_PORTS[] = { "9998", "9999" };

#define ITERATIONS 1000

#define member_size(type, member) sizeof(((type *)0)->member)
#define sizeof_up_to(type, member) (offsetof(type, member) + member_size(type, member))

enum {
	PIPE_R = 0,
	PIPE_W,
};

int main(int argc, char **argv)
{
	int sock, psock, result, flags, index, i, pipefd[2], pipes[2][2];
	struct addrinfo hints, *info;
	struct sctp_event_subscribe subscr_events;
	pid_t fork_pid;
	char byte = 0x41, data[1024];
	sctp_assoc_t assoc_id;
	union sctp_notification *notif;

	result = pipe(pipefd);
	if (result < 0) {
		perror("pipe");
		return 1;
	}
	pipes[0][PIPE_R] = pipefd[0];
	pipes[1][PIPE_W] = pipefd[1];

	result = pipe(pipefd);
	if (result < 0) {
		perror("pipe");
		return 1;
	}
	pipes[1][PIPE_R] = pipefd[0];
	pipes[0][PIPE_W] = pipefd[1];

	fork_pid = fork();
	if (fork_pid < 0) {
		perror("fork");
		return 1;
	}

	index = !!fork_pid;
	close(pipes[!index][PIPE_R]);
	close(pipes[!index][PIPE_W]);

	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_flags = AI_PASSIVE;
	hints.ai_protocol = IPPROTO_SCTP;
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_SEQPACKET;

	result = getaddrinfo(NULL, TEST_PORTS[index], &hints, &info);
	if (result < 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(result));
		return 1;
	}

	sock = socket(info->ai_family, info->ai_socktype, info->ai_protocol);
	if (sock < 0) {
		perror("socket");
		return 1;
	}

	result = bind(sock, info->ai_addr, info->ai_addrlen);
	if (result < 0) {
		perror("bind");
		return 1;
	}

	if (listen(sock, SOMAXCONN)) {
		perror("listen");
		return 1;
	}

	memset(&subscr_events, 0, sizeof(subscr_events));
	subscr_events.sctp_association_event = 1;
	result = setsockopt(sock, IPPROTO_SCTP, SCTP_EVENTS, &subscr_events,
			    sizeof_up_to(struct sctp_event_subscribe,
					 sctp_association_event));

	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_protocol = IPPROTO_SCTP;
	hints.ai_socktype = SOCK_SEQPACKET;

	result = getaddrinfo("127.0.0.1", TEST_PORTS[!index], &hints, &info);
	if (result < 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(result));
		return 1;
	}

	for (i = 0; i < ITERATIONS; i++) {
		printf("[%i] ITERATION %i...\n", index, i);

		/* synchronize */
		result = write(pipes[index][PIPE_W], &byte, 1);
		if (result < 0) {
			perror("pipe");
			return 1;
		}
		result = read(pipes[index][PIPE_R], &byte, 1);
		if (result < 0) {
			perror("pipe");
			return 1;
		}

		result = connect(sock, info->ai_addr, info->ai_addrlen);
		if (result < 0 && errno != EISCONN) {
			perror("connect");
			return 1;
		}

		/* Get assoc_id for sctp_peeloff() */
		flags = 0;
		result = sctp_recvmsg(sock, data, sizeof(data),
				NULL, 0, NULL, &flags);
		if (result < 0) {
			perror("sctp_recvmsg");
			return 1;
		}

		if ((flags & (MSG_NOTIFICATION | MSG_EOR)) != (MSG_NOTIFICATION | MSG_EOR)) {
			fprintf(stderr, "[%i] Invalid sctp_recvmsg response FLAGS: %x\n", index, flags);
			return 1;
		}

		notif = (union sctp_notification *)data;
		if (notif->sn_header.sn_type != SCTP_ASSOC_CHANGE) {
			fprintf(stderr, "[%i] Invalid sctp_recvmsg response type: %x\n", index, notif->sn_header.sn_type);
			return 1;
		}
		assoc_id = notif->sn_assoc_change.sac_assoc_id;
		psock = sctp_peeloff(sock, assoc_id);
		if (psock < 0) {
			perror("sctp_peeloff");
			return 1;
		}

		data[0] = 42;
		result = sctp_sendmsg(psock, data, 1, NULL, 0,
				      0, 0, 0, 0, 0);
		if (result < 0) {
			perror("sctp_sendmsg");
			return 1;
		}

		result = sctp_recvmsg(psock, data, sizeof(data),
				      NULL, 0, NULL, NULL);
		if (result < 0) {
			perror("sctp_recvmsg");
			return 1;
		}

		if (data[0] != 42) {
			fprintf(stderr, "[%i] Invalid sctp_recvmsg response: %d\n", index, (int)data[0]);
			return 1;
		}

		close(psock);
		printf("[%i] ITERATION %i SUCCESS!\n", index, i);
	}
	close(sock);
	return 0;
}
