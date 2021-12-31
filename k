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


###################
## Configuration ##
###################

KUBECTL_BIN="$(which env) kubectl"

K_BASE_DIR=~/.k
K_COMPLETION="${K_BASE_DIR}/bash-completion"

K_CONFIG_DIR="${K_BASE_DIR}/config.d"
K_CONFIG_TIMEOUT=7 # In days

K_CACHE_DIR=~/.cache/k
K_CACHE_TIMEOUT=1 # In minutes

K_EXEC_DEFAULT_COMMAND="/bin/sh"


###########
## Utils ##
###########

# Return the current directory of the k script
get_current_directory () {
  realpath $(dirname $0)
}

# Return the name of the alias used to call the binary
get_call_name () {
  basename $0
}

# Print logs with verbosity
# log <LEVEL> <MESSAGE>
#   LEVEL : info --> stdin
#         : warning, error --> stderr
#         : debug --> stderr only if environment var "K_DEBUG" is defined
log () {
  level=$1
  shift
  message=$@

  case "${level}" in
    info) echo "[INFO] ${message}";;
    warning) echo "[WARNING] ${message}" >&2;;
    error) echo "[ERROR] ${message}" >&2;;
    debug) if ! [ -z "${K_DEBUG}" ]; then echo "[DEBUG] ${message}" >&2; fi;;
  esac
}

# Get current instance
# instance is defined by environment var "KUBE_SHELL_INSTANCE"
#   the value is 'default' if not defined
get_instance () {
  if [ -z "${KUBE_SHELL_INSTANCE}" ]; then
    export KUBE_SHELL_INSTANCE=default
  fi
  echo "${KUBE_SHELL_INSTANCE}"
}

# Install software
install_soft () {
  current_dir=$(get_current_directory)

  log info "Copying bash completion script to : ${K_COMPLETION}"
  cat << EOF > "${K_COMPLETION}"
complete_k_ctx () {
  COMPREPLY=(\$(compgen -W "\$(${current_dir}/kc -lc)" "\${COMP_WORDS[1]}"))
}
complete_k_ns () {
  COMPREPLY=(\$(compgen -W "\$(${current_dir}/kn -lc)" "\${COMP_WORDS[1]}"))
}
complete_k_po () {
  COMPREPLY=(\$(compgen -W "\$(${current_dir}/kp -lc)" "\${COMP_WORDS[1]}"))
}

complete -F "complete_k_ctx" kc
complete -F "complete_k_ns" kn
complete -F "complete_k_po" kp
EOF

  log info "Creating '${current_dir}/kc', '${current_dir}/kn', '${current_dir}/kp' aliases for '${current_dir}/k'"
  if ! [ -h "${current_dir}/kc" ]; then
    ln -s "${current_dir}/k" "${current_dir}/kc"
  fi
  if ! [ -h "${current_dir}/kn" ]; then
    ln -s "${current_dir}/k" "${current_dir}/kn"
  fi
  if ! [ -h "${current_dir}/kp" ]; then
    ln -s "${current_dir}/k" "${current_dir}/kp"
  fi

  cat << EOF

Update your prompt by adding this string to your PS1 : "\$(${current_dir}/kc -w)/\$(${current_dir}/kn -w)"

Add those lines in your shell rc file (~/.bashrc, ~/.zshrc) :
  export KUBE_SHELL_INSTANCE="\$RANDOM-\$RANDOM"
  source "${K_COMPLETION}"
EOF
}

# Install software
uninstall_soft () {

  log info "Removing components directory : ${K_BASE_DIR}"
  rm -rf "${K_BASE_DIR}"
  log info "Removing cache directory : ${K_CACHE_DIR}"
  rm -rf "${K_CACHE_DIR}"

  current_dir=$(get_current_directory)

  log info "Removing '${current_dir}/kc', '${current_dir}/kn', '${current_dir}/kp' aliases"
  rm "${current_dir}/kc"
  rm "${current_dir}/kn"
  rm "${current_dir}/kp"

  cat << EOF

Update your prompt by removing this string to your PS1 : "\$(${current_dir}/kc -w)/\$(${current_dir}/kn -w)"

Remove those lines in your shell rc file (~/.bashrc, ~/.zshrc) :
  export KUBE_SHELL_INSTANCE="\$RANDOM-\$RANDOM"
  source "${K_COMPLETION}"
EOF

  log info "Removing '${current_dir}/k' script"
  rm "${current_dir}/k"

  log info "Follow the instructions at https://github.com/Lunik/k to reinstall the script"
}

