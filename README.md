## 因为服务器没有界面，此脚本是为ubuntu服务器安装远程桌面，然后使用vnc连接，
### 此脚本已经在ubuntu20.04和22.04上测试通过
## 📦 Installation Guide 

## 一，安装桌面
直接执行install.sh 

    bash install.sh

所有的弹出的安装菜单都使用默认配置，不更改任何设置。    
安装脚本执行完毕后让服务器重启。
重启命令

    reboot
    
## 二、安装并配置 TightVNC 服务器

安装 TightVNC Server：

    sudo apt install tightvncserver -y

安装XFCE

    sudo apt install -y xfce4 xfce4-goodies dbus-x11

添加用户，此处用户名为user1

    sudo adduser user1

在弹出所有问题中只需要设置好用户密码，其他问题一律默认即可

    New password: 
    Retype new password: 
    passwd: password updated successfully
    Changing the user information for user1
    Enter the new value, or press ENTER for the default
    	Full Name []: 
    	Room Number []: 
    	Work Phone []: 
    	Home Phone []: 
    	Other []: 
    Is the information correct? [Y/n] 

然后切换到用户，设置此用户下的vncserver。

    su - user1
    vncserver :1

第一次执行会提示设置 VNC 访问密码（不是登录密码）
在提示是否要创建view-only的密码时选择否

    Would you like to enter a view-only password (y/n)? n
    
记住这个密码，因为你用 RealVNC（其他VNC客户端一致） 连接时要输入
运行完之后先退出，然后编辑启动脚本：

    vncserver -kill :1

然后把 ~/.vnc/xstartup 改成下面这个（XFCE + dbus-run-session）：

    #!/bin/sh
    unset SESSION_MANAGER
    unset DBUS_SESSION_BUS_ADDRESS
    
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
    
    xrdb "$HOME/.Xresources"
    xsetroot -solid grey
    
    exec dbus-run-session startxfce4

修改此文件权限以便于执行

    chmod +x ~/.vnc/xstartup

启动桌面并绑定到指定接口比如

    vncserver :1 -geometry 1920x1080

此时，桌面以端口号5901启动登陆用户是user1，你使用realvnc连接的时候记得使用5901而不是端口号1.

### 三，连接vnc服务器桌面

在MacOS下使用realvnc连接服务器，端口号为5901，并不是1端口，密码为最开始设置的密码。 
realvnc已经测试通过，其他vnc软件并未测试，下列是候选的测试软件，你可以挑选你比较熟悉的。（来自chatgpt）。    

macOS 下的远程桌面（VNC/RDP）客户端

    RealVNC  
    TigerVNC  
    TeamViewer
    AnyDesk Remote Desktop for macOS 
    Splashtop Remote Desktop for Mac 
    Chrome Remote Desktop 
    Microsoft Remote Desktop for Mac 
    DWService 
    Lifewire
    RustDesk 
    TechRadar
    
Windows：

    RealVNC Viewer 
    VNC Viewer Plus
    TightVNC Viewer 
    UltraVNC Viewer 
    Remote Ripple 
    MightyViewer 

### 四，远程桌面图标，任务栏显示慢的问题解决办法

连接远程桌面以后可能会发现桌面的图标加载缓慢，这是由于
user1 从来没有经历过 systemd 的“真实登录会话”
（login / ssh / display-manager）
现在所有的操作，都是在 su 派生的“假用户会话”里。
在这种情况下：
systemd 不会 自动创建 /run/user/1000
dbus / polkit / dconf / gvfs / pulseaudio
👉 全部失去“运行时根目录”
XFCE 只能一边报错、一边 fallback
👉 表现就是：慢、延迟、polkit 报错
    RealVNC Connect 
    MobaXterm 
如果你执行下面的命令会得到如下结果：

    user1@localhost:~$ echo $XDG_RUNTIME_DIR
    
    user1@localhost:~$ ls -ld /run/user/1000
    ls: cannot access '/run/user/1000': No such file or directory

解决办法：  

不要使用root登陆服务器，直接使用user1登陆服务器

在本机执行：

    ssh user1@xxx.xxx.xxx.xxx

登录后检查:

    echo $XDG_RUNTIME_DIR
    ls -ld /run/user/1000

当你看到如下输出，代表正确：

    user1@localhost:~$ echo $XDG_RUNTIME_DIR
    /run/user/1000
    user1@localhost:~$ ls -ld /run/user/1000
    drwx------ 6 user1 user1 220 Jan 25 02:49 /run/user/1000

### 五，安装火狐浏览器

Snap 版 Firefox无法正确启动，因为此桌面为精简版，缺少firefox依赖的沙盒   
安装esr版本（以下命令可以在root下执行）：

    sudo add-apt-repository ppa:mozillateam/ppa
    sudo apt update
    sudo apt install firefox-esr

安装完成以后，在服务器的轻量化桌面上启动terminal，然后运行firefox-esr 








