# xssh - SSH 快速连接管理器
# 完全兼容 SSH config 格式，与 VSCode Remote SSH 兼容
# 使用方法: .\xssh.ps1 [服务器名称]

$ConfigFile = Join-Path $env:USERPROFILE ".ssh\config"

# ============================================================================
# 辅助函数
# ============================================================================

# 显示帮助信息
function Show-Help {
    Write-Host @"
xssh - SSH 快速连接管理器

用法:
  .\xssh.ps1 [Host别名]            # 连接到指定服务器
  .\xssh.ps1 -l, --list            # 列出所有可用服务器
  .\xssh.ps1 -n, --number <序号>   # 按列表序号连接服务器
  .\xssh.ps1 -a, --add             # 添加新服务器
  .\xssh.ps1 -e, --edit            # 编辑配置文件
  .\xssh.ps1 -c, --copy            # 复制Host别名到剪贴板
  .\xssh.ps1 -v, --verify          # 验证配置文件
  .\xssh.ps1 -i, --info            # 显示配置信息
  .\xssh.ps1 -h, --help            # 显示帮助信息

特点:
  • 完全兼容 SSH config 格式
  • 与 VSCode Remote SSH 共用同一配置
  • 标准 SSH 命令行工具兼容

示例:
  .\xssh.ps1 web-server-1          # 连接到 web-server-1
  .\xssh.ps1 -n 1                  # 连接列表中的第 1 个服务器
  .\xssh.ps1 -l                    # 列出所有服务器
  .\xssh.ps1 -a                    # 添加新服务器
  .\xssh.ps1 -c web-server-1       # 复制连接命令

"@
}

# 检查配置文件是否存在
function Check-Config {
    if (-not (Test-Path $ConfigFile)) {
        $dir = Split-Path $ConfigFile -Parent
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        New-Item -ItemType File -Path $ConfigFile -Force | Out-Null
        Set-SecurePermission $ConfigFile
        Write-Host "✓ 已创建 SSH 配置文件: $ConfigFile"
    }
}

# 设置文件权限为仅当前用户可访问 (等同于 chmod 600)
function Set-SecurePermission {
    param([string]$FilePath)
    try {
        # 移除继承的权限
        $acl = Get-Acl $FilePath
        $acl.SetAccessRuleProtection($true, $false)
        # 为当前用户添加完全控制权限
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
        $acl.AddAccessRule($rule)
        Set-Acl -Path $FilePath -AclObject $acl
    }
    catch {
        # 如果设置失败（例如在非NTFS格式盘），静默忽略
    }
}

# 从 SSH config 中解析所有 Host
function Get-Hosts {
    Check-Config
    $lines = Get-Content $ConfigFile -ErrorAction SilentlyContinue
    $hosts = @()
    foreach ($line in $lines) {
        $trimmedLine = $line.Trim()
        if ($trimmedLine.StartsWith("Host ")) {
            # 使用 split 提取，避免 $Matches 哈希表类型引发的错误
            $parts = $trimmedLine -split '\s+', 2
            if ($parts.Length -ge 2) {
                $hostAlias = $parts[1].Trim()
                if ($hostAlias -ne '*') {
                    $hosts += $hostAlias
                }
            }
        }
    }
    return $hosts
}

# 解析特定 Host 的配置
function Parse-HostConfig {
    param([string]$HostAlias)
    
    Check-Config
    
    $inHost = $false
    $hostname = ""
    $user = $env:USERNAME
    $port = "22"
    $identityFile = ""
    $strictCheck = ""

    $lines = Get-Content $ConfigFile
    foreach ($line in $lines) {
        $trimmedLine = $line.Trim()
        
        # 跳过注释和空行
        if ($trimmedLine.StartsWith('#') -or [string]::IsNullOrWhiteSpace($trimmedLine)) {
            continue
        }
        
        # 检查是否是新的 Host 块
        if ($trimmedLine.StartsWith("Host ")) {
            if ($inHost) {
                break # 已经离开目标 Host
            }
            $parts = $trimmedLine -split '\s+', 2
            $checkHost = if ($parts.Length -ge 2) { $parts[1].Trim() } else { "" }
            if ($checkHost -eq $HostAlias) {
                $inHost = $true
            }
            continue
        }
        
        # 只处理目标 Host 内的配置
        if ($inHost) {
            $parts = $trimmedLine -split '\s+', 2
            $key = $parts[0].Trim()
            $value = if ($parts.Length -gt 1) { $parts[1].Trim() } else { "" }
            
            switch ($key) {
                "HostName" { $hostname = $value }
                "User"     { $user = $value }
                "Port"     { $port = $value }
                "IdentityFile" { $identityFile = $value }
                "StrictHostKeyChecking" { $strictCheck = $value }
            }
        }
    }
    
    # 验证必需的配置
    if ([string]::IsNullOrWhiteSpace($hostname)) {
        Write-Error "错误: 找不到 Host '$HostAlias' 或 HostName 未配置"
        return $null
    }
    
    return @{
        HostName      = $hostname
        Port          = $port
        User          = $user
        IdentityFile  = $identityFile
        StrictCheck   = $strictCheck
    }
}

