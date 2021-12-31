# k a Kubectl alias

## Install
Se mettre dans un dossier de binaire exporté via `$PATH` et déposer le script ci-dessus dans un fichier nommé `k`
Changer les permissions :
```sh
chmod u+x k
```

```sh
k --install
```

Rajouter la ligne suivante dans le `~/.bashrc` (ou autre en fonction du shell) pour avoir des configs différentes entre chaque shell : 
```shell
export KUBE_SHELL_INSTANCE="$RANDOM-$RANDOM"
```

## Usage

### k

```shell
k get pods
k <action> [options] <type>/<object> # Standard Kubectl options
```

### kc

```shell
kc <CONTEXT> # Set the current context
kc -l        # List all available contexts
kc -w        # Get the current context  
```

### kn

```shell
kn <NAMESPACE> # Set the current namespace
kn -l          # List all available namespaces
kn -w          # Get the current namespace   
```

### kp

```shell
kp <POD_NAME> [ARGS]                     # Execute a command in the pod
kp -c <CONTAINER_NAME> <POD_NAME> [ARGS] # Execute a command in the pod on a specific container
kp -l                                    # List all pods
kp -d <POD_NAME>                         # Describe pod
```

## Config

Toutes les configurations sont stockées dans `~/.k/config.d/`.
Chaque fichier au format `[0-9]+-[0-9]+` contient la configuration courante d'un shell. L'ID du shell actuellement en cours d'utilisation se trouve dans la variable d'environnement `KUBE_SHELL_INSTANCE`

## Troubleshout

### Debug

```shell
export K_DEBUG="true"
```

### Cache

Tous les fichiers de cache sont stockés dans `~/.cache/k` par default.
Les commandes mises en cache sont rafraichie toutes les 30s ou lors du changement de `context` ou de `namespace`

Forcer la suppression de tout le cache (eq. `rm -rf ~/.cache/k`) :
```shell
K_CLEAR_CACHE="true" k
```
