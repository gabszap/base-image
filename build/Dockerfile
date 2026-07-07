ARG IMAGE_BASE="nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04"

# Caddy build
FROM ubuntu:24.04 as caddybuilder

ENV PATH=/opt/go/bin:$PATH
ENV GOROOT=/opt/go
RUN apt-get update && \
    apt-get install -y wget && \
    # Go — verify against Google-published .sha256 alongside the tarball
    wget https://dl.google.com/go/go1.26.3.linux-amd64.tar.gz && \
    wget -q -O go1.26.3.linux-amd64.tar.gz.sha256 https://dl.google.com/go/go1.26.3.linux-amd64.tar.gz.sha256 && \
    echo "$(cat go1.26.3.linux-amd64.tar.gz.sha256)  go1.26.3.linux-amd64.tar.gz" | sha256sum -c - && \
    tar -xf go1.26.3.linux-amd64.tar.gz && \
    mv ./go /opt && \
    # xcaddy — verify against the release's checksums.txt (SHA-512 despite the generic filename)
    wget https://github.com/caddyserver/xcaddy/releases/download/v0.4.5/xcaddy_0.4.5_linux_amd64.deb && \
    wget -q -O xcaddy_0.4.5_checksums.txt https://github.com/caddyserver/xcaddy/releases/download/v0.4.5/xcaddy_0.4.5_checksums.txt && \
    grep " xcaddy_0.4.5_linux_amd64.deb$" xcaddy_0.4.5_checksums.txt | sha512sum -c - && \
    apt-get install ./xcaddy_0.4.5_linux_amd64.deb && \
    xcaddy build \
        --with github.com/caddyserver/caddy/v2=github.com/ai-dock/caddy/v2@httpredirect \
        --with github.com/caddyserver/replace-response && \
    mkdir -p /opt/caddy/bin && \
    mkdir -p /opt/caddy/tls && \
    mv ./caddy /opt/caddy/bin


# For build automation - Allows building from any Debian-based image

FROM ${IMAGE_BASE}

# System libs are handled in /etc/ld.so.conf.d
# Python environments only to use this variable
ENV LD_LIBRARY_PATH=

COPY --from=caddybuilder /opt/caddy/ /opt/caddy/

# Determines which scripts at /opt/ai-dock/bin/build/layerX will be run by init.sh
ARG XPU_TARGET="NVIDIA_GPU" # NVIDIA_GPU, AMD_GPU, CPU
ENV XPU_TARGET=${XPU_TARGET}

ARG NODE_VERSION=v22.22.3
ENV NODE_VERSION=${NODE_VERSION}

LABEL org.opencontainers.image.source https://github.com/lucidboxai/base-image

LABEL org.opencontainers.image.description "Base image for ai-dock (lucidboxai fork)."

LABEL maintainer="lucidboxai"

SHELL ["/bin/bash", "-c"]
# Set ENV variables
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TZ=UTC
ENV SHELL="/bin/bash"
ENV USER_NAME=user
ENV USER_PASSWORD=password
ENV USER_GROUPS=users,ai-dock,adm,sudo,audio,video,tty,cdrom,dialout,dip,fax,floppy,lp,plugdev,ssl-cert,sudo,tape,voice
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/opt/ai-dock/bin:/opt/caddy/bin:$PATH
ENV OPT_SYNC=
ENV PYTHONUNBUFFERED=true
ENV VENV_DIR=/opt/environments/python
ENV SERVICEPORTAL_VENV=${VENV_DIR}/serviceportal
ENV SERVICEPORTAL_VENV_PYTHON=${SERVICEPORTAL_VENV}/bin/python
ENV SERVICEPORTAL_VENV_PIP=${SERVICEPORTAL_VENV}/bin/pip
ENV SUPERVISOR_NO_AUTOSTART=

ENV APT_INSTALL="apt-get install -y --no-install-recommends"
ENV RCLONE_CONFIG="/etc/rclone/rclone.conf"
ENV IMAGE_SLUG="base-image"
ENV CODE_SERVER_PROXY_PORT=2222
ENV CODE_SERVER_ENABLED=true
ENV CODE_SERVER_EXTENSIONS=castrogusttavo.symbols

# code-server — VS Code in the browser (latest stable)
RUN apt-get update && apt-get install -y --no-install-recommends wget ca-certificates && \
    CODE_SERVER_VERSION=$(wget -qO- https://api.github.com/repos/coder/code-server/releases/latest | grep -oP '"tag_name": "\K[^"]+') && \
    echo "Installing code-server ${CODE_SERVER_VERSION}" && \
    wget https://github.com/coder/code-server/releases/download/${CODE_SERVER_VERSION}/code-server_${CODE_SERVER_VERSION#v}_amd64.deb && \
    apt-get install -y ./code-server_${CODE_SERVER_VERSION#v}_amd64.deb && \
    rm code-server_${CODE_SERVER_VERSION#v}_amd64.deb && \
    rm -rf /var/lib/apt/lists/* && \
    echo "code-server ${CODE_SERVER_VERSION} installed successfully"

# Copy early so we can use scripts in the build - Changes to these files will invalidate the cache and cause a rebuild.
COPY --chown=0:1111 ./COPY_ROOT_0/ /

ARG CUDA_STRING
ARG ROCM_STRING

# Use build scripts to ensure we can build all targets from one Dockerfile in a single layer.
# Don't put anything heavy in here - We can use multi-stage building above if necessary.
# Ubuntu 24.04 moved `unminimize` out of the base image into its own package;
# on 22.04 it ships as a built-in script. Install the package only if absent.

# Impede dpkg de perguntar sobre conffiles durante o build
RUN echo 'Dpkg::Options { "--force-confold"; "--force-confdef"; }' \
    > /etc/apt/apt.conf.d/99-docker-build

RUN sed -i 's/^exit 1$/exit 0/' /opt/ai-dock/bin/env-store.sh

RUN set -eo pipefail && \
    find /opt/ai-dock/bin/ -type f -name "*.sh" -exec sed -i 's/\r$//' {} + && \
    sed -i 's/^exit 1$/exit 0/' /opt/ai-dock/bin/env-store.sh && \
    DEBIAN_FRONTEND=noninteractive \
    DEBIAN_PRIORITY=critical \
    RUNLEVEL=1 /opt/ai-dock/bin/build/layer0/init.sh | tee /var/log/build.log

# Supervisor config is placed in subdirectory due to COPY naming; ensure main config is correct
RUN cp /etc/supervisor/supervisord/supervisord.conf /etc/supervisor/supervisord.conf

# Keep init.sh as-is and place additional logic in /opt/ai-dock/bin/preflight.d
CMD ["init.sh"]
