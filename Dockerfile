FROM debian
ARG NGROK_TOKEN
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt upgrade -y && apt install -y \
    ssh wget unzip vim curl python3

RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O /ngrok-stable-linux-amd64.zip \
    && cd / && unzip ngrok-stable-linux-amd64.zip \
    && chmod +x ngrok

RUN mkdir -p /run/sshd \
    # Perintah ngrok tanpa flag region
    && echo "/ngrok tcp --authtoken ${NGROK_TOKEN} 22 &" >>/openssh.sh \
    # Tambah waktu tunggu lebih lama
    && echo "sleep 10" >> /openssh.sh \
    # Script Python yang diperbaiki
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
            print('ssh info:')\n\
            print('ssh root@{}'.format(ssh_cmd))\n\
            print('ROOT Password:craxid')\n\
            break\n\
    except Exception as e:\n\
        print('Error:', str(e), file=sys.stderr)\n\
    tries += 1\n\
    time.sleep(2)\n\
if tries == 5:\n\
    print('\\\\nError: Failed to get Ngrok tunnel after 10 seconds')\
\" >> /openssh.sh" \
    && echo '/usr/sbin/sshd -D' >>/openssh.sh \
    && echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config \
    && echo root:craxid|chpasswd \
    && chmod 755 /openssh.sh

EXPOSE 80 443 3306 4040 5432 5700 5701 5010 6800 6900 8080 8888 9000
CMD ["/bin/bash", "/openssh.sh"]
