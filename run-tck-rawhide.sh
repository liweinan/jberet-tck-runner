#!/bin/bash
set -x

err_report() {
  echo "Error on line $1"
  exit 1
}

trap 'err_report $LINENO' ERR

# clone the upstream `batch-tck` and build it.
git clone https://github.com/jakartaee/batch-tck.git
pushd batch-tck
git checkout master
# https://github.com/jakartaee/batch-tck/issues/77
mvn clean install -DskipTests -Dxml.skip -Decho.skip
tck_ver=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
popd

export BATCH_TCK_DIR=$(pwd)/batch-tck

# Use the customized branch to override the `batch-tck` version.
git clone https://github.com/jberet/jberet-tck-porting.git

# build for jdk 21 testings
pushd jberet-tck-porting
git checkout main
mvn install -DskipTests
echo "build jberet-tck-porting result: $?"
popd

export JBERET_PORTING_DIR=$(pwd)/jberet-tck-porting

git clone https://github.com/jberet/jsr352.git

pushd jsr352
mvn install -DskipTests
echo "build jsr352 result: $?"
jberet_ver=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
popd

cp $JBERET_PORTING_DIR/src/main/resources/runners/sigtest/pom-rawhide.xml $BATCH_TCK_DIR/com.ibm.jbatch.tck.sigtest.exec/pom.xml
cp $JBERET_PORTING_DIR/src/main/resources/runners/se-classpath/pom-rawhide.xml $BATCH_TCK_DIR/com.ibm.jbatch.tck.exec/pom.xml
cp $JBERET_PORTING_DIR/src/main/resources/runners/platform-arquillian/pom-rawhide.xml $BATCH_TCK_DIR/jakarta.batch.arquillian.exec/pom.xml
cp $JBERET_PORTING_DIR/src/main/resources/runners/platform-arquillian/src/test/resources/arquillian.xml $BATCH_TCK_DIR/jakarta.batch.arquillian.exec/src/test/resources/arquillian.xml

# Run sigtest
pushd $BATCH_TCK_DIR/com.ibm.jbatch.tck.sigtest.exec
mvn install -Dversion.org.jberet.jberet-core=${jberet_ver}
echo "run sigtest result: $?"
popd

# Run SE tests
pushd $BATCH_TCK_DIR/com.ibm.jbatch.tck.exec
mvn install -Dversion.org.jberet.jberet-core=${jberet_ver}
echo "se-classpath running result: $?"
popd


WFLY_VER=$(curl --silent -qI https://github.com/wildfly/wildfly/releases/latest | grep '^location.*' | tr -d '\r')
WFLY_VER=${WFLY_VER##*/}

wget https://github.com/wildfly/wildfly/releases/download/${WFLY_VER}/wildfly-${WFLY_VER}.zip
unzip wildfly-${WFLY_VER}.zip

export JBOSS_HOME=$(pwd)/wildfly-${WFLY_VER}

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