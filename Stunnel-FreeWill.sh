#!/bin/bash
STUNNEL_PORT=443
function install_stunnel { 
    yum install -y openssl stunnel
}
function make_stunnel_config {
    echo "Configuring Stunnel "
    read -p "Enter Stunnel Listen Port : " -e -i "443" STUNNEL_PORT
    read -p "Enter Stunnel Remote Port : " -e -i "9000" LOCAL_TUNNEL_PORT
    firewall-cmd --zone=public --permanent --add-port=$STUNNEL_PORT/tcp
    firewall-cmd --zone=public --permanent --add-port=$LOCAL_TUNNEL_PORT/tcp
    echo "cert = /etc/stunnel/stunnel.pem
pid = /var/run/stunnel.pid
[proxy]
accept = $STUNNEL_PORT
connect = $LOCAL_TUNNEL_PORT" > /etc/stunnel/stunnel.conf
    cd /etc/stunnel
    echo "Generating OpenSSL Certs"
    openssl genrsa -out key.pem 2048 \
    && openssl req -new -x509 -key key.pem -out cert.pem -days 3650 -batch \
    && cat key.pem cert.pem >> stunnel.pem
}
function make_stunnel_service {    
    echo "Installing Stunnel Service " 
    echo "[Unit]
Description=Stunnel Service
Requires=network.target
After=network.target
[Service]
Type=forking
PIDFile=/var/run/stunnel.pid
ExecStart=/usr/bin/stunnel /etc/stunnel/stunnel.conf
Restart=on-failure
LimitNOFILE=1024000
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/stunnel.service
}
if [ ! -e /etc/redhat-release ]; then
    echo "This script doesn't support your dist "
    exit
fi

if [ -f "/usr/bin/stunnel" ]; then
    echo "Stunnel Exists ! Skipping Installation "
else
    install_stunnel
fi
if [ -f "/etc/systemd/system/stunnel.service" ]; then
    read -p "Stunnel Service Exists! Overwrite [y/n] : " -e -i "y" OVERWRITE_STUNNEL_SERVICE
    if [ "$OVERWRITE_STUNNEL_SERVICE" == "y" ]; then 
        make_stunnel_service
        systemctl daemon-reload
    fi
else 
    make_stunnel_service
fi

if [ -f "/etc/stunnel/stunnel.conf" ]; then
    read -p "Stunnel Config Exists! Overwrite [y/n] : " -e -i "y" OVERWRITE_STUNNEL
    if [ "$OVERWRITE_STUNNEL" == "y" ]; then 
        make_stunnel_config
    fi
else 
    make_stunnel_config
fi


service stunnel restart
systemctl enable stunnel
