#!/bin/bash
STUNNEL_PORT=443
SQUID_PORT=3128
function install_stunnel { 
    yum install -y openssl stunnel
}
function make_stunnel_config {
    echo "Configuring Stunnel "
    read -p "Enter Stunnel Listen Port : " -e -i "443" STUNNEL_PORT
    echo "cert = /etc/stunnel/stunnel.pem
pid = /var/run/stunnel.pid
[proxy]
accept = $STUNNEL_PORT
connect = $SQUID_PORT" > /etc/stunnel/stunnel.conf
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
function make_squid_config {
    read -p "Enter Basic Auth Username : " -e USERNAME
    read -p "Enter Basic Auth Password : " -e PASSWORD
    read -p "Enter Squid Listen Port : " -e -i "3128" SQUID_PORT
    echo "$PASSWORD" | /usr/bin/htpasswd -c -i /etc/squid/passwd "$USERNAME"
    chown squid.squid /etc/squid/passwd
    echo "
#
# Recommended minimum configuration:
#
max_filedesc 1024000
# Example rule allowing access from your local networks.
# Adapt to list your (internal) IP networks from where browsing
# should be allowed
acl localnet src 10.0.0.0/8     # RFC1918 possible internal network
acl localnet src 172.16.0.0/12  # RFC1918 possible internal network
acl localnet src 192.168.0.0/16 # RFC1918 possible internal network
acl localnet src fc00::/7       # RFC 4193 local private network range
acl localnet src fe80::/10      # RFC 4291 link-local (directly plugged) machines

acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT

#
# Recommended minimum Access Permission configuration:
#
# Deny requests to certain unsafe ports
#http_access deny !Safe_ports

# Deny CONNECT to other than secure SSL ports
#http_access deny CONNECT !SSL_ports

# Only allow cachemgr access from localhost
http_access allow localhost manager
http_access deny manager

#
# INSERT YOUR OWN RULE(S) HERE TO ALLOW ACCESS FROM YOUR CLIENTS
#
auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm Squid Basic Authentication
auth_param basic credentialsttl 2 hours
auth_param basic casesensitive on
acl auth_users proxy_auth REQUIRED
http_access allow auth_users




# Example rule allowing access from your local networks.
# Adapt localnet in the ACL section to list your (internal) IP networks
# from where browsing should be allowed
http_access allow localnet
http_access allow localhost

# And finally deny all other access to this proxy
http_access deny all

# Squid normally listens to port 3128
http_port $SQUID_PORT
#http_port 3129 transparent
# Uncomment and adjust the following to add a disk cache directory.
#cache_dir ufs /var/spool/squid 100 16 256

# Leave coredumps in the first cache dir
coredump_dir /var/spool/squid

#
# Add any of your own refresh_pattern entries above these.
#
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320" > /etc/squid/squid.conf 
}
function install_squid { 
    yum install -y squid httpd-tools
}
if [ ! -e /etc/redhat-release ]; then
    echo "This script doesn't support your dist "
    exit
fi

if [ -f "/usr/sbin/squid" ]; then
    echo "Squid Exists ! Skipping Installation "
else
    install_squid
fi
if [ -f "/etc/squid/squid.conf" ]; then
    read -p "Squid Config Exists! Overwrite [y/n] : " -e -i "y" OVERWRITE_SQUID
    if [ "$OVERWRITE_SQUID" == "y" ]; then 
        make_squid_config
    fi
else
    make_squid_config
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
systemctl enable --now squid
service squid restart 
