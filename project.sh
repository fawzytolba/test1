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

sudo usermod -aG docker iti
#mv ./project /home/iti/
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
cd /home/iti ; mkdir -p project2/app{1,2}
cd project2/app1/ ; mkdir db-data logs nginx wordpress;
cat <<-EOF > nginx/wordpress.conf
server {
    listen 80;
    server_name wp-iti.com;
 
    root /var/www/html;
    index index.php;
 
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
cat <<-EOF > docker-compose.yml
nginx:
    image: nginx:latest
    ports:
        - '80:80'
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
su - iti  -c "cd ~/project2/app1/; docker-compose up -d"
cd /home/iti/project2/app2
cat <<-EOF > docker-compose.yml
my-apache:
    build: .
    ports:
        - '8080:80'
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
FROM php:5.5.23-apache
RUN ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/
RUN service apache2 restart
EOF
chown -R iti:iti /home/iti/project2
su - iti  -c "cd ~/project2/app2/; docker-compose up -d"
su - iti -c "docker ps"

