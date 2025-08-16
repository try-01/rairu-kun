FROM debian
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt update && apt upgrade -y && apt install -y \
    ssh wget unzip vim curl python3

# Install ngrok
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O /ngrok-stable-linux-amd64.zip \
    && cd / && unzip ngrok-stable-linux-amd64.zip \
    && chmod +x ngrok

# Setup SSH and ngrok tunnel
RUN mkdir -p /run/sshd \
    && echo "#!/bin/bash" > /openssh.sh \
    && echo "echo \"Using Ngrok token: \$NGROK_TOKEN\" " >> /openssh.sh \
    && echo "echo \"Using Region: \$REGION\" " >> /openssh.sh \
    # Perbaikan kritis: urutan parameter yang benar
    && echo "/ngrok tcp --region \${REGION:-ap} --authtoken \"\$NGROK_TOKEN\" 22 &" >> /openssh.sh \
    && echo "sleep 15" >> /openssh.sh \
    && echo "curl -s http://localhost:4040/api/tunnels | python3 -c \"\
import sys, json, time\n\
tries = 0\n\
while tries < 5:\n\
    try:\n\
        data = sys.stdin.read()\n\
        if data:\n\
            tunnels = json.loads(data)['tunnels']\n\
            public_url = tunnels[0]['public_url'][6:]  # remove 'tcp://'\n\
            ssh_cmd = public_url.replace(':', ' -p ')\n\
            print('='*50)\n\
            print('ssh info:')\n\
            print('ssh root@{}'.format(ssh_cmd))\n\
            print('ROOT Password: craxid')\n\
            print('='*50)\n\
            break\n\
    except Exception as e:\n\
        print('Error:', str(e), file=sys.stderr)\n\
    tries += 1\n\
    time.sleep(3)\n\
if tries == 5:\n\
    print('\\\\nError: Failed to get Ngrok tunnel after 15 seconds')\
\" || echo \"\nNgrok setup failed\" " >> /openssh.sh \
    && echo '/usr/sbin/sshd -D' >> /openssh.sh \
    && echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config \
    && echo 'root:craxid' | chpasswd \
    && chmod 755 /openssh.sh

EXPOSE 22
CMD ["/bin/bash", "/openssh.sh"]
