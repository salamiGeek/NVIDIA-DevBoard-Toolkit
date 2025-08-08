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

使用提供的安装脚本进行一键安装：

```bash
sudo ./install_gpio.sh
```

该脚本会自动执行以下操作：
- 检查并安装必要的依赖（如果尚未安装）
- 编译GPIO守护进程
- 安装可执行文件到系统目录
- 安装并启用系统服务
- 启动服务并显示状态

安装完成后，可以使用以下命令检查服务状态：
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

> **注意**：命令发送时必须使用 `echo -n` 以避免发送额外的换行符，否则可能导致命令无法识别。

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

### 5.2 测试工具

本项目提供了以下测试工具：

1. **test_gpio_daemon.sh**：自动化测试脚本，用于测试GPIO守护进程的RPC接口
2. **test_mock.c**：模拟程序，模拟GPIO守护进程的RPC接口功能
3. **test_gpio_client.py**：Python客户端，用于测试RPC接口

### 5.3 自动化测试

使用提供的测试脚本进行自动化测试：

```bash
sudo ./test_gpio_daemon.sh
```

该脚本会自动执行以下测试：
- 检查服务状态
- 测试状态查询
- 测试正常模式
- 测试复位功能
- 测试DFU模式
- 恢复正常模式

### 5.4 模拟测试

如果没有实际硬件，可以使用模拟程序进行测试：

1. 编译模拟程序：
   ```bash
   gcc -Wall -o test_mock test_mock.c
   ```

2. 运行模拟程序：
   ```bash
   ./test_mock
   ```

3. 使用Python客户端测试模拟程序：
   ```bash
   ./test_gpio_client.py
   ```

### 5.5 Python客户端测试

Python客户端提供了更丰富的测试功能，包括交互式测试和命令行参数：

```bash
# 交互式测试
./test_gpio_client.py

# 命令行参数测试
./test_gpio_client.py -c status    # 查询状态
./test_gpio_client.py -c normal    # 设置为正常模式
./test_gpio_client.py -c reset     # 复位单片机
./test_gpio_client.py -c dfu       # 进入DFU模式
./test_gpio_client.py -c auto      # 运行自动测试

# 指定主机和端口
./test_gpio_client.py -H 192.168.1.100 -p 8888
```

### 5.6 测试结果验证

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

### 6.2 命令无法识别

如果使用测试脚本或手动发送命令时收到 `ERROR:UNKNOWN_COMMAND` 响应：

1. 确保使用 `echo -n` 发送命令，避免额外的换行符：
   ```bash
   echo -n "status" | nc localhost 8888
   ```

2. 检查服务日志，查看实际接收到的命令：
   ```bash
   journalctl -u gpio-daemon.service -f
   ```

### 6.3 编译错误

1. 检查libgpiod开发库是否已安装：
   ```bash
   pkg-config --exists libgpiod && echo "已安装" || echo "未安装"
   ```

2. 安装libgpiod开发库：
   ```bash
   sudo apt-get install -y libgpiod-dev
   ```

### 6.4 GPIO控制失败

1. 检查GPIO权限：
   ```bash
   ls -l /dev/gpiochip*
   ```

2. 检查GPIO引脚号是否正确：
   修改源代码中的`PH40_RESET_PIN`和`PH40_BOOT_PIN`定义 