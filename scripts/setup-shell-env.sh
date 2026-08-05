#!/usr/bin/env bash

# Initialize the native Neat and ROS 2 environments for every interactive SDK
# user. Login shells may reach this file through both /etc/bash.bashrc and
# /etc/profile.d, so keep repeated sourcing harmless.

if [[ "${ROS2_SDK_ENV_INITIALIZED:-}" == "1" ]]; then
    return 0
fi

# shellcheck disable=SC1091
source /usr/local/bin/setup-native-build-env

case $- in
    *u*) ros2_sdk_restore_nounset=1 ;;
    *) ros2_sdk_restore_nounset=0 ;;
esac
set +u

for ros2_sdk_setup in \
    /usr/local/ros2/local_setup.bash \
    /usr/local/rosbot_navigation/local_setup.bash \
    /usr/local/rtabmap-ros/local_setup.bash; do
    if [[ ! -r "${ros2_sdk_setup}" ]]; then
        echo "Missing SDK environment: ${ros2_sdk_setup}" >&2
        unset ros2_sdk_setup ros2_sdk_restore_nounset
        return 1
    fi

    # shellcheck disable=SC1090
    source "${ros2_sdk_setup}"
done

if [[ "${ros2_sdk_restore_nounset}" == "1" ]]; then
    set -u
fi

export ROS2_SDK_ENV_INITIALIZED=1
unset ros2_sdk_setup ros2_sdk_restore_nounset