# 列出所有服务器
function List-Servers {
    Check-Config
    
    $hosts = Get-Hosts
    if ($hosts.Count -eq 0) {
        Write-Host "没有配置任何 Host"
        return
    }
    
    Write-Host "可用的服务器:"
    Write-Host "────────────────────────────────────────────────────────────────"
    Write-Host ("  {0,-4}  {1,-20}  {2}@{3}:{4}" -f "序号", "Host别名", "用户", "主机", "端口")
    Write-Host "────────────────────────────────────────────────────────────────"
    
    $index = 1
    foreach ($h in $hosts) {
        $config = Parse-HostConfig $h
        if ($null -ne $config) {
            Write-Host ("  {0,-4}  {1,-20}  {2}@{3}:{4}" -f $index, $h, $config.User, $config.HostName, $config.Port)
        }
        $index++
    }
    Write-Host "────────────────────────────────────────────────────────────────"
}

# 按列表序号获取 Host（1-based）
function Get-HostByNumber {
    param([string]$Number)

    $hosts = @(Get-Hosts)
    if ($hosts.Count -eq 0) {
        Write-Error "没有配置任何 Host"
        return $null
    }

    $index = 0
    if (-not [int]::TryParse($Number, [ref]$index) -or $index -lt 1) {
        Write-Error "错误: 序号必须是大于 0 的整数"
        return $null
    }

    if ($index -gt $hosts.Count) {
        Write-Error "错误: 序号 $index 超出范围，可用范围: 1-$($hosts.Count)"
        return $null
    }

    return $hosts[$index - 1]
}

# 添加新服务器（交互式）
function Add-Server {
    Check-Config
    
    Write-Host "添加新 Host"
    $hostAlias = Read-Host "Host 别名 (如: web-server-1)"
    
    if ([string]::IsNullOrWhiteSpace($hostAlias)) {
        Write-Error "错误: Host 别名不能为空"
        return
    }
    
    # 检查是否已存在
    $existing = Get-Hosts
    if ($existing -contains $hostAlias) {
        Write-Error "错误: Host '$hostAlias' 已存在"
        return
    }
    
    $hostnameInput = Read-Host "主机名/IP (HostName)"
    $userInput = Read-Host "用户名 (User, 默认 $env:USERNAME)"
    $portInput = Read-Host "端口 (Port, 默认 22)"
    $idFileInput = Read-Host "私钥路径 (IdentityFile, 可选)"
    
    if ([string]::IsNullOrWhiteSpace($userInput)) { $userInput = $env:USERNAME }
    if ([string]::IsNullOrWhiteSpace($portInput)) { $portInput = "22" }
    
    # 追加到配置文件
    $content = @(
        "",
        "Host $hostAlias",
        "    HostName $hostnameInput",
        "    User $userInput",
        "    Port $portInput"
    )
    if (-not [string]::IsNullOrWhiteSpace($idFileInput)) {
        $content += "    IdentityFile $idFileInput"
    }
    
    Add-Content -Path $ConfigFile -Value ($content -join "`r`n")
    Set-SecurePermission $ConfigFile
    
    Write-Host "✓ Host '$hostAlias' 已添加"
    Write-Host "提示: 现在可以用 '.\xssh.ps1 $hostAlias' 连接"
}

# 编辑配置文件
function Edit-Config {
    Check-Config
    
    Write-Host "正在打开 SSH 配置文件..."
    
    # 优先尝试使用 psEdit (适配 VSCode / PowerShell ISE)
    if (Get-Command 'psEdit' -ErrorAction SilentlyContinue) {
        psEdit $ConfigFile
    }
    # 否则使用系统默认关联程序打开
    else {
        Invoke-Item $ConfigFile
    }
    
    # 确保权限正确
    Set-SecurePermission $ConfigFile
}

# 复制连接命令到剪贴板
function Copy-ToClipboard {
    param([string]$HostAlias)
    
    $config = Parse-HostConfig $HostAlias
    if ($null -eq $config) {
        return
    }
    
    $cmd = "ssh $HostAlias"
    
    # PowerShell 原生剪贴板支持
    Set-Clipboard -Value $cmd
    Write-Host "✓ 已复制到剪贴板: $cmd"
}

