# GPIO守护进程使用与测试说明

## 1. 功能介绍

GPIO守护进程（gpio_daemon）是一个用于控制单片机复位和DFU模式的系统服务。它通过控制NVIDIA Jetson开发板上的GPIO引脚，实现对单片机的三种状态控制：

1. **正常运行状态**：单片机正常工作
2. **复位状态**：触发单片机复位
3. **DFU模式**：使单片机进入DFU烧录模式

该守护进程提供RPC接口，允许通过网络远程控制单片机状态。

## 2. 安装方法

### 2.1 依赖项

- libgpiod-dev：GPIO控制库
- netcat：用于测试RPC接口（可选）

### 2.2 安装步骤

1. 确保系统已安装libgpiod开发库：
   ```bash
   sudo apt-get update
   sudo apt-get install -y libgpiod-dev
   ```

2. 运行安装脚本：
   ```bash
   cd gpio
   sudo ./install_gpio.sh
   ```

3. 检查服务是否正常运行：
   ```bash
   systemctl status gpio-daemon.service
   ```

## 3. 使用方法

### 3.1 RPC接口

GPIO守护进程在本地8888端口提供RPC接口，可以通过以下命令进行控制：

1. 查询当前状态：
   ```bash
   echo -n "status" | nc localhost 8888
   ```
   返回值：
   - `STATUS:NORMAL`：正常运行状态
   - `STATUS:RESET`：复位状态
   - `STATUS:DFU`：DFU模式状态
   - `STATUS:TEST`：测试模式状态

2. 设置为正常运行状态：
   ```bash
   echo -n "normal" | nc localhost 8888
   ```
   返回值：`OK:NORMAL`

3. 复位单片机：
   ```bash
   echo -n "reset" | nc localhost 8888
   ```
   返回值：`OK:RESET`

4. 进入DFU模式：
   ```bash
   echo -n "dfu" | nc localhost 8888
   ```
   返回值：`OK:DFU`

5. 进入测试模式（每3秒跳变一次）：
   ```bash
   echo -n "test" | nc localhost 8888
   ```
   返回值：`OK:TEST`

6. 退出测试模式：
   ```bash
   echo -n "test_exit" | nc localhost 8888
   ```
   返回值：`OK:TEST_EXIT`

### 3.2 服务管理

#### 服务控制

- 启动服务：`sudo systemctl start gpio-daemon.service`
- 停止服务：`sudo systemctl stop gpio-daemon.service`
- 重启服务：`sudo systemctl restart gpio-daemon.service`
- 查看状态：`sudo systemctl status gpio-daemon.service`
- 启用开机自启：`sudo systemctl enable gpio-daemon.service`
- 禁用开机自启：`sudo systemctl disable gpio-daemon.service`

#### 日志查看

查看守护进程日志：
```bash
journalctl -u gpio-daemon.service
```

实时查看日志：
```bash
journalctl -u gpio-daemon.service -f
```

## 4. 技术说明

### 4.1 GPIO引脚定义

- 复位引脚（RESET_PIN）：GPIO 31
- BOOT引脚（BOOT_PIN）：GPIO 32

可以根据实际硬件连接修改源代码中的引脚定义。

### 4.2 编译方法

如需手动编译：
```bash
gcc -Wall -o gpio_daemon gpio_daemon.c -lgpiod
```

## 5. 测试方法

### 5.1 测试环境

GPIO守护进程的测试可以在以下两种环境中进行：

1. **实际硬件环境**：在NVIDIA Jetson设备上进行实际的GPIO操作测试
2. **模拟测试环境**：在没有实际硬件的情况下，使用模拟程序进行功能测试

### 5.2 测试方式

无需额外脚本，使用 nc 命令直接测试 RPC 接口（见下文“快速测试”）。

### 5.3 快速测试

安装完成后，可直接通过 nc 进行快速测试：

```bash
echo -n "status" | nc localhost 8888
```

常用测试命令：
```bash
echo -n "normal" | nc localhost 8888
echo -n "reset"  | nc localhost 8888
echo -n "dfu"    | nc localhost 8888
echo -n "test"   | nc localhost 8888
echo -n "test_exit" | nc localhost 8888
```

### 5.4 模拟测试

（已移除模拟测试示例）

### 5.5 实际硬件测试

在实际硬件上进行测试：

1. 安装GPIO守护进程：
   ```bash
   cd gpio
   sudo ./install_gpio.sh
   ```

2. 检查服务状态：
   ```bash
   systemctl status gpio-daemon.service
   ```

3. 使用 nc 进行测试（示例见“快速测试”小节）


### 5.6 命令行测试

使用 nc 命令进行测试（示例）：

```bash
echo -n "status" | nc localhost 8888

echo -n "normal" | nc localhost 8888
echo -n "reset"  | nc localhost 8888
echo -n "dfu"    | nc localhost 8888
echo -n "test"   | nc localhost 8888
echo -n "test_exit" | nc localhost 8888
```

#### C 语言客户端测试工具（可选）

编译：
```bash
cd gpio
gcc -Wall -O2 -o test_gpio_client test_gpio_client.c
```

用法：
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

### 5.7 测试结果验证

#### 正常运行状态

- 状态查询返回：`STATUS:NORMAL`
- BOOT引脚输出高电平
- RST引脚输出低电平

#### 复位状态

- 状态查询返回：`STATUS:RESET`（临时状态）
- RST引脚先输出高电平，延时300ms后恢复低电平

#### DFU模式

- 状态查询返回：`STATUS:DFU`
- BOOT引脚输出低电平
- RST引脚先输出高电平，延时100ms后恢复低电平

#### 测试模式

- 状态查询返回：`STATUS:TEST`
- BOOT引脚和RST引脚同时每3秒在高低电平之间切换
- 高电平状态持续3秒，低电平状态持续3秒
- 可以通过`test_exit`命令或`normal`命令退出测试模式

## 6. 故障排除

### 6.1 无法连接到RPC服务器

1. 检查服务是否正在运行：
   ```bash
   systemctl status gpio-daemon.service
   ```

2. 检查端口是否被占用：
   ```bash
   netstat -tuln | grep 8888
   ```

3. 检查防火墙设置：
   ```bash
   sudo ufw status
   ```

### 6.2 编译错误

1. 检查libgpiod开发库是否已安装：
   ```bash
   pkg-config --exists libgpiod && echo "已安装" || echo "未安装"
   ```

2. 安装libgpiod开发库：
   ```bash
   sudo apt-get install -y libgpiod-dev
   ```

### 6.3 GPIO控制失败

1. 检查GPIO权限：
   ```bash
   ls -l /dev/gpiochip*
   ```

2. 检查GPIO引脚号是否正确：
   修改源代码中的`PH40_RESET_PIN`和`PH40_BOOT_PIN`定义 