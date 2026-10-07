#!/bin/bash

if command -v helm >/dev/null 2>&1; then
   eval "$(helm completion bash)"
fi
