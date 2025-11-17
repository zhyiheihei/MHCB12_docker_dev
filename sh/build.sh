#!/bin/bash
###
 # @Author       : error: git config user.name & please set dead value or install git
 # @Date         : 2025-02-08 02:42:01
 # @LastEditors  : moli-pp
 # @LastEditTime : 2025-06-18 16:10:18
 # @FilePath     : \MHCB12_docker_dev\sh\build.sh
 # @Description  : 
 # 
 # Copyright (c) 2025 by lym, All Rights Reserved. 
### 

# 参数检查
if [ $# -gt 1 ]; then
    echo "错误：参数过多，只能不带参数或使用以下参数之一：clean menuconfig pm" >&2
    exit 1
fi

if [ $# -eq 1 ] && [[ "$1" != "clean" && "$1" != "menuconfig" && "$1" != "pm" ]]; then
    echo "错误：无效参数 '$1'，只能使用以下参数之一：clean menuconfig pm" >&2
    exit 1
fi

# 清空目标目录并同步workspace数据，忽略隐藏文件夹（不显示日志）
SYNC_COMMAND="rsync -aqz --delete --exclude='.*/' --exclude='.*' /root/workspace/vendor/xiaomi/mijia_ble_mesh/ /root/MHCB12/vendor/xiaomi/mijia_ble_mesh/ && find /root/MHCB12/vendor/xiaomi/mijia_ble_mesh/ -type f -exec dos2unix {} \; >/dev/null 2>&1"

# 定义常量
CD_COMMAND="cd /root/MHCB12"
MOVE_COMMAND="rsync -aqz --remove-source-files --include=application_is_MP_* --exclude=* /root/MHCB12/vendor/realtek/tools/bee/application_is/Debug/bin/ /root/workspace/output/"
CHECK_DIR="/root/MHCB12/vendor/realtek/tools/bee/application_is/Debug/bin/"

# 执行同步和行尾转换（非clean和menuconfig模式下）
if [[ "$1" != "clean" && "$1" != "menuconfig" ]]; then
    echo "正在同步workspace数据并转换行尾..."
    eval $SYNC_COMMAND
    if [ $? -ne 0 ]; then
        echo "同步和行尾转换失败，退出状态码: $?" >&2
        exit 1
    fi
    echo "同步和行尾转换完成。"
fi

# 执行进入目录命令
eval $CD_COMMAND
if [ $? -ne 0 ]; then
    echo "进入目录失败，退出状态码: $?，跳过后续步骤。"
    exit 1
fi

# 根据参数设置构建命令
declare -A BUILD_COMMANDS=(
    [clean]="./build.sh vendor/realtek/boards/rtl8762e/configs/app distclean"
    [menuconfig]="./build.sh vendor/realtek/boards/rtl8762e/configs/app menuconfig"
    [pm]="./build.sh vendor/realtek/boards/rtl8762e/configs/app_pm"
)

BUILD_COMMAND="${BUILD_COMMANDS[$1]:-./build.sh vendor/realtek/boards/rtl8762e/configs/app}"

# 确保输出目录存在
mkdir -p /root/workspace/output/

# 执行编译命令，并在后台运行
echo "开始执行构建命令: $BUILD_COMMAND"
$BUILD_COMMAND &
BUILD_PID=$!

# 如果不是clean模式，监控并移动生成的文件
if [ "$1" != "clean" ]; then
    # 循环检查编译命令是否还在运行
    while ps -p $BUILD_PID > /dev/null; do
        # 检查是否存在满足条件的文件
        if find "$CHECK_DIR" -maxdepth 1 -name "application_is_MP_*" | grep -q .; then
            echo "检测到新生成的文件，正在移动..."
            $MOVE_COMMAND
            [ $? -eq 0 ] && echo "文件已成功移动到workspace/output目录" || echo "文件移动失败，退出状态码: $?"
        fi
        sleep 5  # 每5秒检查一次
    done
fi

# 等待编译命令完成
wait $BUILD_PID
BUILD_EXIT_CODE=$?

# 检查编译命令的退出状态
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo "编译成功完成。"
    if [ "$1" != "clean" ]; then
        # 再次检查并移动文件，确保最后一次检查
        if find "$CHECK_DIR" -maxdepth 1 -name "application_is_MP_*" | grep -q .; then
            echo "检测到最终生成的文件，正在移动..."
            $MOVE_COMMAND
            [ $? -eq 0 ] && echo "文件已成功移动到workspace/output目录" || echo "文件移动失败，退出状态码: $?"
        fi
        echo "所有操作已完成"
    else
        echo "清理编译成功。"
    fi
    exit 0
else
    echo "编译或清理操作失败，退出状态码: $BUILD_EXIT_CODE，跳过文件移动步骤。"
    exit $BUILD_EXIT_CODE
fi

rm -rf /root/MHCB12/vendor/xiaomi/mijia_ble_mesh/* # 清除同步的文件
