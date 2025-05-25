二、安装并配置 TightVNC 服务器
安装 TightVNC Server：

bash
Copy
Edit
sudo apt install tightvncserver -y
DigitalOcean

初次运行并设置 VNC 访问密码：

bash
Copy
Edit
vncserver :1
系统会提示输入并确认 6–8 位 VNC 密码。 
DigitalOcean
在提示是否要创建view-only的密码时选择否
Would you like to enter a view-only password (y/n)? n

停止当前 VNC 会话以修改启动脚本：

bash
Copy
Edit
vncserver -kill :1
DigitalOcean

备份并编辑 ~/.vnc/xstartup，内容改为：

bash
Copy
Edit
mv ~/.vnc/xstartup ~/.vnc/xstartup.bak
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/sh
xrdb $HOME/.Xresources
startlxde &
EOF
chmod +x ~/.vnc/xstartup
DigitalOcean

重启 VNC 会话，绑定到本机接口：

bash
Copy
Edit
vncserver -localhost :1
