/**
 * gpio_daemon.c - GPIO守护进程，用于控制单片机的复位和DFU模式
 * 
 * 功能：
 * 1. 作为守护进程运行，维持GPIO引脚状态
 * 2. 提供RPC接口，允许远程控制三种状态：
 *    - 进入DFU模式
 *    - 复位单片机
 *    - 正常运行状态
 * 
 * 编译：gcc -Wall -o gpio_daemon gpio_daemon.c -lgpiod
 * 运行：sudo ./gpio_daemon
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>
#include <syslog.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <gpiod.h>
#include <pthread.h> // 添加pthread头文件

/* 定义GPIO引脚 */
#define PH40_RESET_PIN 106  // 复位引脚
#define PH40_BOOT_PIN  41  // BOOT引脚

/* 定义状态 */
#define STATE_NORMAL   0   // 正常运行状态
#define STATE_RESET    1   // 复位状态
#define STATE_DFU      2   // DFU模式状态
#define STATE_TEST     3   // 测试模式状态 - 每3秒跳变一次

/* 引脚状态定义 */
#define RESET_PIN_TRIGGER_STATE 1   // 复位引脚触发状态
#define DFU_MODE_TRIGGER_STATE  0   // DFU模式触发状态

/* RPC相关定义 */
#define RPC_PORT 8888
#define BUFFER_SIZE 1024

/* GPIO相关定义 */
#define CONSUMER "gpio_daemon"  // 使用者标识
#define GPIOCHIP "gpiochip0"    // GPIO芯片名称

/* 全局变量 */
static volatile int running = 1;
static int current_state = STATE_NORMAL;
static struct gpiod_chip *chip = NULL;
static struct gpiod_line *reset_line = NULL;
static struct gpiod_line *boot_line = NULL;

/* 函数前向声明 */
void signal_handler(int signo);
void daemonize();
int init_gpio();
void set_normal_state();
void reset_mcu();
void enter_dfu_mode();
void enter_test_mode();
void exit_test_mode();
void *test_mode_thread(void *arg);
void handle_command(char *cmd, char *response);
int start_rpc_server();

/**
 * 信号处理函数
 */
void signal_handler(int signo) {
    if (signo == SIGINT || signo == SIGTERM) {
        syslog(LOG_NOTICE, "接收到终止信号，准备退出...");
        running = 0;
    }
}

/**
 * 设置为守护进程
 */
void daemonize() {
    pid_t pid;
    
    /* 创建子进程 */
    pid = fork();
    
    /* 创建失败 */
    if (pid < 0) {
        perror("fork");
        exit(EXIT_FAILURE);
    }
    
    /* 父进程退出 */
    if (pid > 0) {
        exit(EXIT_SUCCESS);
    }
    
    /* 子进程继续 */
    
    /* 创建新会话并设置为会话首进程 */
    if (setsid() < 0) {
        perror("setsid");
        exit(EXIT_FAILURE);
    }
    
    /* 忽略SIGHUP信号 */
    signal(SIGHUP, SIG_IGN);
    
    /* 再次fork，确保进程不是会话首进程 */
    pid = fork();
    
    if (pid < 0) {
        perror("fork");
        exit(EXIT_FAILURE);
    }
    
    if (pid > 0) {
        exit(EXIT_SUCCESS);
    }
    
    /* 更改工作目录 */
    chdir("/");
    
    /* 关闭所有文件描述符 */
    for (int i = 0; i < 1024; i++) {
        close(i);
    }
    
    /* 重定向标准输入输出到/dev/null */
    open("/dev/null", O_RDONLY);
    open("/dev/null", O_WRONLY);
    open("/dev/null", O_WRONLY);
    
    /* 初始化日志系统 */
    openlog("gpio_daemon", LOG_PID, LOG_DAEMON);
}

/**
 * 初始化GPIO
 */
int init_gpio() {
    /* 打开GPIO芯片 */
    chip = gpiod_chip_open_by_name(GPIOCHIP);
    if (!chip) {
        syslog(LOG_ERR, "无法打开GPIO芯片: %s", strerror(errno));
        return -1;
    }
    
    /* 获取复位引脚 */
    reset_line = gpiod_chip_get_line(chip, PH40_RESET_PIN);
    if (!reset_line) {
        syslog(LOG_ERR, "无法获取复位引脚: %s", strerror(errno));
        gpiod_chip_close(chip);
        return -1;
    }
    
    /* 获取BOOT引脚 */
    boot_line = gpiod_chip_get_line(chip, PH40_BOOT_PIN);
    if (!boot_line) {
        syslog(LOG_ERR, "无法获取BOOT引脚: %s", strerror(errno));
        gpiod_chip_close(chip);
        return -1;
    }
    
    /* 设置引脚为输出模式 */
    if (gpiod_line_request_output(reset_line, CONSUMER, 0) < 0) {
        syslog(LOG_ERR, "设置复位引脚为输出模式失败: %s", strerror(errno));
        gpiod_chip_close(chip);
        return -1;
    }
    
    if (gpiod_line_request_output(boot_line, CONSUMER, 0) < 0) {
        syslog(LOG_ERR, "设置BOOT引脚为输出模式失败: %s", strerror(errno));
        gpiod_line_release(reset_line);
        gpiod_chip_close(chip);
        return -1;
    }
    
    /* 设置初始状态为正常运行状态 */
    set_normal_state();
    
    return 0;
}

