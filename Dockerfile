FROM amazonlinux:2023

# Set up working directories
RUN mkdir -p /opt/app /opt/app/build /opt/app/bin/

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# Install packages
RUN \
  yum update -y && \
  yum install -y \
    cpio \
    python3-pip \
    yum-utils \
    zip \
  && yum clean all

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip3 install -r requirements.txt && rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN \
  yumdownloader -x \*i686 --archlist=x86_64 \
    clamav \
    clamav-lib \
    clamav-update \
    gnutls \
    json-c \
    libtasn1 \
    libtool-ltdl \
    libxml2.x86_64 \
    nettle \
    pcre \
    pcre2 \
    xz-libs \
  && rpm2cpio clamav-0*.rpm | cpio -idmv \
  && rpm2cpio clamav-lib*.rpm | cpio -idmv \
  && rpm2cpio clamav-update*.rpm | cpio -idmv \
  && rpm2cpio gnutls*.rpm | cpio -idmv \
  && rpm2cpio json-c*.rpm | cpio -idmv \
  && rpm2cpio libtasn1*.rpm | cpio -idmv \
  && rpm2cpio libtool-ltdl*.rpm | cpio -idmv \
  && rpm2cpio libxml2*.rpm | cpio -idmv \
  && rpm2cpio nettle*.rpm | cpio -idmv \
  && rpm2cpio pcre*.rpm | cpio -idmv \
  && rpm2cpio pcre2*.rpm | cpio -idmv \
  && rpm2cpio xz-libs*.rpm | cpio -idmv \
  # Copy over the binaries and libraries
  && cp /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/lib64/* /opt/app/bin/ \
  # Grab libssl - the lambda environment has libssl.so.10 but we are looking for libssl.so.3
  && cp /lib64/libssl* /opt/app/bin/ \
  && cp /lib64/libcrypto* /opt/app/bin/ \
  # Fix the freshclam.conf settings
  && echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf \
  && echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /usr/local/lib/python3.9/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *

WORKDIR /opt/app
