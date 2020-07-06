#!/bin/bash
STUNNEL_PORT=443
TINY_PROXY_PORT=8888
function install_packages {
    yum update -y
    yum install make g++ gcc autogen automake autoconf asciidoc cmake git -y
    yum groupinstall 'Development Tools' -y
}
function install_stunnel { 
    yum install -y openssl stunnel
    make_stunnel_service
    systemctl daemon-reload
    service stunnel restart
    systemctl enable stunnel
}
function install_tinyproxy {
    install_packages
    git clone https://github.com/tinyproxy/tinyproxy /tmp/tinyproxy
    cd /tmp/tinyproxy
    ./autogen.sh
    ./configure
    make
    make install
    make_tinyproxy_service
    systemctl daemon-reload
    service tinyproxy restart 
    systemctl enable tinyproxy
}
function make_stunnel_config {
    echo "Configuring Stunnel "
    read -p "Enter Stunnel Listen Port : " -e -i "443" STUNNEL_PORT
    echo "cert = /etc/stunnel/stunnel.pem
pid = /var/run/stunnel.pid
[proxy]
accept = $STUNNEL_PORT
connect = $TINY_PROXY_PORT" > /etc/stunnel/stunnel.conf
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
function make_tinyproxy_service {    
    echo "Installing TinyProxy Serivce " 
    echo "[Unit]
Description=TinyProxy Service
Requires=network.target
After=network.target
[Service]
Type=forking
PIDFile=/var/run/tinyproxy.pid
ExecStart=/usr/local/bin/tinyproxy -c /etc/tinyproxy/tinyproxy.conf
Restart=on-failure
LimitNOFILE=1024000

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/tinyproxy.service
}
function make_tinyproxy_config {
    read -p "Enter Basic Auth Username : " -e USERNAME
    read -p "Enter Basic Auth Password : " -e PASSWORD
    read -p "Enter TinyProxy Listen Port : " -e -i "8888" TINY_PROXY_PORT
    mkdir -p /etc/tinyproxy
    echo "User root
Group root
Port $TINY_PROXY_PORT
Timeout 600
DefaultErrorFile \"/usr/share/tinyproxy/default.html\"
Logfile \"/var/log/tinyproxy.log\"
LogLevel Info
PidFile \"/var/run/tinyproxy.pid\"
MaxClients 100
MinSpareServers 5
MaxSpareServers 20
StartServers 10
MaxRequestsPerChild 0
BasicAuth $USERNAME $PASSWORD" > /etc/tinyproxy/tinyproxy.conf
}
if [ ! -e /etc/redhat-release ]; then
    echo "This script doesn't support your dist "
    exit
fi

if [ -f "/usr/local/bin/tinyproxy" ]; then
    echo "Tiny Proxy Exists! Skipping Installation "
else
    install_tinyproxy

fi

if [ -f "/usr/bin/stunnel" ]; then
    echo "Stunnel Exists ! Skipping Installation "
else
    install_stunnel
fi

if [ -f "/etc/tinyproxy/tinyproxy.conf" ]; then
    read -p "TinyProxy Config Exists! Overwrite [y/n] : " -e -i "y" OVERWRITE_TINYPROXY
    if [ "$OVERWRITE_TINYPROXY" == "y" ]; then
        make_tinyproxy_config
    fi
else
    make_tinyproxy_config
fi

if [ -f "/etc/stunnel/stunnel.conf" ]; then
    read -p "Stunnel Config Exists! Overwrite [y/n] : " -e -i "y" OVERWRITE_STUNNEL
    if [ "$OVERWRITE_STUNNEL" == "y" ]; then 
        make_stunnel_config
    fi
else 
    make_stunnel_config
fi




