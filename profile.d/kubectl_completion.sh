if command -v kubectl >/dev/null 2>&1; then
   source <(kubectl completion bash)
   export KUBECTL_COMPLETION_INSTALLED=yes
else
   echo "kubectl not found, not installing bash completion"
   export KUBECTL_COMPLETION_INSTALLED=no
fi