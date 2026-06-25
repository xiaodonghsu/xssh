# xssh

`xssh` / `xssh.ps1` 是 SSH 快速连接管理脚本，用来管理和连接 SSH config 中的 Host。

项目包含两个版本：

- `xssh.ps1`：PowerShell 版本，主要用于 Windows。
- `xssh`：Bash 版本，主要用于 Linux / macOS / WSL。

它不维护独立配置文件，而是直接读取和写入当前用户的 SSH 配置。

PowerShell 版本使用：

```text
%USERPROFILE%\.ssh\config
```

Bash 版本使用：

```text
$HOME/.ssh/config
```

因此它与 OpenSSH、VSCode Remote SSH 等使用同一份配置。

## 功能

- 列出 `~/.ssh/config` 中配置的所有 Host
- 通过 Host 别名快速连接服务器
- 通过列表序号连接服务器
- 交互式添加新的 SSH Host
- 打开 SSH config 进行编辑
- 复制 `ssh <Host>` 命令到剪贴板
- 验证 Host 配置和私钥文件是否存在
- 自动识别包含 `LocalForward` 的 Host，并以隧道模式运行
- 隧道模式下使用 `ssh -N -T <Host>`，ssh 退出后 10 秒自动重连
- 查看 SSH config 路径、权限和 Host 数量
- 自动创建缺失的 `~/.ssh/config`
- 尝试将 SSH config 权限设置为仅当前用户可访问

## 使用要求

PowerShell 版本：

- Windows PowerShell 或 PowerShell 7+
- 系统已安装 `ssh` 命令
- 当前用户可以访问 `%USERPROFILE%\.ssh\config`

Bash 版本：

- Bash
- 系统已安装 `ssh` 命令
- 当前用户可以访问 `$HOME/.ssh/config`

## 快速开始

查看帮助：

```powershell
.\xssh.ps1 -h
```

Bash：

```bash
./xssh -h
```

列出所有服务器：

```powershell
.\xssh.ps1 -l
```

连接指定 Host：

```powershell
.\xssh.ps1 web-server-1
```

或：

```bash
./xssh web-server-1
```

按列表序号连接：

```powershell
.\xssh.ps1 -n 1
```

## 命令

| 命令 | 说明 |
| --- | --- |
| `.\xssh.ps1 <Host别名>` | 连接到指定 Host |
| `.\xssh.ps1 -l` / `--list` | 列出所有可用服务器 |
| `.\xssh.ps1 -n <序号>` / `--number <序号>` | 按列表序号连接服务器 |
| `.\xssh.ps1 -a` / `--add` | 交互式添加新服务器 |
| `.\xssh.ps1 -e` / `--edit` | 编辑 SSH 配置文件 |
| `.\xssh.ps1 -c <Host别名>` / `--copy <Host别名>` | 复制连接命令到剪贴板 |
| `.\xssh.ps1 -v` / `--verify` | 验证 SSH 配置 |
| `.\xssh.ps1 -i` / `--info` | 显示配置文件信息 |
| `.\xssh.ps1 -h` / `--help` | 显示帮助 |

Bash 版本命令相同，只需将 `.\xssh.ps1` 替换为 `./xssh` 或安装后的 `xssh`。

## SSH Config 示例

脚本使用标准 SSH config 格式：

```sshconfig
Host web-server-1
    HostName 192.168.1.10
    User root
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host app-server
    HostName app.example.com
    User deploy
    Port 2222

Host rdp-tunnel
    HostName jump.example.com
    User tunnel
    Port 22
    IdentityFile ~/.ssh/id_rsa
    LocalForward 127.0.0.1:13389 10.0.0.20:3389
```

添加上述配置后，可以直接运行：

```powershell
.\xssh.ps1 web-server-1
.\xssh.ps1 app-server
.\xssh.ps1 rdp-tunnel
```

也可以继续使用标准 SSH 命令：

```powershell
ssh web-server-1
```

## LocalForward 隧道模式

如果目标 Host 配置了 `LocalForward`，脚本会在连接前打印所有 `LocalForward` 参数，然后以隧道模式启动 SSH：

```powershell
ssh -N -T <Host别名>
```

其中：

- `-N`：不执行远程命令，只建立连接和端口转发。
- `-T`：不分配伪终端，适合隧道连接。

隧道模式会持续运行。如果 ssh 进程退出，脚本会等待 10 秒后自动重连：

```text
2026-06-25 09:30:00 starting ssh tunnel...
2026-06-25 09:45:00 ssh tunnel exited, retry in 10 seconds...
```

停止隧道请在终端中按 `Ctrl+C`。

## 添加服务器

运行：

```powershell
.\xssh.ps1 -a
```

脚本会依次提示输入：

- `Host` 别名
- `HostName` 主机名或 IP
- `User` 用户名，默认当前 Windows 用户名
- `Port` 端口，默认 `22`
- `IdentityFile` 私钥路径，可选

添加完成后，配置会追加到 `%USERPROFILE%\.ssh\config`。

## 验证配置

运行：

```powershell
.\xssh.ps1 -v
```

验证内容包括：

- Host 是否配置了 `HostName`
- 已配置的 `IdentityFile` 私钥文件是否存在

注意：验证不会测试网络连通性，也不会实际登录服务器。

## 编辑配置

运行：

```powershell
.\xssh.ps1 -e
```

脚本会优先使用 `psEdit` 打开配置文件，适用于 VSCode / PowerShell ISE 环境；如果不可用，则使用系统默认关联程序打开。

## 工作方式

普通连接时，脚本不会手动拼接完整 SSH 参数，而是执行：

```powershell
ssh <Host别名>
```

这样可以让 OpenSSH 自己读取 `~/.ssh/config`，并继续支持 SSH config 中的标准选项，例如 `ProxyJump`、`ForwardAgent`、`LocalForward`、`ServerAliveInterval` 等。

包含 `LocalForward` 的 Host 会自动切换为：

```powershell
ssh -N -T <Host别名>
```

## 注意事项

- `Host *` 会被列表功能忽略。
- Host 别名需要与 `Host` 行完全匹配。
- 当前脚本只解析并展示 `HostName`、`User`、`Port`、`IdentityFile`、`StrictHostKeyChecking` 和 `LocalForward` 等常用字段。
- 其它 SSH config 字段仍会由 `ssh` 命令正常处理。
- 如果 `~/.ssh/config` 不存在，脚本会自动创建空文件。
