if command -v kubectl >/dev/null 2>&1; then
   source <(kubectl completion bash)
   export KUBECTL_COMPLETION_INSTALLED=yes
else
   export KUBECTL_COMPLETION_INSTALLED=no
fi