#!/bin/bash

if command -v helm >/dev/null 2>&1; then
   source <(helm completion bash)
fi
