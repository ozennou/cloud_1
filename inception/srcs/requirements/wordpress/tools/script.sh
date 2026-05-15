#!/bin/sh

while ! mysql -u $DB_USER -p$DB_USER_PASSWD --host=mariadb -e "SHOW DATABASES LIKE '$DB_NAME';" 2>/dev/null | grep -q $DB_NAME;do 
    echo "Mariabd not ready yet"
    sleep 1
done

while ! redis-cli -h redis-cache --pass $REDIS_PASSWD ping 2>/dev/null | grep -q PONG;do
    echo "Redis-cache not ready yet"
    sleep 1
done 

WP_CLI="php -d memory_limit=512M /bin/wp-cli.phar"

if $WP_CLI core is-installed --path=/var/www 2>/dev/null; then
    exec php-fpm81 -F
fi

$WP_CLI core download --path=/var/www/

$WP_CLI config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_USER_PASSWD --dbhost=mariadb --path=/var/www/

$WP_CLI core install --url="$DOMAINNAME" --title="$TITLE" --admin_user=$WP_ADMIN --admin_password=$WP_ADMIN_PASSWD --admin_email=$WP_ADMIN_MAIL --path=/var/www/

$WP_CLI user create $WP_USER $WP_USER_MAIL --role=subscriber --user_pass=$WP_USER_PASSWD --path=/var/www/ 

$WP_CLI theme install ace-news --path=/var/www

$WP_CLI theme activate ace-news --path=/var/www

#redis-cache begin
$WP_CLI plugin install redis-cache --path=/var/www
$WP_CLI plugin activate redis-cache --path=/var/www
$WP_CLI config set WP_REDIS_HOST redis-cache --path=/var/www
$WP_CLI config set WP_REDIS_PORT 6379  --path=/var/www
$WP_CLI config set WP_CACHE true --raw  --path=/var/www
$WP_CLI config set WP_REDIS_PASSWORD $REDIS_PASSWD  --path=/var/www
$WP_CLI redis enable --path=/var/www
#redis-cache end

chown -R nobody:nogroup /var/www
chmod -R 777 /var/www

exec php-fpm81 -F
