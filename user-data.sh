#!/bin/bash

# ----------------------------
# Variables
# ----------------------------
PROJECT_NAME="${project_name}"
REGION="${region}"
DOMAIN_NAME="${domain_name}"
EMAIL_ADDRESS="${email_address}"
ADMIN_IP_ADDRESS="${admin_ip_address}"

EBS_DEVICE="/dev/xvdf"
POSTGRES_HOST_PATH="/var/lib/postgresql"
POSTGRES_DATA_PATH="$POSTGRES_HOST_PATH/data"
DOCKER_NETWORK="$PROJECT_NAME-net"
CERT_FILE="/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem"
KEY_FILE="/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem"

# ----------------------------
# Install core dependencies first
# ----------------------------
dnf update -y
dnf install -y docker aws-cli nginx certbot python-certbot-nginx

# ----------------------------
# Install Docker Compose V2 Plugin
# ----------------------------
mkdir -p /usr/libexec/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
     -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose
ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose
usermod -aG docker ec2-user

# ----------------------------
# Create named Docker network
# ----------------------------
docker network create "$DOCKER_NETWORK" || true

# ----------------------------
# Start services after successful installation
# ----------------------------
systemctl enable docker
systemctl start docker
while [ "$(systemctl is-active docker)" != "active" ]; do
    echo "Waiting for Docker service to start..."
    sleep 5
done

systemctl enable nginx
systemctl start nginx

# ----------------------------
# Mount EBS volume for Postgres
# ----------------------------
if ! blkid "$EBS_DEVICE" ; then
    echo "EBS device not formatted. Formatting..."
    mkfs -t ext4 "$EBS_DEVICE"
fi

mkdir -p "$POSTGRES_HOST_PATH"

if ! mountpoint -q "$POSTGRES_HOST_PATH" ; then
    echo "Mounting EBS device to $POSTGRES_HOST_PATH..."
    mount "$EBS_DEVICE" "$POSTGRES_HOST_PATH"
else
    echo "EBS device already mounted. Skipping."
fi

chown -R ec2-user:ec2-user "$POSTGRES_HOST_PATH"

mkdir -p "$POSTGRES_DATA_PATH"
chown -R ec2-user:ec2-user "$POSTGRES_DATA_PATH"

# ----------------------------
# Fetch secrets from SSM and export them as environment variables
# ----------------------------
DB_USER=$(aws ssm get-parameter --name "/$PROJECT_NAME/db-user" --region "$REGION" --with-decryption --query "Parameter.Value" --output text)
DB_PASSWORD=$(aws ssm get-parameter --name "/$PROJECT_NAME/db-password" --region "$REGION" --with-decryption --query "Parameter.Value" --output text)
KC_ADMIN_USER=$(aws ssm get-parameter --name "/$PROJECT_NAME/admin-user" --region "$REGION" --with-decryption --query "Parameter.Value" --output text)
KC_ADMIN_PASSWORD=$(aws ssm get-parameter --name "/$PROJECT_NAME/admin-password" --region "$REGION" --with-decryption --query "Parameter.Value" --output text)

# ----------------------------
# Start containers with Docker Compose
# ----------------------------
docker-compose -p "$PROJECT_NAME" -f - up -d <<EOF
networks:
  default:
    name: $DOCKER_NETWORK
services:
  postgres:
    image: postgres:15
    container_name: postgres
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: $DB_USER
      POSTGRES_PASSWORD: $DB_PASSWORD
    volumes:
      - $POSTGRES_DATA_PATH:/var/lib/postgresql/data
    restart: always

  keycloak:
    image: quay.io/keycloak/keycloak:25.0.0
    container_name: keycloak
    command: start --optimized
    environment:
      KC_DB_URL_HOST: postgres
      KC_DB_URL_DATABASE: keycloak
      KC_DB_USERNAME: $DB_USER
      KC_DB_PASSWORD: $DB_PASSWORD
      KC_HOSTNAME: $DOMAIN_NAME
      KC_HTTP_ENABLED: "true"
      KC_PROXY: edge
      KEYCLOAK_ADMIN: $KC_ADMIN_USER
      KEYCLOAK_ADMIN_PASSWORD: $KC_ADMIN_PASSWORD
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    restart: always
EOF

# ----------------------------
# Temporary HTTP server block for Certbot
# ----------------------------
mkdir -p /var/www/certbot
cat > /etc/nginx/conf.d/keycloak.conf  <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF

nginx -t && systemctl reload nginx

# ----------------------------
# Run Certbot to get SSL certificate
# ----------------------------
certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos -m "$EMAIL_ADDRESS"

# ----------------------------
# Replace temporary block with final HTTPS config
# ----------------------------
cat > /etc/nginx/conf.d/keycloak.conf <<EOF
# ----------------------------
# HTTP (port 80) - only for Certbot + redirect
# ----------------------------
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME;

    # Certbot challenge endpoint
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect everything else to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# ----------------------------
# HTTPS (port 443) - Keycloak
# ----------------------------
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $DOMAIN_NAME;

    ssl_certificate $CERT_FILE;
    ssl_certificate_key $KEY_FILE;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location /admin {
        # Allow access only from your IP address; you can also use SSM for access
        allow $ADMIN_IP_ADDRESS;
        deny all;

        proxy_pass http://127.0.0.1:8080/admin;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
    # Everything proxied to Keycloak
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOF

nginx -t && systemctl reload nginx
