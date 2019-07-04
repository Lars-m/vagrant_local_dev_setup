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