#####################
## Cache managment ##
#####################

_K_CONFIG_CACHE=""

# Return the cache directory of the current instance
# The cache directory is created if it doesn't exists
get_cache_dir() {
  cache_dir="${K_CACHE_DIR}/$(get_instance)"

  if ! [ -f "${cache_dir}" ]; then
    mkdir -p "${cache_dir}"
  fi

  echo "${cache_dir}"
}

# Remove the cache from the current instance
_clear_cache () {
  cache_dir="$(get_cache_dir)"
  log debug "Clearing cache : ${cache_dir}"
  rm -rf "${cache_dir}"
}

# Remove all cache from k
_full_clear_cache () {
  log debug "Full clearing cache : ${K_CACHE_DIR}"
  rm -rf "${K_CACHE_DIR}"
}

# Clear all cache that have expired
_cache_timeout () {
  cache_dir="$(get_cache_dir)"
  find "${cache_dir}" -type f -mmin +"${K_CACHE_TIMEOUT}" -delete
}

# Retreive result from cache or execute the command
# Cache is only enabled if environment variable "K_CACHE_ENABLED" is defined
_cache_or_exec () {
  if [ -z "${K_CACHE_ENABLED}" ]; then
    $@
  else
    cache_dir="$(get_cache_dir)"
    _cache_timeout

    hash=$(echo "$@" | md5sum | cut -c -32)
    cache_file="${cache_dir}/${hash}"

    log debug "${cache_file} : $@"

    if [ -f "${cache_file}" ]; then
      log debug "Reading from cache : ${cache_file}"
      cat "${cache_file}"
    else
      log debug "Writing to cache : ${cache_file}"
      $@ | tee "${cache_file}"
    fi
  fi
}


######################
## Config managment ##
######################

# Return the config file of the current instance
# The config file directory is created if it doesn't exists
# The config file is created if it doesn't exists
# instance is defined by environment var "KUBE_SHELL_INSTANCE"
#   the value is 'default' if not defined
get_config_file() {
  if ! [ -d "${K_CONFIG_DIR}" ]; then
    log debug "Creating configs directory : ${K_CONFIG_DIR}"
    mkdir -p "${K_CONFIG_DIR}"
  fi

  config_file="${K_CONFIG_DIR}/$(get_instance)"

  if ! [ -f "${config_file}" ]; then
    log debug "Initializing configs file : ${config_file}"
    cat << EOF > "${config_file}"
CURRENT_NAMESPACE="default"
CURRENT_CONTEXT="$(${KUBECTL_BIN} config current-context)"
EOF
    log debug "Cleaning old config file"
    find "${K_CONFIG_DIR}" -mtime +"${K_CONFIG_TIMEOUT}" -type f -delete
  fi

  echo "${config_file}"
}

# Read a parameter from the config
# read_config <PARAM_NAME>
read_config () {
  param=$1

  if [ -z "${_K_CONFIG_CACHE}" ]; then
    _K_CONFIG_CACHE=$(cat "$(get_config_file)")
  fi

  echo "${_K_CONFIG_CACHE}" | grep "^${param}=" | sed -e 's/^.*="\(.*\)"$/\1/'
}

# Write a parameter to the config
# write_config <PARAM_NAME> <VALUE>
write_config () {
  param=$1
  shift
  value=$@

  sed -i .orig 's/^\('${param}'\)=.*$/\1="'${value}'"/' "$(get_config_file)"
  unset _K_CONFIG_CACHE
}


######################
## Kubectl commands ##
######################

# Execute kubectl command
# _kubectl_exec <COMMAND_PARAMETERS>
_kubectl_exec () {
  context="$(read_config CURRENT_CONTEXT)"
  namespace="$(read_config CURRENT_NAMESPACE)"

  log debug "${KUBECTL_BIN} --context="${context}" --namespace="${namespace}" $@"
  _cache_or_exec ${KUBECTL_BIN} --context="${context}" --namespace="${namespace}" $@
}

# Return the current context from the kubectl config
# _kubectl_get_context
_kubectl_get_context () {
  log debug "${KUBECTL_BIN} config get-contexts -o name"
  _cache_or_exec ${KUBECTL_BIN} config get-contexts -o name
}

# Return the current context from the kubectl config in wide format
# _kubectl_get_context_wide
_kubectl_get_context_wide () {
  log debug "${KUBECTL_BIN} config get-contexts"
  _cache_or_exec ${KUBECTL_BIN} config get-contexts
}

