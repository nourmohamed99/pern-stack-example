#!/bin/bash

STATIC_IP_ADDRESS="172.19.2.120"

# Update system 
update_system() {
  echo "Updating system packages..."
  sudo apt-get update
}

# Install dependencies
install_dependencies() {
  echo "Installing dependencies..."
  sudo apt-get install -y curl dirmngr apt-transport-https lsb-release ca-certificates
  curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
  sudo apt-get install -y nodejs postgresql git
  sudo apt install npm
}

# Install Node.js packages
install_node_packages() {
  echo "Installing Node.js packages..."
  npm install dotenv express pg pine sequelize swagger-ui-express
}

# Set static IP
set_static_ip() {
  echo "Setting static IP..."
  sudo tee -a /etc/network/interfaces.d/eth0.cfg <<EOF
auto eth0
iface eth0 inet static
address $STATIC_IP_ADDRESS
netmask 255.255.255.0
gateway 192.168.1.1
EOF

  ip_regex='([0-9]{1,3}\.){3}[0-9]{1,3}'
  ip_address=$(ifconfig | grep -oP "$ip_regex" | head -n 1)
  echo "Static IP set to: $ip_address"
}

# Add Linux user
add_linux_user() {
  echo "Creating Linux user 'node'..."
  sudo useradd -m node
  sudo passwd node
  sudo usermod -aG sudo node
}

# Start Postgres
start_postgres() {
  echo "Starting Postgres..."
  sudo systemctl start postgresql
}

# Create database and user in postgresql
create_database_and_user() {
  echo "Creating database and user..."
  sudo -u postgres psql -c "CREATE DATABASE node"
  sudo -u postgres psql -c "CREATE USER node WITH PASSWORD '123'"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE node TO node"
}

# Clone repo
clone_repo() {
  echo "Cloning the repository..."
  git clone https://github.com/omarmohsen/pern-stack-example.git
  cd pern-stack-example
}

# Install and build frontend
install_and_build_frontend() {
  echo "Installing and building frontend..."
  cd ui
  npm install
  npm audit fix
  npm run build
}

# Build backend
build_backend() {
  echo "Building backend..."
  cd ..
  sed -i "/if (environment === 'demo') {/,/};/c \\
if (environment === 'demo') { \\
    ENVIRONMENT_VARIABLES = { \\
        'process.env.HOST': JSON.stringify('$STATIC_IP_ADDRESS'), \\
        'process.env.USER': JSON.stringify('node'), \\
        'process.env.DB': JSON.stringify('node'), \\
        'process.env.DIALECT': JSON.stringify('postgres'), \\
        'process.env.PORT': JSON.stringify('5432'), \\
        'process.env.PG_CONNECTION_STR': JSON.stringify('postgres://node:node@$STATIC_IP_ADDRESS:5432/node') \\
    }; \\
}" api/webpack.config.js

  export PG_CONNECTION_STR=postgres://node:node@$STATIC_IP_ADDRESS:5432/node
}

# Build frontend
build_frontend() {
  echo "Building frontend..."
  cd ui
  ENVIRONMENT=demo npm run build
}

# deploy server
deploy_server() {
  echo "Starting server..."
  cd ..
  cp -r ui api
  cd api && npm start
  echo "Server started successfully."
}


# Call functions 
update_system
install_dependencies
install_node_packages
set_static_ip
add_linux_user
start_postgres
create_database_and_user
clone_repo
install_and_build_frontend
build_backend
build_frontend
deploy_server
