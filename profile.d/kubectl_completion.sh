if command -v kubectl >/dev/null 2>&1; then
   source <(kubectl completion bash)
   alias k=kubectl
   complete -F __start_kubectl k
   export KUBECTL_COMPLETION_INSTALLED=yes
else
   export KUBECTL_COMPLETION_INSTALLED=no
fi