# Return all namespaces space separated
# Use the current context from the k config
# _kubectl_get_namespace
_kubectl_get_namespace () {
  _kubectl_exec get namespace -o jsonpath="{.items[*].metadata.name}"
}

# Return all namespaces in wide format
# Use the current context from the k config
# _kubectl_get_namespace
_kubectl_get_namespace_wide () {
  _kubectl_exec get namespace -o wide
}

# Return all pods space separated
# Use the current context and namespace from the k config
# _kubectl_get_pods
_kubectl_get_pods () {
  _kubectl_exec get pods -o jsonpath="{.items[*].metadata.name}"
}

# Return all pods in wide format
# Use the current context and namespace from the k config
# _kubectl_get_pods_wide
_kubectl_get_pods_wide () {
  _kubectl_exec get pods -o wide
}

# Return the description of a pod
# Use the current context and namespace from the k config
# _kubectl_describe_pods <POD_NAME>
_kubectl_describe_pods () {
  pod_name=$1
  _kubectl_exec describe pods "${pod_name}"
}

# Execute a command in a pod
# Use the current context and namespace from the k config
# _kubectl_exec_pods <POD_NAME> <COMMAND>
# _kubectl_exec_pods <POD_NAME> -c <CONTAINER_NAME> <COMMAND>
_kubectl_exec_pods () {
  _kubectl_exec exec -it $@
}


####################
## Module kubectl ##
####################

# Called module when the $0 is 'k'
# Execute basic kubectl commands
# Examples :
#   k get pods
#   k create deployment demo --image=nginx:latest
# Extra options :
#   --install     # Install k software (see "install_soft" function)
module_kubectl () {
  if [ "$1" = "--install" ]; then
    install_soft
    exit 0
  elif [ "$1" = "--uninstall" ]; then
    uninstall_soft
    exit 0
  elif [ "$1" = "--clear-cache" ]; then
    _full_clear_cache
    exit 0
  fi

  _kubectl_exec $@
}


####################
## Module context ##
####################

# Called module when the $0 is 'kc'
# Execute kubectl context related commands

# Print module usage
module_context_usage () {
  cat << EOF
Usage:
  kc <CONTEXT>  # Set the current context
  kc -l         # List all available contexts
  kc -lc        # Raw list all available contexts for complete
  kc -w         # Get the current context
EOF
}

# Called by "kc -l"
# List all available contexts
module_context_list () {
  _kubectl_get_context_wide
}

# Called by "kc -lc"
# List all available contexts in bash completion format
# Should not be used for anything else
module_context_list_complete () {
  K_CACHE_ENABLED="true" _kubectl_get_context
}

# Called by "kc -w"
# Return the current context used by k
module_context_where () {
  read_config CURRENT_CONTEXT
}

# Called by 'kc <CONTEXT>'
# Change current context in k (/!\ not in ~/.kube/config)
# User can change context with the full or partial context name
#   k will try to find a matching context with the provided partial information
module_context_switch () {
  context=$1

  log debug "Searching for context matching : ${context}"

  # Check if the requested context exists
  _kubectl_get_context | grep -E "(^|\s)${context}(\s|$)" > /dev/null
  # If the requested context doesn't exists
  if [ "$?" -ne "0" ]; then
    log error "Context not found : ${context}"

    # Searching for a context that could match requested context
    potential_cluster=$(_kubectl_get_context | grep -E "${context}" | head -1)
    # If no potential clusters are found
    if [ -z "${potential_cluster}" ]; then
      exit 1
    fi

    # Ask the user if the potential cluster is the requested context
    read -p "Did you mean '${potential_cluster}' ? (yes/no) : " response
    case "${response}" in
      yes|y|oui|o) context="${potential_cluster}";;
      *) exit 1;;
    esac
  fi

  log info "Switching to context : ${context}"
  write_config CURRENT_CONTEXT "${context}"
  # Clear all cache of the instance to prevent invalid values
  unset _K_CONFIG_CACHE
  _clear_cache
}

# Main function for the 'kc' call name
module_context () {
  if [ "$#" -ne "1" ]; then
    module_context_usage
    exit 1
  fi

  case "$1" in
    -l) module_context_list;;
    -lc) module_context_list_complete;;
    -w) module_context_where;;
    *) module_context_switch "$1";;
  esac
}


######################
## Module namespace ##
######################

