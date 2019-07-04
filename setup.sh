

echo "###########                     Setup MySql 8.0              ################"
echo "##############################################################################"


# mysql_user="test"
export MYSQL_ROOT_PW="test"
export DEV_USER_PW="dev"


export DEBIAN_FRONTEND="noninteractive";
sudo apt-get update
sudo apt-get install -y debconf-utils 
sudo debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/select-server select mysql-8.0'

wget https://dev.mysql.com/get/mysql-apt-config_0.8.13-1_all.deb

sudo -E dpkg -i mysql-apt-config_0.8.13-1_all.deb
sudo apt-get update

#NEW --> Clean up
sudo rm mysql-apt-config*

# Install MySQL 8
echo "Installing MySQL 8..."
sudo debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password $MYSQL_ROOT_PW"
sudo debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password $MYSQL_ROOT_PW"

sudo -E apt-get -y install mysql-server

# mysql_secure_installation -p test -D
# Below mimics the behaviour of mysql_sequre_installation which is hard to automate

MYSQL_PWD=$MYSQL_ROOT_PW mysql -u root <<_EOF_
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
_EOF_


sudo mysql -u root -p$MYSQL_ROOT_PW -t <<MYSQL_INPUT
CREATE User 'dev'@'localhost' IDENTIFIED BY '$DEV_USER_PW' ;
GRANT ALL PRIVILEGES ON *.* TO 'MY_USER'@'localhost' WITH GRANT OPTION;
MYSQL_INPUT


# Override any existing bind-address to be 0.0.0.0 to accept connections from host
# echo "Updating my.cnf..."
# sudo sed -i "s/^bind-address/#bind-address/" /etc/mysql/my.cnf

# echo "[mysqld]" | sudo tee -a /etc/mysql/my.cnf
# echo "bind-address=0.0.0.0" | sudo tee -a /etc/mysql/my.cnf

#Check this
# echo "default-time-zone='+01:00'" | sudo tee -a /etc/mysql/my.cnf

echo "Granting root access via any IP..."
# MYSQL_PWD=root mysql -u root -e "CREATE USER 'root'@'%' IDENTIFIED BY 'root'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES; SET GLOBAL max_connect_errors=10000;"

# Start MySQL server
echo "Restarting MySQL..."
sudo service mysql restart


echo "########################## Install Java     #########################"
sudo -E apt-get install -y openjdk-8-jre

echo ""
echo "########################## Tomcat Setup     #########################"

sudo groupadd tomcat
sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat

cd /tmp
sudo curl -O http://mirrors.dotsrc.org/apache/tomcat/tomcat-9/v9.0.21/bin/apache-tomcat-9.0.21.tar.gz
sudo mkdir /opt/tomcat
sudo tar xzvf apache-tomcat-9*tar.gz -C /opt/tomcat --strip-components=1

cd /opt/tomcat
sudo chgrp -R tomcat /opt/tomcat
sudo chmod -R g+r conf
sudo chmod g+x conf
sudo chown -R tomcat webapps/ work/ temp/ logs/

echo "##############################################################################"
echo "###########             Setup Tomcat-users.xml                ################"
echo "########### NEVER NEVER use this file for a production server ################"
echo "##############################################################################"

sudo rm /opt/tomcat/conf/tomcat-users.xml
sudo cat <<- EOF_TCU > /opt/tomcat/conf/tomcat-users.xml
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
<!--
         NOTE:  DO NOT USE THIS FILE IN PRODUCTION.
         IT'S MEANT ONLY FOR A LOCAL DEVELOPMENT SERVER USED BY NETBEANS
-->
  <user username="netbeans" password="xf87rE" roles="manager-gui"/>
  <user username="mavendeploy" password="xf87rE" roles="manager-script"/>
</tomcat-users>
EOF_TCU

echo ""
echo "################################################################################"
echo "#######             Setup manager context.xml                            #######"
echo "####### Allows access from browsers NOT running on same server as Tomcat #######"
echo "################################################################################"

sudo rm /opt/tomcat/webapps/manager/META-INF/context.xml
sudo cat <<- EOF_CONTEXT > /opt/tomcat/webapps/manager/META-INF/context.xml
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" /> -->
</Context>
EOF_CONTEXT

sudo rm /opt/tomcat/webapps/host-manager/META-INF/context.xml
sudo cat <<- EOF_CONTEXT_H > /opt/tomcat/webapps/host-manager/META-INF/context.xml
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" /> -->
</Context>
EOF_CONTEXT_H


echo ""
echo "################################################################################"
echo "#######                       Setup setenv.sh                            #######"
echo "#######      Sets different environment variables read by Tomcat         #######"
echo "################################################################################"

sudo cat <<- EOF_SETENV > /opt/tomcat/bin/setenv.sh
# export JPDA_OPTS="-agentlib:jdwp=transport=dt_socket, address=9999, server=y, suspend=n"
export CATALINA_OPTS="-agentlib:jdwp=transport=dt_socket,address=9999,server=y,suspend=n"
EOF_SETENV


echo ""
echo "################################################################################"
echo "############################ Create tomcat.service file ########################"
echo "################################################################################"
# Inspired by this tutorial: https://www.digitalocean.com/community/tutorials/install-tomcat-9-ubuntu-1804

sudo cat <<- EOF > /etc/systemd/system/tomcat.service
 [Unit]
 Description=Apache Tomcat Web Applicatiprivilegedon Container
 After=network.target

 [Service]
 Type=forking
 
 Environment=JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
 Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
 Environment=CATALINA_HOME=/opt/tomcat
 Environment=CATALINA_BASE=/opt/tomcat
 Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
 Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'
 
 ExecStart=/opt/tomcat/bin/startup.sh
 ExecStop=/opt/tomcat/bin/shutdown.sh
 
 User=tomcat
 Group=tomcat
 UMask=0007
 RestartSec=10
 Restart=always

 [Install]
 WantedBy=multi-user.target
EOF


sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat


echo "############ setup nginx  ############"
sudo apt-get install -y nginx
sudo sed -i '/http {/ a\       client_max_body_size 50M;' /etc/nginx/nginx.conf;


####### TBD --> Setup virtual server to point to tomcat





