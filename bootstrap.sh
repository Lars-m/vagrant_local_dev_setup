apt-get update
sudo -E apt install -y openjdk-8-jre

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


echo "################################################################################"
echo "#######             Setup manager context.xml                            #######"
echo "####### Allows access from browsers NOT running on same server as Tomcat #######"
echo "################################################################################"

sudo rm /opt/tomcat/webapps/manager/META-INF/context.xml
sudo cat <<- EOF_CONTEXT > /opt/tomcat/webapps/manager/META-INF/context.xml
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <!--<Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" />-->
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOF_CONTEXT



echo "############ Create tomcat.service file ############"
# Inspired by this tutorial: https://www.digitalocean.com/community/tutorials/install-tomcat-9-ubuntu-1804

sudo cat <<- EOF > /etc/systemd/system/tomcat.service
 [Unit]
 Description=Apache Tomcat Web Application Container
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





