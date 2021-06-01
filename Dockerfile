# Copyright (c) Association of Universities for Research in Astronomy
# Distributed under the terms of the Modified BSD License.

# DATB's HST CAL code build for fundamental calibration s/w
ARG CAL_BASE_IMAGE=stsci/hst-pipeline:stable
FROM ${CAL_BASE_IMAGE}

# Keyword added to products
ENV CSYS_VER ${CAL_BASE_IMAGE}

LABEL maintainer="dmd_octarine@stsci.edu" \
      vendor="Space Telescope Science Institute"

# Environment variables
ENV MKL_THREADING_LAYER="GNU"

ENV REQUESTS_CA_BUNDLE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
ENV CURL_CA_BUNDLE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

# ------------------------------------------------------------------------
# SSL/TLS cert setup for STScI AWS firewalling

USER root

RUN mkdir -p /etc/ssl/certs && \
    mkdir -p /etc/pki/ca-trust/extracted/pem
COPY tls-ca-bundle.pem /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
RUN mv /etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-bundle.crt.org && \
    ln -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem  /etc/ssl/certs/ca-bundle.crt && \
   #  mv /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt.org && \
    ln -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/ssl/certs/ca-certificates.crt && \
   #  ln -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /usr/lib/ssl/cert.pem && \
    mkdir -p /etc/pki/ca-trust/extracted/openssl

# RUN npm config set cafile /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
COPY scripts/fix-certs .
RUN ./fix-certs

# Removing kernel-headers seems to remove glibc and all packages which use them
# Install s/w dev tools for fitscut build
RUN yum remove -y kernel-devel   &&\
 yum update  -y && \
 yum install -y \
   emacs-nox \
   make \
   gcc \
   gcc-c++ \
   gcc-gfortran \
   python3 \
   python3-devel \
   htop \
   wget \
   git \
   libpng-devel \
   libjpeg-devel \
   libcurl-devel \
   tar \
   patch \
   curl \
   rsync \
   time

# Install fitscut
COPY scripts/caldp-install-fitscut  .
RUN ./caldp-install-fitscut   /usr/local && \
   rm ./caldp-install-fitscut && \
   echo "/usr/local/lib" >> /etc/ld.so.conf && \
   ldconfig

# Install caldp pip package from local source
WORKDIR /home/developer
RUN mkdir /home/developer/caldp
COPY . /home/developer/caldp/
RUN chown -R developer.developer /home/developer

# this is a temporary solution for an update to the crds_s3_get plugin
# because python in the sdp environment is pinned to 3.6, crds is pinned to 10.1.0
COPY ./scripts/crds_s3_get /home/developer/crds_s3_get
RUN chmod +x /home/developer/crds_s3_get

# CRDS cache mount point or container storage.
RUN mkdir -p /grp/crds/cache && chown -R developer.developer /grp/crds/cache

# Part #2 of turning on core dumps
# # These are also Terraformed as Docker --ulimit,  container runtime also needs to permit.
# RUN echo "*               soft    core            -1" >> /etc/security/limits.conf &&\
#     echo "*               hard    core            -1" >> /etc/security/limits.conf


# ------------------------------------------------
USER developer
RUN cd caldp  &&  pip install .[dev,test]
