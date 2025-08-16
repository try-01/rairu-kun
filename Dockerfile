FROM debian:bullseye

ARG NGROK_TOKEN
ARG REGION=ap
ENV DEBIAN_FRONTEND=noninteractive \
    VNC_PASSWORD=craxid

# Install dependencies
RUN apt update && apt upgrade -y && \
    apt install -y --no-install-recommends \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    firefox-esr \
    wget unzip curl python3 \
    openssh-server

# Install ngrok
RUN curl -k -L https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -o /ngrok.tgz \
    && tar xvzf /ngrok.tgz -C / \
    && chmod +x /ngrok \
    && rm /ngrok.tgz

# Setup VNC
RUN mkdir -p /root/.vnc && \
    echo "$VNC_PASSWORD" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Create VNC startup script
RUN echo "#!/bin/sh\nunset SESSION_MANAGER\nunset DBUS_SESSION_BUS_ADDRESS\nexec startxfce4" > /root/.vnc/xstartup && \
    chmod +x /root/.vnc/xstartup

# Main startup script
RUN echo "#!/bin/bash" > /startup.sh && \
    echo "vncserver :1 -geometry 1280x720 -depth 24" >> /startup.sh && \
    echo "/usr/sbin/sshd -D &" >> /startup.sh && \
    echo "/ngrok tcp --region \$REGION --authtoken \$NGROK_TOKEN 5901 &" >> /startup.sh && \
    echo "sleep 10" >> /startup.sh && \
    echo "echo '========================================='" >> /startup.sh && \
    echo "echo 'VNC Desktop Access:'" >> /startup.sh && \
    echo "curl -s http://localhost:4040/api/tunnels | python3 -c \"import sys, json; data=json.load(sys.stdin); tunnels=data['tunnels']; print('Address: ' + tunnels[0]['public_url'][6:] + '\nPassword: ' + '$VNC_PASSWORD')\" || echo 'Failed to get tunnel info'" >> /startup.sh && \
    echo "echo '========================================='" >> /startup.sh && \
    echo "echo 'Untuk SSH: Buka terminal di desktop VNC'" >> /startup.sh && \
    echo "tail -f /dev/null" >> /startup.sh && \
    chmod +x /startup.sh

# SSH setup
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'root:craxid' | chpasswd && \
    mkdir -p /run/sshd

EXPOSE 5901
CMD ["/bin/bash", "/startup.sh"]
