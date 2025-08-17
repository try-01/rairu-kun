FROM debian:bullseye

ARG NGROK_TOKEN
ARG REGION=ap
ARG VNC_PASSWORD
ARG USERNAME
ARG USER_PASSWORD
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies termasuk procps untuk 'pkill'
RUN apt update && apt upgrade -y && \
    apt install -y --no-install-recommends \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    firefox-esr \
    wget unzip curl python3 \
    openssh-server \
    dbus-x11 \
    sudo \
    procps

# Install ngrok
RUN curl -k -L https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -o /ngrok.tgz \
    && tar xvzf /ngrok.tgz -C /usr/local/bin \
    && chmod +x /usr/local/bin/ngrok \
    && rm /ngrok.tgz

# Setup DBus
RUN dbus-uuidgen > /var/lib/dbus/machine-id

# Create a non-root user
RUN useradd -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME}:${USER_PASSWORD}" | chpasswd && \
    adduser ${USERNAME} sudo

# Setup VNC for the new user
RUN mkdir -p /home/${USERNAME}/.vnc && \
    echo "${VNC_PASSWORD}" | vncpasswd -f > /home/${USERNAME}/.vnc/passwd && \
    chmod 600 /home/${USERNAME}/.vnc/passwd && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.vnc

# Create VNC startup script
RUN echo "#!/bin/sh" > /home/${USERNAME}/.vnc/xstartup && \
    echo "unset SESSION_MANAGER" >> /home/${USERNAME}/.vnc/xstartup && \
    echo "unset DBUS_SESSION_BUS_ADDRESS" >> /home/${USERNAME}/.vnc/xstartup && \
    echo "exec dbus-launch startxfce4" >> /home/${USERNAME}/.vnc/xstartup && \
    chmod +x /home/${USERNAME}/.vnc/xstartup && \
    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.vnc/xstartup

# --- SKRIP TUNGGAL UNTUK MENUKAR TUNNEL NGROK ---
RUN echo "#!/bin/bash" > /usr/local/bin/switch-tunnel && \
    echo "STATE_FILE=\"/tmp/ngrok_state\"" >> /usr/local/bin/switch-tunnel && \
    echo "CURRENT_STATE=\$(cat \$STATE_FILE 2>/dev/null || echo \"vnc\")" >> /usr/local/bin/switch-tunnel && \
    echo "" >> /usr/local/bin/switch-tunnel && \
    echo "echo '>>> Mematikan tunnel yang ada...'" >> /usr/local/bin/switch-tunnel && \
    echo "pkill ngrok || true" >> /usr/local/bin/switch-tunnel && \
    echo "sleep 2" >> /usr/local/bin/switch-tunnel && \
    echo "" >> /usr/local/bin/switch-tunnel && \
    echo "if [ \"\$CURRENT_STATE\" == \"vnc\" ]; then" >> /usr/local/bin/switch-tunnel && \
    echo "  echo '>>> Mengalihkan tunnel ke SSH (port 22)...'" >> /usr/local/bin/switch-tunnel && \
    echo "  nohup /usr/local/bin/ngrok tcp --region \$REGION --authtoken \$NGROK_TOKEN 22 &" >> /usr/local/bin/switch-tunnel && \
    echo "  echo 'ssh' > \$STATE_FILE" >> /usr/local/bin/switch-tunnel && \
    echo "  echo '>>> SUKSES! Koneksi Anda saat ini akan terputus.'" >> /usr/local/bin/switch-tunnel && \
    echo "" >> /usr/local/bin/switch-tunnel && \
    echo ">>> Buka browser dan cek dashboard.ngrok.com untuk alamat SSH baru.'" >> /usr/local/bin/switch-tunnel && \
    echo "else" >> /usr/local/bin/switch-tunnel && \
    echo "  echo '>>> Mengembalikan tunnel ke VNC (port 5901)...'" >> /usr/local/bin/switch-tunnel && \
    echo "  nohup /usr/local/bin/ngrok tcp --region \$REGION --authtoken \$NGROK_TOKEN 5901 &" >> /usr/local/bin/switch-tunnel && \
    echo "  echo 'vnc' > \$STATE_FILE" >> /usr/local/bin/switch-tunnel && \
    echo "  echo '>>> SUKSES! Koneksi Anda saat ini akan terputus.'" >> /usr/local/bin/switch-tunnel && \
    echo "" >> /usr/local/bin/switch-tunnel && \
    echo ">>> Buka browser dan cek dashboard.ngrok.com untuk alamat VNC baru.'" >> /usr/local/bin/switch-tunnel && \
    echo "fi" >> /usr/local/bin/switch-tunnel && \
    chmod +x /usr/local/bin/switch-tunnel

# Main startup script
RUN echo "#!/bin/bash" > /startup.sh && \
    echo "dbus-daemon --system &" >> /startup.sh && \
    echo "sleep 2" >> /startup.sh && \
    echo "sudo -u ${USERNAME} vncserver :1 -geometry 1280x720 -depth 24" >> /startup.sh && \
    echo "/usr/sbin/sshd -D &" >> /startup.sh && \
    # Memulai tunnel VNC secara default saat startup
    echo "/usr/local/bin/ngrok tcp --region \$REGION --authtoken \$NGROK_TOKEN 5901 &" >> /startup.sh && \
    # Mengatur state awal ke 'vnc'
    echo "echo 'vnc' > /tmp/ngrok_state" >> /startup.sh && \
    echo "sleep 10" >> /startup.sh && \
    echo "echo '--- VNC Access Info ---'" >> /startup.sh && \
    echo "curl -s http://localhost:4040/api/tunnels | python3 -c \"import sys, json; data=json.load(sys.stdin); tunnel=data['tunnels'][0]['public_url'].replace('tcp://', ''); print('Address: ' + tunnel); print('Password: ' + '\$VNC_PASSWORD')\" || echo 'Failed to get tunnel info'" >> /startup.sh && \
    echo "tail -f /dev/null" >> /startup.sh && \
    chmod +x /startup.sh

# SSH setup
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'root:craxid' | chpasswd && \
    mkdir -p /run/sshd

EXPOSE 5901 22
CMD ["/bin/bash", "/startup.sh"]
