#!/bin/bash
id -Z
NOTIFY_SOCKET=/run/systemd/notify systemd-notify --ready
NOTIFY_SOCKET=/run/systemd/notify systemd-notify --ready

