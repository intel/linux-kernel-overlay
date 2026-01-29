#!/bin/bash

#
# Constants
#
# default key
DK='default'
# rt key
RK='rt'
# default variant key
DVK='emt'
declare -A BASE_PATH=(
    [mainline-tracking/emt/v6.17,$DVK]='overlay/base-os/config'
    [mainline-tracking/emt/v6.17,$DVK,$RK]='overlay/base-os/config-rt'
    [$DK,$DVK]='overlay/base-os/config'
    [$DK,$DVK,$RK]='overlay/base-os/config-rt'
)
# Key rules for KCONF_PATHS:
#   There are three fields of the keys:
#     1 sequence number: set the handling order
#     2 type: dir, cfg, rt
#       dir: folder which contains the kernel config file
#       cfg: single kernel config file
#       rt: the kernel config file for the real-time mode
#     3 the name of the path variable
declare -A KCONF_PATHS=(
)
