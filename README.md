# k a Kubectl alias

k is a lightweight bash native script to improve productivity when using `kubectl` binary.

Features :
- Short commands
- Lightweight script
- Easy to install and uninstall
- Aliases for context management
- Aliases for namespace managment
- Aliases for pod managment
- Command caching
- Bash completion
- Only require `bash`

## Install

Download the script :
```sh
wget https://raw.githubusercontent.com/Lunik/k/master/k -O /usr/local/bin/k
```

Change the permissions on the script to make it executable
```sh
chmod u+x /usr/local/bin/k
```

Install the script and all it's components and follow the instructions
```sh
k --install
```

## Usage

### k

Execute basic kubectl commands :
```shell
k get pods
k <action> [options] <type>/<object> # Standard Kubectl options
```

### kc

Execute kubectl context related commands :
```shell
kc <CONTEXT>  # Set the current context
kc -l         # List all available contexts
kc -w         # Get the current context
```

### kn

Execute kubectl namespace related commands :
```shell
kn <NAMESPACE> # Set the current namespace
kn -l          # List all available namespaces
kn -w          # Get the current namespace
```

### kp

Execute kubectl pod related commands :
```shell
kp <POD_NAME> [ARGS..]                     # Execute a command in the pod
kp -c <CONTAINER_NAME> <POD_NAME> [ARGS..] # Execute a command in the pod on a specific container
kp -l                                      # List all pods
kp -d <POD_NAME>                           # Describe pod
```

## Config

The script can be configured by editing the `Configuration` section in the `k` script.

| Parameter | Default value | Description |
|:–|:-|:-|
| `KUBECTL_BIN`  | `$(which env) kubectl`          | Location of the `kubectl` binary   |
| `K_BASE_DIR`   | `~/.k`                          | Base directory for `k` components  |
| `K_COMPLETION` | `${K_BASE_DIR}/bash-completion` | Path of the bash completion script |
||||
| `K_CONFIG_DIR`     | `${K_BASE_DIR}/config.d` | Base directory for `k` instance configs                 |
| `K_CONFIG_TIMEOUT` | `7`                      | Timeout value in days for removing old instance configs |
||||
| `K_CACHE_DIR`     | `~/.cache/k` | Base directory for `k` cache                |
| `K_CACHE_TIMEOUT` | `1`          | Timeout value in minutes for clearing cache |
||||
| `K_EXEC_DEFAULT_COMMAND` | `/bin/sh` | Default command executed in pods if none is provided |

## Uninstall

Uninstall the script and all it's components and follow the instructions
```sh
k --uninstall
```

## Troubleshout

### Cache

All cache files are stored in  `${K_CACHE_DIR}`.
Cached commands are refreshed every `${K_CACHE_TIMEOUT}` minutes or when switching `context` or `namespace`

To force all cache to refresh (eq. `rm -rf ${K_CACHE_DIR}`) :
```shell
k --clear-cache
```

### Debug

Enable debug mode :
```shell
export K_DEBUG=1
```
