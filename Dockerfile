FROM debian:bullseye

ARG NGROK_TOKEN
ARG REGION=ap
ARG VNC_PASSWORD=craxid
ARG USERNAME=bebas
ARG USER_PASSWORD=bebasaja
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies termasuk DBus
RUN apt update && apt upgrade -y && \
    apt install -y --no-install-recommends \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server \
    firefox-esr \
    wget unzip curl python3 \
    openssh-server \
    dbus-x11 \
    sudo \
    xfce4-settings \
    xfce4-panel \
    xfce4-session \
    xfdesktop4 \
    xinit

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

# Create VNC startup script yang diperbaiki untuk user
RUN echo "#!/bin/sh" > /home/${USERNAME}/.vnc/xstartup && \
    echo "unset SESSION_MANAGER" >> /home/${USERNAME}/.vnc/xstartup && \
    echo "unset DBUS_SESSION_BUS_ADDRESS" >> /home/${USERNAME}/.vnc/xstartup && \
    echo "exec dbus-launch startxfce4" >> /home/${USERNAME}/.vnc/xstartup && \
    chmod +x /home/${USERNAME}/.vnc/xstartup && \
    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.vnc/xstartup

# Main startup script
RUN echo "#!/bin/bash" > /startup.sh && \
    # Jalankan VNC server sebagai pengguna baru
    echo "sudo -u ${USERNAME} vncserver :1 -geometry 1280x720 -depth 24" >> /startup.sh && \
    echo "/usr/sbin/sshd -D &" >> /startup.sh && \
    # Jalankan ngrok sebagai root agar bisa mengakses proses lain jika perlu
    echo "/usr/local/bin/ngrok tcp --region \$REGION --authtoken \$NGROK_TOKEN 5901 &" >> /startup.sh && \
    echo "sleep 10" >> /startup.sh && \
    echo "echo '========================================='" >> /startup.sh && \
    echo "echo 'VNC Desktop Access:'" >> /startup.sh && \
    echo "curl -s http://localhost:4040/api/tunnels | python3 -c \"import sys, json; data=json.load(sys.stdin); tunnel=data['tunnels'][0]['public_url'].replace('tcp://', ''); print('Address: ' + tunnel); print('Password: ' + '${VNC_PASSWORD}')\" || echo 'Failed to get tunnel info'" >> /startup.sh && \
    echo "echo '========================================='" >> /startup.sh && \
    echo "echo 'Untuk SSH: Login sebagai root (user: root, pass: craxid) atau user (user: ${USERNAME}, pass: ${USER_PASSWORD})'" >> /startup.sh && \
    echo "tail -f /dev/null" >> /startup.sh && \
    chmod +x /startup.sh

# SSH setup
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'root:craxid' | chpasswd && \
    mkdir -p /run/sshd

EXPOSE 5901
CMD ["/bin/bash", "/startup.sh"]
