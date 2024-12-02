#!/bin/bash

set -x

# todo: extract the following into a separate file.
# and run with different profiles.

# Using the provisioned WildFly instead.
#WFLY_VER=$(curl --silent -qI https://github.com/wildfly/wildfly/releases/latest | grep '^location.*' | tr -d '\r')
#WFLY_VER=${WFLY_VER##*/}
#
#wget https://github.com/wildfly/wildfly/releases/download/${WFLY_VER}/wildfly-${WFLY_VER}.zip
#unzip wildfly-${WFLY_VER}.zip
#
#export JBOSS_HOME=$(pwd)/wildfly-${WFLY_VER}
echo "start to run wildfly-ci test"
pwd

if [ "${USE_PROFILE}" != "" ]; then
  mvn clean install \
    "-Dversion.org.wildfly=${WFLY_VER}" \
    '-Dversion.wildfly-maven-plugin=5.0.0.Final' \
    "-Dversion.jberet=${JBERET_VER}" \
    "-P${USE_PROFILE}"
else
  mvn clean install \
      "-Dversion.org.wildfly=${WFLY_VER}" \
      '-Dversion.wildfly-maven-plugin=5.0.0.Final' \
      "-Dversion.jberet=${JBERET_VER}"
fi

#mvn clean install \
#  "-Dversion.org.wildfly=${WFLY_VER}" \
#  '-Dversion.wildfly-maven-plugin=5.0.0.Final' \
#  "-Dversion.jberet=${jberet_ver}" \
#  '-Pprovision-preview'

export JBOSS_HOME=$(pwd)/target/wildfly

cp $JBERET_PORTING_DIR/target/jberet-tck-porting.jar $JBOSS_HOME/standalone/deployments/

# Run integration tests

# start WildFly server
pushd $JBOSS_HOME/bin
./standalone.sh &

sleep 10
NUM=0
while true
do
NUM=$[$NUM + 1]
if (("$NUM" > "6")); then
    echo "Application server failed to start up!"
    exit 1
fi

if ./jboss-cli.sh --connect command=':read-attribute(name=server-state)' | grep running; then
    echo "server is running"
    break
fi
    echo "server is not yet running"
    sleep 10
done
popd

pushd $BATCH_TCK_DIR/jakarta.batch.arquillian.exec
mvn install
echo "platform-arquillian running result: $?"
popd

# stop WildFly server
$JBOSS_HOME/bin/jboss-cli.sh --connect --commands="undeploy jberet-tck-porting.jar, shutdown"