/**
 * 设置为正常运行状态
 * BOOT引脚输出高电平，RST引脚输出低电平
 */
void set_normal_state() {
    gpiod_line_set_value(boot_line, !DFU_MODE_TRIGGER_STATE);  // BOOT引脚高电平
    gpiod_line_set_value(reset_line, !RESET_PIN_TRIGGER_STATE); // RST引脚低电平
    current_state = STATE_NORMAL;
    syslog(LOG_INFO, "设置为正常运行状态");
}

/**
 * 复位单片机
 * 将RESET_PIN拉低300ms然后恢复
 */
void reset_mcu() {
    syslog(LOG_INFO, "执行单片机复位...");
    
    /* 保存当前状态 */
    int old_state = current_state;
    
    /* 设置RESET_PIN为触发状态 */
    gpiod_line_set_value(reset_line, RESET_PIN_TRIGGER_STATE);
    current_state = STATE_RESET;
    
    /* 延时300ms */
    usleep(300000);
    
    /* 恢复到之前的状态 */
    if (old_state == STATE_NORMAL) {
        set_normal_state();
    } else {
        /* 如果之前是DFU模式，则恢复到DFU模式 */
        enter_dfu_mode();
    }
    
    syslog(LOG_INFO, "单片机复位完成");
}

/**
 * 进入DFU模式
 */
void enter_dfu_mode() {
    syslog(LOG_INFO, "执行进入DFU模式...");
    
    /* 设置BOOT_PIN为DFU模式触发状态 */
    gpiod_line_set_value(boot_line, DFU_MODE_TRIGGER_STATE);
    
    /* 设置RESET_PIN为触发状态 */
    gpiod_line_set_value(reset_line, RESET_PIN_TRIGGER_STATE);
    
    /* 延时100ms */
    usleep(100000);
    
    /* 将RESET_PIN设置为非触发状态 */
    gpiod_line_set_value(reset_line, !RESET_PIN_TRIGGER_STATE);
    
    /* 延时100ms */
    usleep(100000);
    
    /* 保持BOOT_PIN为DFU模式触发状态 */
    gpiod_line_set_value(boot_line, DFU_MODE_TRIGGER_STATE);
    
    current_state = STATE_DFU;
    syslog(LOG_INFO, "DFU模式设置完成");
}

/**
 * 进入测试模式 - 每3秒跳变一次
 * 此函数会启动一个新线程来执行跳变操作
 */
pthread_t test_thread = 0;
volatile int test_running = 0;

void *test_mode_thread(void *arg) {
    syslog(LOG_INFO, "测试模式线程启动");
    
    while (test_running) {
        /* 设置BOOT_PIN和RESET_PIN为高电平 */
        gpiod_line_set_value(boot_line, 1);
        gpiod_line_set_value(reset_line, 1);
        syslog(LOG_INFO, "测试模式: 引脚设置为高电平");
        
        /* 延时3秒 */
        sleep(3);
        
        if (!test_running) break;
        
        /* 设置BOOT_PIN和RESET_PIN为低电平 */
        gpiod_line_set_value(boot_line, 0);
        gpiod_line_set_value(reset_line, 0);
        syslog(LOG_INFO, "测试模式: 引脚设置为低电平");
        
        /* 延时3秒 */
        sleep(3);
    }
    
    syslog(LOG_INFO, "测试模式线程退出");
    return NULL;
}

void enter_test_mode() {
    syslog(LOG_INFO, "执行进入测试模式...");
    
    /* 如果已经在测试模式，先退出 */
    if (current_state == STATE_TEST) {
        exit_test_mode();
    }
    
    /* 设置测试运行标志 */
    test_running = 1;
    
    /* 创建测试线程 */
    if (pthread_create(&test_thread, NULL, test_mode_thread, NULL) != 0) {
        syslog(LOG_ERR, "创建测试线程失败: %s", strerror(errno));
        return;
    }
    
    current_state = STATE_TEST;
    syslog(LOG_INFO, "测试模式设置完成");
}

void exit_test_mode() {
    if (current_state != STATE_TEST) {
        return;
    }
    
    /* 停止测试线程 */
    if (test_thread) {
        test_running = 0;
        pthread_join(test_thread, NULL);
        test_thread = 0;
    }
    
    /* 恢复引脚状态 */
    set_normal_state();
    
    syslog(LOG_INFO, "退出测试模式");
}

/**
 * 处理RPC命令
 */
