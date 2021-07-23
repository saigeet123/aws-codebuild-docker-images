FROM amazonlinux:2 AS core

# Install git, SSH, and other utilities
RUN set -ex \
    && yum install -y openssh-clients \
    && mkdir ~/.ssh \
    && touch ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa -H github.com >> ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa -H bitbucket.org >> ~/.ssh/known_hosts \
    && chmod 600 ~/.ssh/known_hosts \
    && amazon-linux-extras install epel -y \
    && rpm --import https://download.mono-project.com/repo/xamarin.gpg \
    && curl https://download.mono-project.com/repo/centos7-stable.repo | tee /etc/yum.repos.d/mono-centos7-stable.repo \
    && amazon-linux-extras enable corretto8 \
    && yum groupinstall -y "Development tools" \
    && yum install -y \
           GeoIP-devel ImageMagick asciidoc bzip2-devel bzr bzrtools cvs cvsps \
           docbook-dtds docbook-style-xsl dpkg-dev e2fsprogs expat-devel expect fakeroot \
           glib2-devel groff gzip icu iptables jq krb5-server libargon2-devel \
           libcurl-devel libdb-devel libedit-devel libevent-devel libffi-devel \
           libicu-devel libjpeg-devel libpng-devel libserf libsqlite3x-devel \
           libtidy-devel libunwind libwebp-devel libxml2-devel libxslt libxslt-devel \
           libyaml-devel libzip-devel mariadb-devel mercurial mlocate mono-devel \
           ncurses-devel oniguruma-devel openssl openssl-devel perl-DBD-SQLite \
           perl-DBI perl-HTTP-Date perl-IO-Pty-Easy perl-TimeDate perl-YAML-LibYAML \
           postgresql-devel procps-ng python-configobj readline-devel rsync sgml-common \
           subversion-perl tar tcl tk vim wget which xfsprogs xmlto xorg-x11-server-Xvfb xz-devel \
    && rm /etc/yum.repos.d/mono-centos7-stable.repo

  
RUN useradd codebuild-user

#=======================End of layer: core  =================

FROM core AS tools

