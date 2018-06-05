#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

FROM openjdk:8-jdk as builder

WORKDIR /build

COPY . .

RUN set -ex && \
    apt-get update && \
    apt-get upgrade -y

RUN ./dev/make-distribution.sh --name astarte-kubernetes-spark --tgz -Phadoop-2.7 -Phive -Phive-thriftserver -Pyarn -Pkubernetes

FROM openjdk:8-jdk-slim

ARG spark_jars=assembly/target/scala-2.11/jars
ARG img_path=resource-managers/kubernetes/docker/src/main/dockerfiles

# Before building the docker image, first build and make a Spark distribution following
# the instructions in http://spark.apache.org/docs/latest/building-spark.html.
# If this docker file is being used in the context of building your images from a Spark
# distribution, the docker build command should be invoked from the top level directory
# of the Spark distribution. E.g.:
# docker build -t spark:latest -f kubernetes/dockerfiles/spark/Dockerfile .

RUN set -ex && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && \
    mkdir -p /opt/spark && \
    mkdir -p /opt/spark/work-dir \
    touch /opt/spark/RELEASE && \
    rm /bin/sh && \
    ln -sv /bin/bash /bin/sh && \
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd

# Add Tini
ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /sbin/tini
RUN chmod +x /sbin/tini

COPY --from=builder build/${spark_jars} /opt/spark/jars
COPY --from=builder build/bin /opt/spark/bin
COPY --from=builder build/sbin /opt/spark/sbin
COPY --from=builder build/conf /opt/spark/conf
COPY --from=builder build/${img_path}/spark/entrypoint.sh /opt/
COPY --from=builder build/examples /opt/spark/examples
COPY --from=builder build/data /opt/spark/data

ENV SPARK_HOME /opt/spark

WORKDIR /opt/spark/work-dir

ENTRYPOINT [ "/opt/entrypoint.sh" ]
