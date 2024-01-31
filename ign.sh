#!/bin/bash

# detectar onde estou 
hostname; echo ${1} - a instalar aqui! sleep 5; #BREATHe
export PROJ_HOME=/home/mop/clientes/${1}/${1}-wp;
# pega os parametros da pipeline ativada manualmente
source ${PROJ_HOME}/.env; #primeira coisa a se fazer 
cd ${PROJ_HOME};
pwd;

echo INICIar deploy dentro do servidor-alvo;

export MOP_SERVER_IP=$( dig +short ${MOP_SERVER} | tail -n1 );
echo ${MOP_SERVER}:${MOP_SERVER_IP};

#cria entrada DNS
echo "VOU AUTENTICAR NA CLOUDFLARE E CRIAR ENTRADA DNS";
curl -X POST \
  --url https://api.cloudflare.com/client/v4/zones/${MOP_ZONE}/dns_records \
  -H'Content-Type: application/json' \
  -H 'X-Auth-Email: gustavo.conte@agenciamop.com.br ' \
  -H "Authorization: Bearer ${MOP_TOKEN}"  \
  --data '{
  "content": "'${MOP_SERVER_IP}'",
  "name": "'${MOP_WP}'-wp.agenciamop.com.br",
  "proxied": true,
  "type": "A",
  "comment": "mop-wp record",
  "ttl": 3600
}'

echo "DOCKER COMPOSE ************************************** begin";

docker-compose up -d --force-recreate --build;
sleep 10; #BREATHe
docker exec ${MOP_WP}-wp chown www-data -R /var/www/html;
docker network connect sites ${MOP_WP}-wp;
docker network connect mail ${MOP_WP}-wp;
#create vhost on main nginx listening port 80 behind CloudFlare
echo -e 'server { listen 80;\n\tserver_name '${MOP_WP}'-wp.agenciamop.com.br;\n\n client_max_body_size 500M;\n\n\t location / {\n\n proxy_pass http://'${MOP_WP}'-wp;\n proxy_set_header \n\t Host $http_host;\n  }\n }\n\n' > /home/mop/servidor-producao-config/nginx-config/${MOP_WP}-wp.agenciamop.com.br.conf;
sleep 5;
echo "RELOAD vhosts cfg only ONLY if configtest pass";
docker exec server-production-config /etc/nginx/conf.d/NginxReload.sh;

#wp-cli
docker exec ${MOP_WP}-wp curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
docker exec ${MOP_WP}-wp chmod +x wp-cli.phar
docker exec ${MOP_WP}-wp cp -ra wp-cli.phar /usr/bin/wp
