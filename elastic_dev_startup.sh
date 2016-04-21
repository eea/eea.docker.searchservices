#!/bin/bash

# Build the rdf river
apt-get update
apt-get install maven -y
cp -R /river_src /tmp/river_src
cd /tmp/river_src
echo "Installing openjdk-7"
apt-get install openjdk-7-jdk openjdk-7-doc openjdk-7-jre-lib -y
export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/jre
echo "Building eea-rdf-river"
mvn clean install
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre
echo "Installing eea-rdf-river plugin"
PLUGIN=$(find /tmp/river_src -name "eea-rdf-river-plugin-*.zip")
unzip -o $PLUGIN -d /usr/share/elasticsearch/plugins/eea-rdf-river || true
unset RIVER_VERSION

set -e

# Add elasticsearch as command if needed
if [ "${1:0:1}" = '-' ]; then
        set -- elasticsearch "$@"
fi

# Drop root privileges if we are running elasticsearch
# allow the container to be started with `--user`
if [ "$1" = 'elasticsearch' -a "$(id -u)" = '0' ]; then
        # Change the ownership of /usr/share/elasticsearch/data to elasticsearch        chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/data

        set -- gosu elasticsearch "$@"
        #exec gosu elasticsearch "$BASH_SOURCE" "$@"
fi

# As argument is not related to elasticsearch,
# then assume that user wants to run his own process,
# for example a `bash` shell to explore this image
exec "$@"