# 连接到服务器
function Connect-Server {
    param([string]$HostAlias)
    
    $config = Parse-HostConfig $HostAlias
    if ($null -eq $config) {
        Write-Host "可用的 Host:" -ForegroundColor Red
        List-Servers
        return
    }
    
    Write-Host "正在连接..."
    Write-Host "Host: $HostAlias ($($config.User)@$($config.HostName):$($config.Port))"
    Write-Host ""
    
    # 使用 SSH 连接，让 SSH 读取配置文件处理所有细节
    # 使用 cmd /c 确保 ssh 进程接管标准输入输出流，支持交互式会话
    cmd /c "ssh $HostAlias"
}

# 验证配置文件格式
function Verify-Config {
    Check-Config
    
    $hosts = Get-Hosts
    if ($hosts.Count -eq 0) {
        Write-Host "配置文件为空，还没有定义任何 Host"
        return
    }
    
    Write-Host "验证 SSH 配置..."
    
    $errorCount = 0
    foreach ($h in $hosts) {
        $config = Parse-HostConfig $h
        if ($null -eq $config) {
            Write-Host "✗ Host '$h' 配置不完整"
            $errorCount++
        }
        else {
            $checkIdFile = $config.IdentityFile
            Write-Host -NoNewline "✓ $h`: "
            
            # 检查私钥文件
            if (-not [string]::IsNullOrWhiteSpace($checkIdFile)) {
                # 展开波浪号路径
                $expandedPath = $checkIdFile -replace '^~', $env:USERPROFILE
                if (Test-Path $expandedPath) {
                    Write-Host "OK (私钥存在)"
                }
                else {
                    Write-Host "警告: 私钥不存在 ($expandedPath)" -ForegroundColor Yellow
                    $errorCount++
                }
            }
            else {
                Write-Host "OK"
            }
        }
    }
    
    if ($errorCount -eq 0) {
        Write-Host "✓ 配置验证通过"
    }
    else {
        Write-Host "✗ 发现 $errorCount 个问题"
    }
}

# 显示配置文件信息
function Show-Info {
    Write-Host "SSH 配置信息"
    Write-Host "─────────────────────────────────"
    Write-Host "配置文件: $ConfigFile"
    
    if (Test-Path $ConfigFile) {
        $acl = Get-Acl $ConfigFile
        $access = $acl.Access | Where-Object { $_.IdentityReference -match $env:USERNAME } | Select-Object -First 1
        $permStr = if ($access) { $access.FileSystemRights.ToString() } else { "未知" }
        Write-Host "权限: $permStr (仅当前用户)"
        Write-Host "已配置 Host 数: $((Get-Hosts).Count)"
    }
    else {
        Write-Host "状态: 文件不存在"
    }
    
    Write-Host "─────────────────────────────────"
}

# ============================================================================
# 主程序
# ============================================================================

function Main {
    param([string[]]$Arguments)
    
    if ($Arguments.Count -eq 0) {
        Show-Help
        return
    }
    
    # 获取第一个参数作为操作指令
    $Command = $Arguments[0]
    
    switch ($Command) {
        "-h" { Show-Help }
        "--help" { Show-Help }
        "-l" { List-Servers }
        "--list" { List-Servers }
        "-n" {
            if ($Arguments.Count -lt 2) {
                Write-Error "错误: 请指定服务器序号"
                Write-Error "用法: .\xssh.ps1 -n <序号>"
            } else {
                $hostAlias = Get-HostByNumber $Arguments[1]
                if ($null -eq $hostAlias) {
                    List-Servers
                    return
                }
                Connect-Server $hostAlias
            }
        }
        "--number" {
            if ($Arguments.Count -lt 2) {
                Write-Error "错误: 请指定服务器序号"
                Write-Error "用法: .\xssh.ps1 -n <序号>"
            } else {
                $hostAlias = Get-HostByNumber $Arguments[1]
                if ($null -eq $hostAlias) {
                    List-Servers
                    return
                }
                Connect-Server $hostAlias
            }
        }
        "-a" { Add-Server }
        "--add" { Add-Server }
        "-e" { Edit-Config }
        "--edit" { Edit-Config }
        
        "-c" {
            if ($Arguments.Count -lt 2) {
                Write-Error "错误: 请指定 Host 别名"
                Write-Error "用法: .\xssh.ps1 -c <Host别名>"
            } else {
                Copy-ToClipboard $Arguments[1]
            }
        }
        "--copy" {
            if ($Arguments.Count -lt 2) {
                Write-Error "错误: 请指定 Host 别名"
                Write-Error "用法: .\xssh.ps1 -c <Host别名>"
            } else {
                Copy-ToClipboard $Arguments[1]
            }
        }
        
        "-v" { Verify-Config }
        "--verify" { Verify-Config }
        "-i" { Show-Info }
        "--info" { Show-Info }
        
        # 默认情况：作为 Host 别名进行连接
        default { Connect-Server $Command }
    }
}

# 执行主程序并传入所有命令行参数
Main $args
