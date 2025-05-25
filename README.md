## 因为服务器没有界面，此脚本是为ubuntu服务器安装远程桌面，然后使用vnc连接，
### 此脚本已经在ubuntu20.04和22.04上测试通过
## 📦 Installation Guide 

## 一，安装桌面
直接执行install.sh 

    bash install.sh

所有的弹出的安装菜单都使用默认配置，不更改任何设置。    
安装脚本执行完毕后机器会重启。

## 二、安装并配置 TightVNC 服务器

安装 TightVNC Server：

    sudo apt install tightvncserver -y

初次运行并设置 VNC 访问密码：

    vncserver :1
系统会提示输入并确认 6–8 位 VNC 密码。 
在提示是否要创建view-only的密码时选择否

    Would you like to enter a view-only password (y/n)? n

停止当前 VNC 会话以修改启动脚本：

    vncserver -kill :1

备份并编辑 ~/.vnc/xstartup，内容改为：

    #!/bin/sh
    xrdb $HOME/.Xresources
    startlxde &

修改此文件权限以便于执行

    chmod +x ~/.vnc/xstartup

重启 VNC 会话，绑定到本机接口：

    vncserver -localhost :1

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
    RealVNC Connect 
    MobaXterm 
