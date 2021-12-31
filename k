#!/bin/sh

# k - kubectl alias (v0.1.0)
# Copyright (C) 2021 by Guillaume MARTINEZ
#
# This file is part of k.
#
# k is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# k is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with k. If not, see <http://www.gnu.org/licenses/>.

K_CONFIG=~/.k/config
K_CONFIGS=~/.k/config.d
K_COMPLETION=~/.k/bash-completion
K_CACHE=~/.cache/k
KUBECTL_BIN="/bin/env kubectl"

_K_CONFIG_CACHE=""

get_config_file() {
  if [ -z "${KUBE_SHELL_INSTANCE}" ]; then
    export KUBE_SHELL_INSTANCE=default
  fi
  echo "${K_CONFIGS}/${KUBE_SHELL_INSTANCE}"
}

read_config () {
  param=$1

  if [ -z "${_K_CONFIG_CACHE}" ]; then
    _K_CONFIG_CACHE=$(cat "$(get_config_file)")
  fi

  echo "${_K_CONFIG_CACHE}" | grep "^${param}=" | sed -e 's/^.*="\(.*\)"$/\1/'
}

write_config () {
  param=$1
  shift
  value=$@

  sed -i 's/^\('${param}'\)=.*$/\1="'${value}'"/' "$(get_config_file)"
  unset _K_CONFIG_CACHE
}

# Return the name of the alias used to call the binary
get_call_name () {
  call_bin=$1

  echo $1 | sed -e 's/^.*\/\(\w\+\)$/\1/g'
}

log () {
  level=$1
  shift
  message=$@

  case "${level}" in
    info) echo "[INFO] ${message}";;
    warning) echo "[WARNING] ${message}" >&2;;
    error) echo "[ERROR] ${message}" >&2;;
    debug) if [ "${K_DEBUG}" = "true" ]; then echo "[DEBUG] ${message}" >&2; fi;;
  esac
}

show_install () {
  cat << EOF > "${K_COMPLETION}"
complete_k_ctx () {
  COMPREPLY=($(compgen -W "$(kc -lc)" "${COMP_WORDS[1]}"))
}
complete_k_ns () {
    COMPREPLY=($(compgen -W "$(kn -lc)" "${COMP_WORDS[1]}"))
  }
complete_k_po () {
    COMPREPLY=($(compgen -W "$(kp -lc)" "${COMP_WORDS[1]}"))
  }

complete -F "complete_k_ctx" kc
complete -F "complete_k_ns" kn
complete -F "complete_k_po" kp
EOF

  cat << EOF
ln -s k kn
ln -s k kc
ln -s k kp

source "${K_COMPLETION}"
EOF
}

_clear_cache () {
  cache_dir="${K_CACHE}/${KUBE_SHELL_INSTANCE}"
  log debug "Clearing cache : ${cache_dir}"
  rm -rf "${cache_dir}"
}

_full_clear_cache () {
  log debug "Full clearing cache : ${K_CACHE}"
  rm -rf "${K_CACHE}"
}

_cache_timeout () {
  cache_dir="${K_CACHE}/${KUBE_SHELL_INSTANCE}"
  find "${cache_dir}" -type f -mmin +0.5 -delete
}

_cache_or_exec () {
  if [ -z "${K_ENABLE_CACHE}" ]; then
    $@
  else
    cache_dir="${K_CACHE}/${KUBE_SHELL_INSTANCE}"
    if ! [ -f "${cache_dir}" ]; then
      mkdir -p "${cache_dir}"
    fi
    _cache_timeout

    hash=$(echo "$@" | md5sum | cut -c -32)
    cache_file="${cache_dir}/${hash}"

    log debug "${cache_file} : $@"

    if [ -f "${cache_file}" ]; then
      cat "${cache_file}"
    else
      $@ | tee "${cache_file}"
    fi
  fi
}

_kubectl_exec () {
  context=$(read_config CURRENT_CONTEXT)
  namespace=$(read_config CURRENT_NAMESPACE)

  log debug "${KUBECTL_BIN} --context="${context}" --namespace="${namespace}" $@"
  _cache_or_exec ${KUBECTL_BIN} --context="${context}" --namespace="${namespace}" $@
}

module_kubectl () {
  if [ "$1" = "--install" ]; then
    show_install
    exit 0
  fi

  _kubectl_exec $@
}

module_context_usage () {
  cat << EOF
Usage:
  kc <CONTEXT> # Set the current context
  kc -l # List all available contexts
  kc -lc # Raw list all available contexts for complete
  kc -w # Get the current context
EOF
}

_kubectl_get_context () {
  log debug "${KUBECTL_BIN} config get-contexts -o name"
  _cache_or_exec ${KUBECTL_BIN} config get-contexts -o name
}

module_context_list () {
  log info "Available contexts :"
  _kubectl_get_context | sed 's/^/  /g'
}

module_context_list_complete () {
  K_ENABLE_CACHE="true" _kubectl_get_context | tr '\n' ' '
}

module_context_where () {
  read_config CURRENT_CONTEXT
}