void handle_command(char *cmd, char *response) {
    if (strcmp(cmd, "status") == 0) {
        switch (current_state) {
            case STATE_NORMAL:
                strcpy(response, "STATUS:NORMAL");
                break;
            case STATE_RESET:
                strcpy(response, "STATUS:RESET");
                break;
            case STATE_DFU:
                strcpy(response, "STATUS:DFU");
                break;
            case STATE_TEST:
                strcpy(response, "STATUS:TEST");
                break;
            default:
                strcpy(response, "STATUS:UNKNOWN");
        }
    } else if (strcmp(cmd, "normal") == 0) {
        set_normal_state();
        strcpy(response, "OK:NORMAL");
    } else if (strcmp(cmd, "reset") == 0) {
        reset_mcu();
        strcpy(response, "OK:RESET");
    } else if (strcmp(cmd, "dfu") == 0) {
        enter_dfu_mode();
        strcpy(response, "OK:DFU");
    } else if (strcmp(cmd, "test") == 0) {
        enter_test_mode();
        strcpy(response, "OK:TEST");
    } else if (strcmp(cmd, "test_exit") == 0) {
        exit_test_mode();
        strcpy(response, "OK:TEST_EXIT");
    } else {
        strcpy(response, "ERROR:UNKNOWN_COMMAND");
    }
}

/**
 * 启动RPC服务器
 */
int start_rpc_server() {
    int server_fd, client_fd;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_len;
    char buffer[BUFFER_SIZE];
    char response[BUFFER_SIZE];
    
    /* 创建套接字 */
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        syslog(LOG_ERR, "无法创建套接字: %s", strerror(errno));
        return -1;
    }
    
    /* 设置套接字选项 */
    int opt = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        syslog(LOG_ERR, "设置套接字选项失败: %s", strerror(errno));
        close(server_fd);
        return -1;
    }
    
    /* 配置服务器地址 */
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(RPC_PORT);
    
    /* 绑定地址 */
    if (bind(server_fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        syslog(LOG_ERR, "绑定套接字失败: %s", strerror(errno));
        close(server_fd);
        return -1;
    }
    
    /* 监听连接 */
    if (listen(server_fd, 5) < 0) {
        syslog(LOG_ERR, "监听失败: %s", strerror(errno));
        close(server_fd);
        return -1;
    }
    
    syslog(LOG_NOTICE, "RPC服务器已启动，监听端口 %d", RPC_PORT);
    
    /* 设置非阻塞模式 */
    fcntl(server_fd, F_SETFL, O_NONBLOCK);
    
    /* 主循环 */
    while (running) {
        /* 接受连接 */
        client_len = sizeof(client_addr);
        client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_len);
        
        if (client_fd < 0) {
            if (errno != EAGAIN && errno != EWOULDBLOCK) {
                syslog(LOG_ERR, "接受连接失败: %s", strerror(errno));
            }
            usleep(100000);  // 100ms
            continue;
        }
        
        syslog(LOG_INFO, "接受来自 %s:%d 的连接", 
               inet_ntoa(client_addr.sin_addr), ntohs(client_addr.sin_port));
        
        /* 接收命令 */
        memset(buffer, 0, BUFFER_SIZE);
        int n = read(client_fd, buffer, BUFFER_SIZE - 1);
        if (n < 0) {
            syslog(LOG_ERR, "读取数据失败: %s", strerror(errno));
            close(client_fd);
            continue;
        }
        
        buffer[n] = '\0';
        syslog(LOG_INFO, "收到命令: %s", buffer);
        
        /* 处理命令 */
        memset(response, 0, BUFFER_SIZE);
        handle_command(buffer, response);
        
        /* 发送响应 */
        if (write(client_fd, response, strlen(response)) < 0) {
            syslog(LOG_ERR, "发送响应失败: %s", strerror(errno));
        }
        
        /* 关闭连接 */
        close(client_fd);
    }
    
    /* 关闭服务器套接字 */
    close(server_fd);
    return 0;
}

/**
 * 主函数
 */
int main(int argc, char *argv[]) {
    /* 检查是否以守护进程模式运行 */
    int daemon_mode = 1;
    
    /* 解析命令行参数 */
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "--foreground") == 0) {
            daemon_mode = 0;
        }
    }
    
    /* 设置信号处理 */
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    /* 以守护进程模式运行 */
    if (daemon_mode) {
        daemonize();
    } else {
        /* 初始化日志系统 */
        openlog("gpio_daemon", LOG_PID, LOG_USER);
    }
    
    syslog(LOG_NOTICE, "GPIO守护进程启动");
    
    /* 初始化GPIO */
    if (init_gpio() < 0) {
        syslog(LOG_ERR, "GPIO初始化失败，退出");
        closelog();
        exit(EXIT_FAILURE);
    }
    
    /* 启动RPC服务器 */
    if (start_rpc_server() < 0) {
        syslog(LOG_ERR, "RPC服务器启动失败，退出");
        if (reset_line)
            gpiod_line_release(reset_line);
        if (boot_line)
            gpiod_line_release(boot_line);
        if (chip)
            gpiod_chip_close(chip);
        closelog();
        exit(EXIT_FAILURE);
    }
    
    /* 清理资源 */
    syslog(LOG_NOTICE, "GPIO守护进程正在退出");
    if (current_state == STATE_TEST) {
        exit_test_mode();
    }
    if (reset_line)
        gpiod_line_release(reset_line);
    if (boot_line)
        gpiod_line_release(boot_line);
    if (chip)
        gpiod_chip_close(chip);
    closelog();
    
    return EXIT_SUCCESS;
} 