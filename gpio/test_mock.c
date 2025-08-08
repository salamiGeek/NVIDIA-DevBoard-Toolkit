/**
 * test_mock.c - GPIO守护进程的模拟测试程序
 * 
 * 这个程序模拟libgpiod库的功能，用于在没有实际硬件的情况下测试GPIO守护进程
 * 编译：gcc -Wall -o test_mock test_mock.c
 * 运行：./test_mock
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define RPC_PORT 8888
#define BUFFER_SIZE 1024

// 模拟GPIO状态
typedef enum {
    GPIO_STATE_NORMAL = 0,
    GPIO_STATE_RESET = 1,
    GPIO_STATE_DFU = 2
} gpio_state_t;

static gpio_state_t current_state = GPIO_STATE_NORMAL;
static volatile int running = 1;

// 信号处理函数
void signal_handler(int signo) {
    if (signo == SIGINT || signo == SIGTERM) {
        printf("接收到终止信号，准备退出...\n");
        running = 0;
    }
}

// 处理RPC命令
void handle_command(char *cmd, char *response) {
    printf("收到命令: %s\n", cmd);
    
    if (strcmp(cmd, "status") == 0) {
        switch (current_state) {
            case GPIO_STATE_NORMAL:
                strcpy(response, "STATUS:NORMAL");
                break;
            case GPIO_STATE_RESET:
                strcpy(response, "STATUS:RESET");
                break;
            case GPIO_STATE_DFU:
                strcpy(response, "STATUS:DFU");
                break;
            default:
                strcpy(response, "STATUS:UNKNOWN");
        }
    } else if (strcmp(cmd, "normal") == 0) {
        current_state = GPIO_STATE_NORMAL;
        printf("设置为正常运行状态\n");
        strcpy(response, "OK:NORMAL");
    } else if (strcmp(cmd, "reset") == 0) {
        current_state = GPIO_STATE_RESET;
        printf("执行单片机复位...\n");
        usleep(300000);  // 模拟延时300ms
        current_state = GPIO_STATE_NORMAL;
        printf("单片机复位完成\n");
        strcpy(response, "OK:RESET");
    } else if (strcmp(cmd, "dfu") == 0) {
        current_state = GPIO_STATE_DFU;
        printf("执行进入DFU模式...\n");
        printf("DFU模式设置完成\n");
        strcpy(response, "OK:DFU");
    } else {
        strcpy(response, "ERROR:UNKNOWN_COMMAND");
    }
}

// 启动RPC服务器
int start_rpc_server() {
    int server_fd, client_fd;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len;
    char buffer[BUFFER_SIZE];
    char response[BUFFER_SIZE];
    
    // 创建套接字
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("无法创建套接字");
        return -1;
    }
    
    // 设置套接字选项
    int opt = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        perror("设置套接字选项失败");
        close(server_fd);
        return -1;
    }
    
    // 配置服务器地址
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(RPC_PORT);
    
    // 绑定地址
    if (bind(server_fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        perror("绑定套接字失败");
        close(server_fd);
        return -1;
    }
    
    // 监听连接
    if (listen(server_fd, 5) < 0) {
        perror("监听失败");
        close(server_fd);
        return -1;
    }
    
    printf("模拟RPC服务器已启动，监听端口 %d\n", RPC_PORT);
    printf("可以使用以下命令测试:\n");
    printf("  echo 'status' | nc localhost %d\n", RPC_PORT);
    printf("  echo 'normal' | nc localhost %d\n", RPC_PORT);
    printf("  echo 'reset'  | nc localhost %d\n", RPC_PORT);
    printf("  echo 'dfu'    | nc localhost %d\n", RPC_PORT);
    
    // 主循环
    while (running) {
        // 接受连接
        client_len = sizeof(client_addr);
        client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_len);
        
        if (client_fd < 0) {
            perror("接受连接失败");
            continue;
        }
        
        printf("接受来自 %s:%d 的连接\n", 
               inet_ntoa(client_addr.sin_addr), ntohs(client_addr.sin_port));
        
        // 接收命令
        memset(buffer, 0, BUFFER_SIZE);
        int n = read(client_fd, buffer, BUFFER_SIZE - 1);
        if (n < 0) {
            perror("读取数据失败");
            close(client_fd);
            continue;
        }
        
        buffer[n] = '\0';
        
        // 处理命令
        memset(response, 0, BUFFER_SIZE);
        handle_command(buffer, response);
        
        // 发送响应
        if (write(client_fd, response, strlen(response)) < 0) {
            perror("发送响应失败");
        }
        
        // 关闭连接
        close(client_fd);
    }
    
    // 关闭服务器套接字
    close(server_fd);
    return 0;
}

int main() {
    // 设置信号处理
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    printf("GPIO守护进程模拟测试程序\n");
    printf("这个程序模拟GPIO守护进程的RPC接口，用于测试\n");
    printf("按Ctrl+C退出\n\n");
    
    // 启动RPC服务器
    if (start_rpc_server() < 0) {
        printf("RPC服务器启动失败，退出\n");
        exit(EXIT_FAILURE);
    }
    
    printf("模拟测试程序正在退出\n");
    
    return EXIT_SUCCESS;
} 