# Install Git
RUN set -ex \
   && GIT_VERSION=2.27.0 \
   && GIT_TAR_FILE=git-$GIT_VERSION.tar.gz \
   && GIT_SRC=https://github.com/git/git/archive/v${GIT_VERSION}.tar.gz  \
   && curl -L -o $GIT_TAR_FILE $GIT_SRC \
   && tar zxvf $GIT_TAR_FILE \
   && cd git-$GIT_VERSION \
   && make -j4 prefix=/usr \
   && make install prefix=/usr \
   && cd .. ; rm -rf git-$GIT_VERSION \
   && rm -rf $GIT_TAR_FILE /tmp/*

# Install stunnel
RUN set -ex \
   && STUNNEL_VERSION=5.56 \
   && STUNNEL_TAR=stunnel-$STUNNEL_VERSION.tar.gz \
   && STUNNEL_SHA256="7384bfb356b9a89ddfee70b5ca494d187605bb516b4fff597e167f97e2236b22" \
   && curl -o $STUNNEL_TAR https://www.usenix.org.uk/mirrors/stunnel/archive/5.x/$STUNNEL_TAR \
   && echo "$STUNNEL_SHA256 $STUNNEL_TAR" | sha256sum -c - \
   && tar xvfz $STUNNEL_TAR \
   && cd stunnel-$STUNNEL_VERSION \
   && ./configure \
   && make -j4 \
   && make install \
   && openssl genrsa -out key.pem 2048 \
   && openssl req -new -x509 -key key.pem -out cert.pem -days 1095 -subj "/C=US/ST=Washington/L=Seattle/O=Amazon/OU=Codebuild/CN=codebuild.amazon.com" \
   && cat key.pem cert.pem >> /usr/local/etc/stunnel/stunnel.pem \
   && cd .. ; rm -rf stunnel-${STUNNEL_VERSION}*



##python
RUN curl https://pyenv.run | bash
ENV PATH="/root/.pyenv/shims:/root/.pyenv/bin:$PATH"


#=======================End of layer: tools  =================

FROM tools AS runtimes_1

#****************      JAVA     ****************************************************
COPY tools/android-accept-licenses.sh /opt/tools/android-accept-licenses.sh

ENV JAVA_11_HOME="/usr/lib/jvm/java-11-amazon-corretto.x86_64" \
    JDK_11_HOME="/usr/lib/jvm/java-11-amazon-corretto.x86_64" \
    JRE_11_HOME="/usr/lib/jvm/java-11-amazon-corretto.x86_64" \
    JAVA_8_HOME="/usr/lib/jvm/java-1.8.0-amazon-corretto.x86_64" \
    JDK_8_HOME="/usr/lib/jvm/java-1.8.0-amazon-corretto.x86_64" \
    JRE_8_HOME="/usr/lib/jvm/java-1.8.0-amazon-corretto.x86_64/jre" \
    ANT_VERSION=1.10.8 \
    MAVEN_HOME="/opt/maven" \
    MAVEN_VERSION=3.6.3 \
    INSTALLED_GRADLE_VERSIONS="4.10.3 5.6.4" \
    GRADLE_VERSION=5.6.4 \
    SBT_VERSION=1.2.8 \
    ANDROID_HOME="/usr/local/android-sdk-linux" \
    GRADLE_PATH="$SRC_DIR/gradle" \
    ANDROID_SDK_MANAGER_VER="4333796" \
    ANDROID_SDK_BUILD_TOOLS="build-tools;29.0.3" \
    ANDROID_SDK_PLATFORM_TOOLS="platforms;android-29" \
    ANDROID_SDK_BUILD_TOOLS_28="build-tools;28.0.3" \
    ANDROID_SDK_PLATFORM_TOOLS_28="platforms;android-28" \
    ANDROID_SDK_EXTRAS="extras;android;m2repository extras;google;m2repository extras;google;google_play_services" \
    ANT_DOWNLOAD_SHA512="4d80dc6ba23eeec7769085ddb00261b7480b596b56c6e69aa221391acbfb7338eb5855179c88222c8021095ef1f64f43caf2b4f90e8305d7c3128026d4258d06" \
    MAVEN_DOWNLOAD_SHA512="c35a1803a6e70a126e80b2b3ae33eed961f83ed74d18fcd16909b2d44d7dada3203f1ffe726c17ef8dcca2dcaa9fca676987befeadc9b9f759967a8cb77181c0" \
    GRADLE_DOWNLOADS_SHA256="abc10bcedb58806e8654210f96031db541bcd2d6fc3161e81cb0572d6a15e821 5.6.4\n336b6898b491f6334502d8074a6b8c2d73ed83b92123106bd4bf837f04111043 4.10.3" \
    ANDROID_SDK_MANAGER_SHA256="92ffee5a1d98d856634e8b71132e8a95d96c83a63fde1099be3d86df3106def9" \
    SBT_DOWNLOAD_SHA256="9bb9212541176d6fcce7bd12e4cf8a9c9649f5b63f88b3aff474e0b02c7cfe58"

ARG MAVEN_CONFIG_HOME="/root/.m2"
ENV JAVA_HOME="$JAVA_11_HOME" \
    JDK_HOME="$JDK_11_HOME" \
    JRE_HOME="$JRE_11_HOME"

ENV PATH="${PATH}:/opt/tools:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools"

RUN set -ex \
    # Install Amazon Corretto 8
    && yum install -y java-1.8.0-amazon-corretto-devel \
    # Ensure Java cacerts symlink points to valid location
    && update-ca-trust

RUN set -x \
    # Install Amazon Corretto 11
    # Note: We will use update-alternatives to make sure JDK11 has higher priority for all the tools
    && yum install -y java-11-amazon-corretto \
    && for tool_path in $JAVA_HOME/bin/*; do \
          tool=`basename $tool_path`; \
          update-alternatives --install /usr/bin/$tool $tool $tool_path 10000; \
          update-alternatives --set $tool $tool_path; \
        done \
        && rm $JAVA_HOME/lib/security/cacerts && ln -s /etc/pki/java/cacerts $JAVA_HOME/lib/security/cacerts 

RUN set -ex \
    # Install Maven
    && mkdir -p $MAVEN_HOME \
    && curl -LSso /var/tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz https://apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz \
    && echo "$MAVEN_DOWNLOAD_SHA512 /var/tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz" | sha512sum -c - \
    && tar xzvf /var/tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz -C $MAVEN_HOME --strip-components=1 \
    && rm /var/tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz \
    && update-alternatives --install /usr/bin/mvn mvn /opt/maven/bin/mvn 10000 \
    && mkdir -p $MAVEN_CONFIG_HOME \

    # Install SBT
    && curl -fSL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" -o sbt.tgz \
    && echo "${SBT_DOWNLOAD_SHA256} *sbt.tgz" | sha256sum -c - \
    && tar xzvf sbt.tgz -C /usr/local/bin/ \
    && rm sbt.tgz
ENV PATH "/usr/local/bin/sbt/bin:$PATH"
RUN sbt version
# Cleanup
RUN rm -fr /tmp/* /var/tmp/*
#****************     END JAVA     ****************************************************

#**************** PYTHON *****************************************************
ENV PYTHON_37_VERSION="3.7.10"
ENV PYTHON_PIP_VERSION=20.2.4

COPY tools/runtime_configs/python/$PYTHON_37_VERSION /root/.pyenv/plugins/python-build/share/python-build/$PYTHON_37_VERSION
RUN   env PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install $PYTHON_37_VERSION; rm -rf /tmp/*
RUN   pyenv global  $PYTHON_37_VERSION
RUN set -ex \
    && pip3 install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" \
    && pip3 install --no-cache-dir --upgrade "PyYAML==5.3.1" \
    && pip3 install --no-cache-dir --upgrade setuptools wheel aws-sam-cli awscli boto3 pipenv virtualenv --use-feature=2020-resolver

#**************** END PYTHON *****************************************************


#=======================End of layer: runtimes_1  =================
FROM runtimes_1 AS runtimes_2

#Docker 19
ENV DOCKER_BUCKET="download.docker.com" \
    DOCKER_CHANNEL="stable" \
    DIND_COMMIT="3b5fac462d21ca164b3778647420016315289034" \
    DOCKER_COMPOSE_VERSION="1.26.0"

ENV DOCKER_SHA256="0f4336378f61ed73ed55a356ac19e46699a995f2aff34323ba5874d131548b9e"
ENV DOCKER_VERSION="19.03.11"

VOLUME /var/lib/docker

RUN set -ex \
    && curl -fSL "https://${DOCKER_BUCKET}/linux/static/${DOCKER_CHANNEL}/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
    && echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
    && tar --extract --file docker.tgz --strip-components 1  --directory /usr/local/bin/ \
    && rm docker.tgz \
    && docker -v \
    # set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
    && groupadd dockremap \
    && useradd -g dockremap dockremap \
    && echo 'dockremap:165536:65536' >> /etc/subuid \
    && echo 'dockremap:165536:65536' >> /etc/subgid \
    && wget -nv "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -O /usr/local/bin/dind \
    && curl -L https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64 > /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/dind /usr/local/bin/docker-compose \
    && docker-compose version

#Python 3.8
ENV PYTHON_38_VERSION="3.8.8"

COPY tools/runtime_configs/python/$PYTHON_38_VERSION /root/.pyenv/plugins/python-build/share/python-build/$PYTHON_38_VERSION
RUN   env PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install $PYTHON_38_VERSION; rm -rf /tmp/*
RUN   pyenv global  $PYTHON_38_VERSION
RUN set -ex \
    && pip3 install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" \
    && pip3 install --no-cache-dir --upgrade "PyYAML==5.3.1" \
    && pip3 install --no-cache-dir --upgrade setuptools wheel aws-sam-cli awscli boto3 pipenv virtualenv --use-feature=2020-resolver

#=======================End of layer: runtimes_2  =================
FROM runtimes_2 AS runtimes_3




#===================END of runtimes_3 ==============
FROM runtimes_3 AS al2_v3

# Configure SSH
COPY ssh_config /root/.ssh/config
COPY runtimes.yml /codebuild/image/config/runtimes.yml
COPY dockerd-entrypoint.sh /usr/local/bin/
COPY legal/THIRD_PARTY_LICENSES.txt /usr/share/doc
COPY legal/bill_of_material.txt     /usr/share/doc
COPY amazon-ssm-agent.json          /etc/amazon/ssm/

ENTRYPOINT ["dockerd-entrypoint.sh"]

#=======================End of layer: al2_v3  =================

