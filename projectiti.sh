#!/bin/bash
set +e
sudo yum install -y yum-utils  device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo  https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod a+rx /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

useradd -m -s /bin/bash iti
firewall-cmd --add-service=https --permanent
firewall-cmd --add-service=http --permanent
firewall-cmd --add-port=8080/tcp --permanent
firewall-cmd --add-port=8443/tcp --permanent
firewall-cmd --reload
sudo usermod -aG docker iti
setenforce 0
#mv ./project /home/iti/
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
cd /home/iti ; mkdir -p project2/app{1,2}
cd project2/app1/ ; mkdir db-data logs nginx wordpress;
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt
cat <<-EOF > nginx/wordpress.conf
server {
    listen 80 ;
    listen 8443 default_server ssl;
    server_name wp-iti.com;
 
    root /var/www/html;
    index index.php;
    #ssl    on;
    ssl_certificate    /etc/ssl/certs/server.crt;
    ssl_certificate_key    /etc/ssl/certs/server.key;
    access_log /var/log/nginx/iti-access.log;
    error_log /var/log/nginx/iti-error.log;
 
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
 
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
}
EOF
cat <<-EOF > Dockerfile
FROM nginx:latest
COPY ./server.key /etc/ssl/certs/server.key
COPY ./server.crt /etc/ssl/certs/server.crt
RUN service nginx restart
EOF
cat <<-EOF > docker-compose.yml
nginx:
    build: .
    ports:
        - '80:80'
        - '8443:8443'
    volumes:
        - ./nginx:/etc/nginx/conf.d
        - ./logs/nginx:/var/log/nginx
        - ./wordpress:/var/www/html
    links:
        - wordpress
    restart: always
mysql:
    image: mariadb:10.1
    ports:
        - '3306:3306'
    #volumes:
    #    - ./db-data:/var/lib/mysql
    environment:
        - MYSQL_ROOT_PASSWORD=ahmed123
    restart: always
wordpress:
    image: wordpress:4.7.1-php7.0-fpm
    ports:
        - '9000:9000'
    volumes:
        - ./wordpress:/var/www/html
    environment:
        - WORDPRESS_DB_NAME=wpdb
        - WORDPRESS_TABLE_PREFIX=wp_
        - WORDPRESS_DB_HOST=mysql
        - WORDPRESS_DB_PASSWORD=ahmed123
    links:
        - mysql
    restart: always
EOF
chown -R iti:iti /home/iti/project2
su - iti  -c "cd ~/project2/app1/; docker-compose build ; docker-compose up -d"
cd /home/iti/project2/app2
cat <<-EOF > docker-compose.yml
my-apache:
    build: .
    ports:
        - '8080:80'
        - '443:443'
    volumes:
        - ./joomla:/var/www/html
    links:
        - joomla
    restart: always
mysql:
    image: mariadb
    ports:
        - '3307:3306'
    volumes:

        - ./db-data:/var/lib/mysql
    environment:
        - MYSQL_ROOT_PASSWORD=ahmed123
    restart: always
joomla:
    image: joomla:3.8.8-php5.6-fpm
    ports:
        - '9001:9000'
    volumes:
        - ./joomla:/var/www/html
    environment:
        - JOOMLA_DB_NAME=wpdb
        - JOOMLA_TABLE_PREFIX=wp_
        - JOOMLA_DB_HOST=mysql
        - JOOMLA_DB_PASSWORD=ahmed123
    links:
        - mysql
    restart: always
EOF
cat <<-EOF > Dockerfile
FROM php:7.1-apache
RUN ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/
RUN apt-get update && \
    apt-get install -y \
        zlib1g-dev
COPY ./server.crt /etc/apache2/ssl/server.crt
COPY ./server.key /etc/apache2/ssl/server.key
COPY ./ahmed.conf /etc/apache2/sites-enabled/ahmed.conf
RUN docker-php-ext-install mysqli pdo pdo_mysql zip mbstring
RUN a2enmod rewrite
RUN a2enmod ssl
RUN service apache2 restart
EOF
cat <<-EOF > ahmed.conf
<VirtualHost *:443>
    DocumentRoot "/var/www/html/"
    ServerName ahmed
    SSLEngine on
    SSLCertificateFile "/etc/apache2/ssl/server.crt"
    SSLCertificateKeyFile "/etc/apache2/ssl/server.key"
</VirtualHost>
EOF
chown -R iti:iti /home/iti/project2
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt
su - iti  -c "cd ~/project2/app2/; docker-compose build ; docker-compose up -d"
su - iti -c "docker ps"

