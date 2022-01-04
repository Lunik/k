#!/bin/bash

set -e
set -o xtrace

cat << EOF
####################
## Module context ##
####################
EOF

echo "[ctx] Check listing contexts"
kc -l | grep 'default'

echo "[ctx] Check listing contexts completion mode"
kc -lc | grep 'default'

echo "[ctx] Check showing current context"
kc -w | grep 'default'

echo "[ctx] Check switching contexts"
kc default
kc -w | grep 'default'


cat << EOF
######################
## Module namespace ##
######################
EOF

echo "[ns] Check listing namespaces"
kn -l | grep 'test-namespace'

echo "[ns] Check listing namespaces completion mode"
kn -lc | grep 'test-namespace'

echo "[ns] Check showing current namespace"
kn -w | grep 'default'

echo "[ns] Check listing pods in default namespace"
k get pods | grep 'test-simple'

echo "[ns] Check switching to 'test-namespace' namespace"
kn test-namespace
kn -w | grep 'test-namespace'

echo "[ns] Check listing pods in 'test-namespace' namespace"
k get pods | grep 'test-namespace'


cat << EOF
################
## Module pod ##
################
EOF

kn default

echo "[po] Check listing pods"
kp -l | grep 'test-simple'

echo "[pod] Check listing pods completion mode"
kp -lc | grep 'test-simple'

echo "[pod] Check pods in 'test-namespace' namespace"
kn test-namespace
kp -l | grep 'test-namespace'

kn default

echo "[pod] Check describe pod"
kp -d $(kp -lc | awk '{ print $1 }') | grep -E 'State:.*Running'

echo "[po] Check exec default pod"
kp $(kp -lc | awk '{ print $1 }') /bin/true

echo "[po] Check exec other pod"
kp -c other $(kp -lc | awk '{ print $1 }') /bin/true