# 第一阶段：构建环境
FROM library/ubuntu:22.04 AS builder

ARG REPO_URL=git@codeup.aliyun.com:dooya/mhcb12g_demo.git

# 一次性安装所有必要工具并清理
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openssh-client \
    git \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 设置SSH配置（合并到单个RUN指令）
RUN mkdir -p ~/.ssh && \
    chmod 700 ~/.ssh && \
    ssh-keyscan codeup.aliyun.com >> ~/.ssh/known_hosts && \
    chmod 600 ~/.ssh/known_hosts

# 克隆仓库
RUN --mount=type=ssh,id=default \
    git clone --depth 1 ${REPO_URL} /tmp/src && \
    chmod -R 755 /tmp/src

# 第二阶段：使用更小的基础镜像
FROM library/ubuntu:22.04

LABEL maintainer="zhyi4 <molishanguang@outlook.com>"

# 一次性完成所有系统配置和软件安装
RUN cp -a /etc/apt/sources.list /etc/apt/sources.list.bak \
    && sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        bison \
        build-essential \
        default-jdk \
        dfu-util \
        genromfs \
        flex \
        gperf \
        kconfig-frontends \
        rsync \
        inotify-tools \
        dos2unix \
        file \
        tini \
        repo \
        python3-pip \
        lib32ncurses5-dev \
        libc6-dev-i386 \
        libx11-dev \
        libx11-dev:i386 \
        libxext-dev \
        libxext-dev:i386 \
        net-tools \
        pkgconf \
        unionfs-fuse \
        zlib1g-dev \
        software-properties-common \
        libpulse-dev:i386 \
        libasound2-dev:i386 \
        libasound2-plugins:i386 \
        libusb-1.0-0-dev \
        libusb-1.0-0-dev:i386 \
        unzip \
        sudo \
        git \
        openssh-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 复制仓库内容
COPY --from=builder /tmp/src /root/MHCB12

# 复制并设置构建脚本（合并到单个指令）
# 1. 先单独执行COPY指令
COPY ./sh/build.sh /root/build.sh

# 2. 然后执行权限设置和链接创建
RUN chmod +x /root/build.sh && \
    ln -s /root/build.sh /usr/local/bin/build

# 设置工作目录
WORKDIR /root/workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "-c", "build 2>&1 | tee /root/workspace/build.log"]