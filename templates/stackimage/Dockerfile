FROM {{.BASE_OS_IMAGE}} AS maven

RUN yum upgrade --disableplugin=subscription-manager -y \
   && yum clean --disableplugin=subscription-manager packages \
   && echo 'Finished installing dependencies'

RUN  useradd --uid 1001 --gid 0 --shell /bin/bash --create-home java_user

# Dependency install
RUN yum install --disableplugin=subscription-manager -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
   && yum install --disableplugin=subscription-manager -y unzip curl ca-certificates wget xmlstarlet procps

# Maven install
ARG MAVEN_VERSION=3.6.3
ARG SHA=c35a1803a6e70a126e80b2b3ae33eed961f83ed74d18fcd16909b2d44d7dada3203f1ffe726c17ef8dcca2dcaa9fca676987befeadc9b9f759967a8cb77181c0
ARG BASE_URL=https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/

RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA}  /tmp/apache-maven.tar.gz" | sha512sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

FROM maven AS builder

ENV OPENJ9_JAVA_OPTIONS="-Xshareclasses:name=liberty,nonfatal,cacheDir=/output/.classCache/"

RUN umask -S u=rwx,g=rwx,o=rx; mkdir -p /mvn/repository \
  && chown -R java_user /mvn \
  && chmod 775 /mvn \
  && mkdir -p /stacks/java-openliberty/priming-app \
  && mkdir -p /stacks/java-openliberty/config \
  && chown -R java_user /stacks \
  && mkdir -p /output \
  && chown -R java_user /output \
  && chmod 775 /output

COPY ./LICENSE /licenses/

USER java_user

ADD ./config /stacks/java-openliberty/config
ADD ./priming-app/src /stacks/java-openliberty/priming-app/src
COPY --chown=1001:0 ./priming-app/pom.xml /stacks/java-openliberty/priming-app/

WORKDIR /stacks/java-openliberty/priming-app

ENV LIBERTY_RUNTIME_VERSION={{.LIBERTY_RUNTIME_VERSION}}
ENV LIBERTY_RUNTIME_ARTIFACTID={{.LIBERTY_RUNTIME_ARTIFACTID}}
ENV LIBERTY_RUNTIME_GROUPID={{.LIBERTY_RUNTIME_GROUPID}}

RUN umask -S u=rwx,g=rwx,o=rx; mvn -B -e -DserverName=tmp -Dmaven.repo.local=/mvn/repository -Dliberty.runtime.version=${LIBERTY_RUNTIME_VERSION} -Dliberty.runtime.artifactid=${LIBERTY_RUNTIME_ARTIFACTID} -Dliberty.runtime.groupid=${LIBERTY_RUNTIME_GROUPID} -DskipITs=true install

# A hack maybe but there's quite a few dependencies that only are detected when dev mode is executed, due to use of mojo executor, etc.
#
# If you see this then you got enough cached, but if you don't, you need to build with --no-cache next time or you won't even redo this step
#
# [INFO]
# [INFO] -------------------------------------------------------
# [INFO]  T E S T S
# [INFO] -------------------------------------------------------
# [INFO] Running dev.odo.starter.it.EndpointIT
# [INFO] Tests run: 1, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 0.134 s - in dev.odo.starter.it.EndpointIT
# [INFO]
# [INFO] Results:
# [INFO]
# [INFO] Tests run: 1, Failures: 0, Errors: 0, Skipped: 0
# [INFO]
# [INFO] Failsafe report directory: /stacks/java-openliberty/priming-app/target/test-reports/it
# [INFO] Integration tests finished.
#
# Done sleeping
RUN nohup bash -c "umask -S u=rwx,g=rwx,o=rx; mvn -B -e -DserverName=tmp -Dmaven.repo.local=/mvn/repository -Dliberty.runtime.version=${LIBERTY_RUNTIME_VERSION} -Dliberty.runtime.artifactid=${LIBERTY_RUNTIME_ARTIFACTID} -Dliberty.runtime.groupid=${LIBERTY_RUNTIME_GROUPID} liberty:dev -DhotTests=true &" \
 && sleep 600 \
 && echo  && echo "Done sleeping" && echo

# Cache dependencies associated with the previous major version of the microprofile APIs and OL microprofile features.
RUN umask -S u=rwx,g=rwx,o=rx; mvn -B -e -Dmaven.repo.local=/mvn/repository -Dtransitive=true -Dartifact=io.openliberty.features:microProfile-{{.LIBERTY_MP_FEATURE_PREV_VERSION}}:${LIBERTY_RUNTIME_VERSION}:pom -DrepoUrl=https://repo1.maven.org/maven2/ org.apache.maven.plugins:maven-dependency-plugin:3.1.2:get \
    && umask -S u=rwx,g=rwx,o=rx; mvn -B -e -Dmaven.repo.local=/mvn/repository -Dtransitive=true -Dartifact=org.eclipse.microprofile:microprofile:{{.ECLIPSE_MP_API_PREV_VERSION}}:pom -DrepoUrl=https://repo1.maven.org/maven2/ org.apache.maven.plugins:maven-dependency-plugin:3.1.2:get

# Delete the server, users will create their own server
RUN rm -rf /stacks/java-openliberty/priming-app/target/liberty/wlp/usr/servers/tmp
# Don't let the sample appear in the user repo
RUN rm -rf /mvn/repository/dev/odo/java-openliberty/samples/priming-app

# Remove openliberty-runtime zip from Maven repo - just taking up space
RUN rm -rf /mvn/repository/io/openliberty/openliberty-runtime

FROM maven

ENV WLP_INSTALL_PATH={{.WLP_INSTALL_PATH}}

ENV OPENJ9_JAVA_OPTIONS="-Xshareclasses:name=liberty,nonfatal,cacheDir=/output/.classCache/"

RUN mkdir -p /output \
  && chown -R java_user /output \
  && chmod 775 /output \
  && mkdir -p $WLP_INSTALL_PATH \
  && chown -R java_user $WLP_INSTALL_PATH \
  && chmod 775 $WLP_INSTALL_PATH \
  && mkdir -p /work/outer-loop-app \
  && chown -R java_user /work \
  && chmod -R 775 /work \
  && mkdir -p /stack/ol/config/configDropins/defaults \
  && chmod -R 775 /stack/ol/config/configDropins/defaults

# Point to local /mvn/repository within container
COPY --chown=1001:0 ./mvn-stack-settings.xml /usr/share/maven/conf/settings.xml
COPY --chown=1001:0 --from=builder /mvn /mvn

COPY --chown=1001:0 --from=builder /stacks/java-openliberty/config/configDropins/defaults/ /stack/ol/config/configDropins/defaults/


COPY --chown=1001:0 --from=builder /stacks/java-openliberty/priming-app/target/liberty/wlp $WLP_INSTALL_PATH
COPY --chown=1001:0 ./LICENSE /licenses/

USER java_user
CMD /bin/bash
