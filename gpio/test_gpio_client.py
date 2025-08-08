#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
GPIO守护进程RPC接口测试客户端
用于测试GPIO守护进程的RPC接口功能
"""

import socket
import time
import argparse
import sys


class GPIOClient:
    """GPIO守护进程RPC客户端"""
    
    def __init__(self, host='localhost', port=8888):
        """初始化客户端"""
        self.host = host
        self.port = port
    
    def send_command(self, command):
        """发送命令到GPIO守护进程"""
        try:
            # 创建套接字
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                # 连接服务器
                s.connect((self.host, self.port))
                # 发送命令
                s.sendall(command.encode())
                # 接收响应
                response = s.recv(1024)
                return response.decode()
        except ConnectionRefusedError:
            return "错误: 连接被拒绝，请确认GPIO守护进程正在运行"
        except Exception as e:
            return f"错误: {str(e)}"
    
    def get_status(self):
        """获取当前状态"""
        return self.send_command('status')
    
    def set_normal(self):
        """设置为正常运行状态"""
        return self.send_command('normal')
    
    def reset_mcu(self):
        """复位单片机"""
        return self.send_command('reset')
    
    def enter_dfu(self):
        """进入DFU模式"""
        return self.send_command('dfu')


def print_colored(text, color_code):
    """打印彩色文本"""
    if sys.stdout.isatty():
        print(f"\033[{color_code}m{text}\033[0m")
    else:
        print(text)


def run_interactive_test(client):
    """运行交互式测试"""
    print_colored("===== GPIO守护进程交互式测试 =====", "1;33")
    print("可用命令:")
    print("  status - 查询当前状态")
    print("  normal - 设置为正常运行状态")
    print("  reset  - 复位单片机")
    print("  dfu    - 进入DFU模式")
    print("  auto   - 执行自动测试")
    print("  exit   - 退出测试")
    print("")
    
    while True:
        try:
            cmd = input("请输入命令> ").strip()
            
            if cmd == "exit":
                break
            elif cmd == "status":
                response = client.get_status()
                print_colored(f"响应: {response}", "0;32")
            elif cmd == "normal":
                response = client.set_normal()
                print_colored(f"响应: {response}", "0;32")
            elif cmd == "reset":
                response = client.reset_mcu()
                print_colored(f"响应: {response}", "0;32")
            elif cmd == "dfu":
                response = client.enter_dfu()
                print_colored(f"响应: {response}", "0;32")
            elif cmd == "auto":
                run_auto_test(client)
            else:
                print_colored(f"未知命令: {cmd}", "0;31")
        except KeyboardInterrupt:
            print("\n退出测试")
            break
        except Exception as e:
            print_colored(f"错误: {str(e)}", "0;31")


def run_auto_test(client):
    """运行自动测试"""
    print_colored("\n===== 开始自动测试 =====", "1;34")
    
    # 测试查询状态
    print("测试1: 查询当前状态")
    response = client.get_status()
    print_colored(f"响应: {response}", "0;32")
    time.sleep(1)
    
    # 测试设置正常状态
    print("\n测试2: 设置为正常运行状态")
    response = client.set_normal()
    print_colored(f"响应: {response}", "0;32")
    time.sleep(1)
    
    # 测试复位功能
    print("\n测试3: 复位单片机")
    response = client.reset_mcu()
    print_colored(f"响应: {response}", "0;32")
    time.sleep(1)
    
    # 测试DFU模式
    print("\n测试4: 进入DFU模式")
    response = client.enter_dfu()
    print_colored(f"响应: {response}", "0;32")
    time.sleep(1)
    
    # 恢复正常状态
    print("\n测试5: 恢复正常状态")
    response = client.set_normal()
    print_colored(f"响应: {response}", "0;32")
    
    print_colored("\n===== 自动测试完成 =====", "1;34")


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='GPIO守护进程RPC接口测试客户端')
    parser.add_argument('-H', '--host', default='localhost', help='服务器主机名或IP地址')
    parser.add_argument('-p', '--port', type=int, default=8888, help='服务器端口')
    parser.add_argument('-c', '--command', choices=['status', 'normal', 'reset', 'dfu', 'auto'], 
                        help='要执行的命令')
    
    args = parser.parse_args()
    
    # 创建客户端
    client = GPIOClient(args.host, args.port)
    
    if args.command:
        # 命令行模式
        if args.command == 'status':
            response = client.get_status()
            print(response)
        elif args.command == 'normal':
            response = client.set_normal()
            print(response)
        elif args.command == 'reset':
            response = client.reset_mcu()
            print(response)
        elif args.command == 'dfu':
            response = client.enter_dfu()
            print(response)
        elif args.command == 'auto':
            run_auto_test(client)
    else:
        # 交互式模式
        run_interactive_test(client)


if __name__ == "__main__":
    main() 