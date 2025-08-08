# C 语言客户端 test_gpio_client 使用说明

## 概述
`test_gpio_client.c` 是用于测试 GPIO 守护进程（`gpio_daemon`）RPC 接口的轻量级 C 语言客户端工具。支持三种使用方式：
- 单次命令模式（-c）
- 自动测试模式（-A）
- 交互模式（默认，无参数）

该客户端通过 TCP 直连守护进程（默认 localhost:8888），发送原始命令字符串（不含换行）并打印响应。

## 编译
在目标设备（如 Jetson）上编译：
```bash
cd gpio
gcc -Wall -O2 -o test_gpio_client test_gpio_client.c
```

说明：
- 无第三方依赖，仅使用系统 socket API
- 生成的可执行文件为 `test_gpio_client`

## 用法
### 参数
```text
-H host     服务器地址，默认: localhost
-p port     服务器端口，默认: 8888
-c command  直接发送命令（status|normal|reset|dfu|test|test_exit）
-A          运行自动测试序列
```
不带 `-c`/`-A` 参数时进入交互模式，输入 `exit` 退出。

### 示例
- 单次命令
```bash
./test_gpio_client -c status
./test_gpio_client -c test
./test_gpio_client -c test_exit
```

- 自动测试
```bash
./test_gpio_client -A
```

- 指定主机和端口
```bash
./test_gpio_client -H 127.0.0.1 -p 8888 -c status
```

- 交互模式（默认，无参数）
```bash
./test_gpio_client
# 输入: status / normal / reset / dfu / test / test_exit / exit
```

## 可用命令
- `status`       查询当前状态（STATUS:NORMAL/RESET/DFU/TEST）
- `normal`       设置为正常运行
- `reset`        触发复位（临时状态）
- `dfu`          进入 DFU 模式
- `test`         进入测试模式（每 3 秒高低电平跳变）
- `test_exit`    退出测试模式

## 故障排查
- 确认守护进程已运行，并监听 8888 端口：
  ```bash
  systemctl status gpio-daemon.service
  netstat -tuln | grep 8888
  ```
- 查看守护进程日志：
  ```bash
  journalctl -u gpio-daemon.service -f
  ```
- 远程测试时，确保网络可达且未被防火墙拦截 