module_context_switch () {
  context=$1

  log debug "context '${context}'"

  _kubectl_get_context | grep -E "(^|\s)${context}(\s|$)" > /dev/null
  if [ "$?" -ne "0" ]; then
    log error "Context '${context}' not found."

    potential_cluster=$(_kubectl_get_context | grep -E "${context}" | head -1)

    if [ -z "${potential_cluster}" ]; then
      exit 1
    fi

    read -p "Did you mean '${potential_cluster}' ? (yes/no) : " response
    case "${response}" in
      yes|y|oui|o) context=${potential_cluster};;
      *) exit 1;;
    esac
  fi

  log info "Switching to context '${context}'"
  write_config CURRENT_CONTEXT "${context}"
  unset _K_CONFIG_CACHE
  _clear_cache
}

module_context () {
  if [ "$#" -ne "1" ]; then
    module_context_usage
    exit 1
  fi

  case "$1" in
    -l) module_context_list;;
    -lc) module_context_list_complete;;
    -w) module_context_where;;
    *) module_context_switch $@;;
  esac
}

module_namespace_usage () {
  cat << EOF
Usage:
  kn <NAMESPACE> # Set the current namespace
  kn -l  # List all available namespaces
  kn -lc # Raw list all available namespaces for bash completion
  kn -w  # Get the current namespace
EOF
}

_kubectl_get_namespace () {
  _kubectl_exec get namespace -o jsonpath="{.items[*].metadata.name}"
}

module_namespace_list () {
  log info "Available namespace in the cluster :"
  _kubectl_get_namespace | sed 's/\s*\([a-z0-9-]\+\)/  \1\n/g'
}

module_namespace_list_complete () {
  K_ENABLE_CACHE="true" _kubectl_get_namespace
}

module_namespace_where () {
  read_config CURRENT_NAMESPACE
}

module_namespace_switch () {
  namespace=$1

  log debug "namespace '${namespace}'"

  _kubectl_get_namespace | grep -E "(^|\s)${namespace}(\s|$)" > /dev/null
  if [ "$?" -ne "0" ]; then
    log error "Namespace '${namespace}' not found in the cluster"
    exit 1
  fi

  log info "Switching to namespace '${namespace}'"
  write_config CURRENT_NAMESPACE "${namespace}"
  unset _K_CONFIG_CACHE
  _clear_cache
}

module_namespace () {
  if [ "$#" -ne "1" ]; then
    module_namespace_usage
    exit 1
  fi

  case "$1" in
    -l) module_namespace_list;;
    -lc) module_namespace_list_complete;;
    -w) module_namespace_where;;
    *) module_namespace_switch $@;;
  esac
}

module_pod_usage () {
  cat << EOF
Usage:
  kp <POD_NAME> [ARGS]                     # Execute a command in the pod
  kp -c <CONTAINER_NAME> <POD_NAME> [ARGS] # Execute a command in the pod on a specific container
  kp -l                                    # List all pods
  kp -lc                                   # Raw list all pods for bash completion
  kp -d <POD_NAME>                         # Describe pod
EOF
}

_kubectl_get_pods () {
  _kubectl_exec get pods -o jsonpath="{.items[*].metadata.name}"
}

_kubectl_describe_pods () {
  _kubectl_exec describe pods "$1"
}

_kubectl_exec_pods () {
  _kubectl_exec exec -it $@
}

module_pod_list () {
  log info "Available pods in the namespaces :"
  _kubectl_get_pods | sed 's/\s*\([a-z0-9-]\+\)/  \1\n/g'
}

module_pod_list_complete () {
  K_ENABLE_CACHE="true" _kubectl_get_pods
}

module_pod_describe () {
  _kubectl_describe_pods "$1"
}

module_pod_exec () {
  pod_name="$1"
  shift
  if [ "$#" -eq "0" ]; then
    args="/bin/sh"
  else
    args=$@
  fi
  _kubectl_exec_pods $pod_name -- $args
}

module_pod_container_exec () {
  if [ "$#" -lt "3" ]; then
    module_pod_usage
    return 1
  fi
  container_name="$2"
  pod_name="$3"
  shift
  shift
  if [ "$#" -eq "1" ]; then
    args="/bin/sh"
  else
    args=$@
  fi
  _kubectl_exec_pods $pod_name -c $container_name -- $args
}

module_pod () {
  if [ "$#" -lt "1" ]; then
    module_pod_usage
    exit 1
  fi

  case "$1" in
    -l) module_pod_list;;
    -d) module_pod_describe "$2";;
    -lc) module_pod_list_complete;;
    -c) module_pod_container_exec $@;;
    *) module_pod_exec $@;;
  esac
}

module_undefined () {
  log error "Module '$1' is not defined."
  exit 1
}

check_init_k () {
  if ! [ -f "$(get_config_file)" ]; then
    init_k
  fi
}

init_k () {
  log debug "Initializing K..."
  mkdir -p ${K_CONFIGS}
  cat << EOF > "$(get_config_file)"
CURRENT_NAMESPACE="default"
CURRENT_CONTEXT="$(${KUBECTL_BIN} config current-context)"
EOF

  find ${K_CONFIGS} -mtime +7 -type f -delete
}

main () {
  check_init_k

  call_name=$(get_call_name $0)
  log debug "Call name '${call_name}'"

  if ! [ -z "${K_CLEAR_CACHE}" ]; then
    _full_clear_cache
  fi
  
  case $call_name in
    k) module_kubectl $@;;
    kc) module_context $@;;
    kn) module_namespace $@;;
    kp) module_pod $@;;
    *) module_undefined $call_name;;
  esac
}

main $@
