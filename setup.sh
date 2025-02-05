#!/bin/bash
set -x

wget https://download.eclipse.org/jakartaee/batch/2.1/jakarta.batch.official.tck-2.1.1.zip
unzip jakarta.batch.official.tck-2.1.1.zip

git clone git@github.com:jberet/jberet-tck-porting.git

pushd jberet-tck-porting
mvn install -DskipTests
popd

git clone git@github.com:wildfly/wildfly.git

pushd wildfly
mvn install -DskipTests
popd

git clone git@github.com:jberet/jsr352.git

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

pushd $BATCH_TCK_DIR/runners/se-classpath
mvn install -Dversion.org.jberet.jberet-core=${jberet_ver}
popd