# Called module when the $0 is 'kn'
# Execute kubectl namespace related commands

# Print module usage
module_namespace_usage () {
  cat << EOF
Usage:
  kn <NAMESPACE> # Set the current namespace
  kn -l          # List all available namespaces
  kn -lc         # Raw list all available namespaces for bash completion
  kn -w          # Get the current namespace
EOF
}

# Called by "kn -l"
# List all available namespaces
module_namespace_list () {
  _kubectl_get_namespace_wide
}

# Called by "kn -lc"
# List all available namespaces in bash completion format
# Should not be used for anything else
module_namespace_list_complete () {
  K_CACHE_ENABLED="true" _kubectl_get_namespace
}

# Called by "kn -w"
# Return the current namespace used by k
module_namespace_where () {
  read_config CURRENT_NAMESPACE
}

# Called by 'kn <NAMESPACE>'
# Change current namespace in k
module_namespace_switch () {
  namespace=$1

  log debug "Searching for namespace : ${namespace}"

  # Check if the requested context exists
  _kubectl_get_namespace | grep -E "(^|\s)${namespace}(\s|$)" > /dev/null
  if [ "$?" -ne "0" ]; then
    log error "Namespace not found in the cluster : ${namespace}"
    exit 1
  fi

  log info "Switching to namespace : ${namespace}"
  write_config CURRENT_NAMESPACE "${namespace}"
  # Clear all cache of the instance to prevent invalid values
  unset _K_CONFIG_CACHE
  _clear_cache
}

# Main function for the 'kn' call name
module_namespace () {
  if [ "$#" -ne "1" ]; then
    module_namespace_usage
    exit 1
  fi

  case "$1" in
    -l) module_namespace_list;;
    -lc) module_namespace_list_complete;;
    -w) module_namespace_where;;
    *) module_namespace_switch "$1";;
  esac
}


################
## Module pod ##
################

# Called module when the $0 is 'kp'
# Execute kubectl pod related commands

# Print module usage
module_pod_usage () {
  cat << EOF
Usage:
  kp <POD_NAME> [ARGS..]                     # Execute a command in the pod
  kp -c <CONTAINER_NAME> <POD_NAME> [ARGS..] # Execute a command in the pod on a specific container
  kp -l                                      # List all pods
  kp -lc                                     # Raw list all pods for bash completion
  kp -d <POD_NAME>                           # Describe pod
EOF
}

# Called by "kp -l"
# List all available pods in the namespace
module_pod_list () {
  _kubectl_get_pods_wide
}

# Called by "kp -lc"
# List all available pods in the namespace in bash completion format
# Should not be used for anything else
module_pod_list_complete () {
  K_CACHE_ENABLED="true" _kubectl_get_pods
}

# Called by "kp -d <POD_NAME>"
# Return the description of the pod
module_pod_describe () {
  pod_name=$1
  _kubectl_describe_pods "${pod_name}"
}

# Called by "kp <POD_NAME> [ARGS..]"
# Execute a command inside of the default container of a pod
module_pod_exec () {
  pod_name=$1
  shift

  # Set default pod command if not provided
  if [ "$#" -eq "0" ]; then
    args="${K_EXEC_DEFAULT_COMMAND}"
  else
    args=$@
  fi

  _kubectl_exec_pods "${pod_name}" -- ${args}
}

# Called by "kp -c <CONTAINER_NAME> <POD_NAME> [ARGS..]"
# Execute a command inside of a specific container of a pod
module_pod_container_exec () {
  container_name="$2"
  pod_name="$3"
  shift
  shift
  shift

  # Set default pod command if not provided
  if [ "$#" -eq "0" ]; then
    args="${K_EXEC_DEFAULT_COMMAND}"
  else
    args=$@
  fi

  _kubectl_exec_pods "${pod_name}" -c "${container_name}" -- ${args}
}

# Main function for the 'kp' call name
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

######################
## Module undefined ##
######################

# Called module when the $0 is not supported

module_undefined () {
  call_name=$1
  log error "Module is not defined : ${call_name}"
  exit 1
}

##########
## Main ##
##########

# Main function always called

main () {
  call_name="$(get_call_name)"
  log debug "Call name : ${call_name}"
  
  case "${call_name}" in
    k) module_kubectl $@;;
    kc) module_context $@;;
    kn) module_namespace $@;;
    kp) module_pod $@;;
    *) module_undefined "${call_name}";;
  esac
}

main $@
