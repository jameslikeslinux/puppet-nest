#!/bin/bash
#
# Bolt wrapper
# Trap exit signal and cleanup
#

[[ $BOLT_CLEANUP_CMD ]] && trap "$BOLT_CLEANUP_CMD" EXIT
bolt "$@"