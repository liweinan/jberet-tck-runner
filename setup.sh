#!/bin/bash
set -x

wget https://download.eclipse.org/jakartaee/batch/2.1/jakarta.batch.official.tck-2.1.1.zip
unzip jakarta.batch.official.tck-2.1.1.zip

git clone https://github.com/jberet/jberet-tck-porting.git

pushd jberet-tck-porting
mvn install -DskipTests
popd

git clone https://github.com/wildfly/wildfly.git

pushd wildfly
mvn install -DskipTests
popd

git clone https://github.com/jberet/jsr352.git

pushd jsr352
mvn install -DskipTests
jberet_ver=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
popd

export BATCH_TCK_DIR=$(pwd)/jakarta.batch.official.tck-2.1.1
export JBERET_PORTING_DIR=$(pwd)/jberet-tck-porting

pushd wildfly
wildfly_ver=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
popd

export JBOSS_HOME=$(pwd)/wildfly/dist/target/wildfly-${wildfly_ver}

cp $JBERET_PORTING_DIR/target/jberet-tck-porting.jar $JBOSS_HOME/standalone/deployments/

cp $JBERET_PORTING_DIR/src/main/resources/runners/sigtest/pom.xml $BATCH_TCK_DIR/runners/sigtest/pom.xml
cp $JBERET_PORTING_DIR/src/main/resources/runners/se-classpath/pom.xml $BATCH_TCK_DIR/runners/se-classpath/pom.xml
cp $JBERET_PORTING_DIR/src/main/resources/runners/platform-arquillian/pom.xml $BATCH_TCK_DIR/runners/platform-arquillian/pom.xml
cp $JBERET_PORTING_DIR/src/main/resources/runners/platform-arquillian/src/test/resources/arquillian.xml $BATCH_TCK_DIR/runners/platform-arquillian/src/test/resources/arquillian.xml


# Run SE tests
pushd $BATCH_TCK_DIR/runners/se-classpath
mvn install -Dversion.org.jberet.jberet-core=${jberet_ver}
popd

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
#    echo "Application server failed to start up! Will run tests anyway"
#    netstat -an
    echo "Application server failed to start up!"
    exit 1
#    echo "try to run tests anyway even though server is not running"
#    break
fi

if ./jboss-cli.sh --connect command=':read-attribute(name=server-state)' | grep running; then
    echo "server is running"
    break
fi
    echo "server is not yet running"
    sleep 10
done
popd

pushd $BATCH_TCK_DIR/runners/platform-arquillian
mvn install
popd

# stop WildFly server
$JBOSS_HOME/bin/jboss-cli.sh --connect --commands="undeploy jberet-tck-porting.jar, shutdown"