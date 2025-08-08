#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#define BUFFER_SIZE 1024

static int send_command(const char *host, const char *port, const char *cmd, char *response, size_t response_len) {
    struct addrinfo hints;
    struct addrinfo *result = NULL, *rp = NULL;
    int sockfd = -1;
    int ret = -1;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;      // 支持IPv4/IPv6
    hints.ai_socktype = SOCK_STREAM;  // TCP

    int s = getaddrinfo(host, port, &hints, &result);
    if (s != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(s));
        return -1;
    }

    for (rp = result; rp != NULL; rp = rp->ai_next) {
        sockfd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (sockfd == -1) continue;
        if (connect(sockfd, rp->ai_addr, rp->ai_addrlen) == 0) break; // 成功
        close(sockfd);
        sockfd = -1;
    }

    if (rp == NULL) {
        fprintf(stderr, "无法连接到 %s:%s\n", host, port);
        goto cleanup;
    }

    // 发送命令（不带换行）
    size_t cmd_len = strlen(cmd);
    if (send(sockfd, cmd, cmd_len, 0) != (ssize_t)cmd_len) {
        fprintf(stderr, "发送命令失败: %s\n", strerror(errno));
        goto cleanup;
    }

    // 接收响应
    if (response && response_len > 0) {
        ssize_t n = recv(sockfd, response, response_len - 1, 0);
        if (n < 0) {
            fprintf(stderr, "接收响应失败: %s\n", strerror(errno));
            goto cleanup;
        }
        response[n] = '\0';
    }

    ret = 0;

cleanup:
    if (sockfd != -1) close(sockfd);
    if (result) freeaddrinfo(result);
    return ret;
}

static void print_usage(const char *prog) {
    fprintf(stderr,
            "用法: %s [-H host] [-p port] [-c command] [-A]\n"
            "  -H host     服务器地址，默认: localhost\n"
            "  -p port     服务器端口，默认: 8888\n"
            "  -c command  直接发送命令(status|normal|reset|dfu|test|test_exit)\n"
            "  -A          运行自动测试序列\n"
            "不带 -c/-A 进入交互模式，输入 exit 退出。\n",
            prog);
}

static void run_auto_test(const char *host, const char *port) {
    const char *sequence[] = {
        "status",
        "normal",
        "reset",
        "dfu",
        "normal",
        "test",
        "status",
        "test_exit",
        "status",
    };
    char resp[BUFFER_SIZE];

    printf("开始自动测试...\n");
    for (size_t i = 0; i < sizeof(sequence)/sizeof(sequence[0]); ++i) {
        const char *cmd = sequence[i];
        if (send_command(host, port, cmd, resp, sizeof(resp)) == 0) {
            printf("命令: %-10s => 响应: %s\n", cmd, resp);
        } else {
            printf("命令: %-10s => 发送失败\n", cmd);
        }
        usleep(300 * 1000); // 300ms 间隔
    }
    printf("自动测试完成。\n");
}

static void run_interactive(const char *host, const char *port) {
    char line[BUFFER_SIZE];
    char resp[BUFFER_SIZE];

    printf("进入交互模式。可用命令: status, normal, reset, dfu, test, test_exit, exit\n");
    while (1) {
        printf("> ");
        fflush(stdout);
        if (!fgets(line, sizeof(line), stdin)) break;
        // 去除换行
        size_t len = strlen(line);
        while (len && (line[len-1] == '\n' || line[len-1] == '\r')) {
            line[--len] = '\0';
        }
        if (len == 0) continue;
        if (strcmp(line, "exit") == 0 || strcmp(line, "quit") == 0) break;

        if (send_command(host, port, line, resp, sizeof(resp)) == 0) {
            printf("响应: %s\n", resp);
        } else {
            printf("发送失败\n");
        }
    }
}

int main(int argc, char **argv) {
    const char *host = "localhost";
    const char *port = "8888";
    const char *command = NULL;
    int auto_mode = 0;

    int opt;
    while ((opt = getopt(argc, argv, "H:p:c:A")) != -1) {
        switch (opt) {
            case 'H': host = optarg; break;
            case 'p': port = optarg; break;
            case 'c': command = optarg; break;
            case 'A': auto_mode = 1; break;
            default:
                print_usage(argv[0]);
                return EXIT_FAILURE;
        }
    }

    if (auto_mode) {
        run_auto_test(host, port);
        return EXIT_SUCCESS;
    }

    if (command) {
        char resp[BUFFER_SIZE];
        if (send_command(host, port, command, resp, sizeof(resp)) == 0) {
            printf("%s\n", resp);
            return EXIT_SUCCESS;
        } else {
            return EXIT_FAILURE;
        }
    }

    run_interactive(host, port);
    return EXIT_SUCCESS;
} 