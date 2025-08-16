FROM debian:bullseye

ARG NGROK_TOKEN
ARG REGION=ap
ENV DEBIAN_FRONTEND=noninteractive \
    VNC_PASSWORD=craxid

# Install dependencies + XFCE desktop + VNC
RUN apt update && apt upgrade -y && \
    apt install -y --no-install-recommends \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    firefox-esr \
    xfce4-terminal \
    gedit \
    thunar \
    wget unzip curl python3 \
    openssh-server

# Install ngrok
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O /ngrok.zip \
    && unzip /ngrok.zip -d / \
    && chmod +x /ngrok

# Setup VNC password
RUN mkdir -p /root/.vnc
RUN echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd \
    && chmod 600 /root/.vnc/passwd

# Create VNC startup script
RUN echo "#!/bin/sh" > /root/.vnc/xstartup \
    && echo "unset SESSION_MANAGER" >> /root/.vnc/xstartup \
    && echo "unset DBUS_SESSION_BUS_ADDRESS" >> /root/.vnc/xstartup \
    && echo "exec startxfce4" >> /root/.vnc/xstartup \
    && chmod +x /root/.vnc/xstartup

# Main startup script
RUN echo "#!/bin/bash" > /startup.sh \
    && echo "vncserver :1 -geometry 1280x720 -depth 24" >> /startup.sh \
    && echo "/usr/sbin/sshd -D &" >> /startup.sh \
    && echo "/ngrok tcp --region \$REGION --authtoken \$NGROK_TOKEN 5901 &" >> /startup.sh \
    && echo "sleep 5" >> /startup.sh \
    && echo "/ngrok tcp --region \$REGION --authtoken \$NGROK_TOKEN 22 &" >> /startup.sh \
    && echo "sleep 10" >> /startup.sh \
    && echo "echo '========================================='" >> /startup.sh \
    && echo "echo 'VNC Desktop Access:'" >> /startup.sh \
    && echo "curl -s http://localhost:4040/api/tunnels | python3 -c \"\
import sys, json\n\
tunnels = json.load(sys.stdin)['tunnels']\n\
for tunnel in tunnels:\n\
    if '5901' in tunnel['name']:\n\
        print('Address: ' + tunnel['public_url'][6:])\n\
        print('Password: ' + '$VNC_PASSWORD')\n\
    elif '22' in tunnel['name']:\n\
        print('\\nSSH Access:')\n\
        print('ssh root@' + tunnel['public_url'][6:].replace(':', ' -p '))\n\
        print('Password: craxid')\
\" || echo \"Failed to get tunnel info\"" >> /startup.sh \
    && echo "echo '========================================='" >> /startup.sh \
    && echo "tail -f /dev/null" >> /startup.sh \
    && chmod +x /startup.sh

# SSH setup
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config \
    && echo 'root:craxid' | chpasswd \
    && mkdir -p /run/sshd

EXPOSE 22 5901
CMD ["/bin/bash", "/startup.sh"]
