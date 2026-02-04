#!/bin/bash

#
# Constants
#
# default key
DK='default'
# rt key
RK='rt'
# default variant key
DVK='deb'
declare -A BASE_PATH=(
    [mainline-tracking/v6.19-rc3,$DVK]='overlay/base-os/noble.config-6.8.0-31-generic'
    [$DK,$DVK]='overlay/base-os/noble.config-6.8.0-31-generic'
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
    [1,dir,features_dir]='overlay/features'
    [2,$RK,$RK]='overlay/features/rt.cfg'
    [3,cfg,overlay]='overlay/overlay/overlay.cfg'
)
