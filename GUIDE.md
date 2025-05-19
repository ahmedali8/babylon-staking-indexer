# Running the Babylon Staking Indexer

This guide explains how to run the Babylon staking indexer using MongoDB Atlas and Bitcoind. You can either run Bitcoind locally (recommended for Signet) or connect to a remote mainnet RPC (via NGINX proxy).

## Table of Contents

1. [Overview](#overview)
2. [Option A: Run Bitcoind Locally (Signet)](#option-a-run-bitcoind-locally-signet)
3. [Option B: Use Remote Bitcoind RPC via NGINX (Mainnet)](#option-b-use-remote-bitcoind-rpc-via-nginx-mainnet)
4. [Running RabbitMQ](#running-rabbitmq)
5. [Environment Configuration](#environment-configuration)
6. [Running the Indexer](#running-the-indexer)

## Overview

- **MongoDB Atlas** is used for the database.
- **Bitcoind** is required for blockchain data access.
  - Use **local Signet** for development and testing.
  - Use a **remote Mainnet RPC** (e.g., Chainstack) for production-like environments.
- **RabbitMQ** is required for queue processing.
- If you're using a remote Bitcoin RPC, it must be exposed via HTTP POST and can be proxied using **NGINX**.

## Option A: Run Bitcoind Locally (Signet)

### 1. Install Bitcoind

```bash
brew install bitcoin
```

### 2. Create the Bitcoin Config

Create or edit the file:

```bash
vim "~/Library/Application Support/Bitcoin/bitcoin.conf"
```

Paste the following content:

```ini
signet=1
rpcallowip=127.0.0.1
rpcconnect=127.0.0.1
server=1
daemon=1
txindex=1
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28334

[signet]
rpcport=38332
rpcuser=admin
rpcpassword=password
deprecatedrpc=create_bdb
deprecatedrpc=warnings
```

### 3. Start Bitcoind

```bash
/opt/homebrew/opt/bitcoin/bin/bitcoind
```

Wait for the Signet chain to sync.

### 4. Test RPC Connection

```bash
curl --user admin \
  --data-binary '{"jsonrpc": "1.0", "id": "curltest", "method": "getblockcount"}' \
  -H 'content-type: text/plain;' \
  http://127.0.0.1:38332/
```

## Option B: Use Remote Bitcoind RPC via NGINX (Mainnet)

### 1. Obtain RPC URL

Use a provider like Chainstack:

```txt
https://bitcoin-mainnet.core.chainstack.com/YOUR_API_KEY
```

### 2. Install NGINX

```bash
brew install nginx
```

### 3. Update NGINX Config

Edit:

```bash
vim /opt/homebrew/etc/nginx/nginx.conf
```

Example configuration:

```nginx
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    keepalive_timeout  65;

    server {
        listen       8545;
        server_name  localhost;

        location / {
            proxy_pass https://bitcoin-mainnet.core.chainstack.com/YOUR_API_KEY;
            proxy_set_header Host bitcoin-mainnet.core.chainstack.com;
            proxy_ssl_server_name on;
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root html;
        }
    }

    include servers/*;
}
```

Replace `YOUR_API_KEY` with your actual Chainstack key.

### 4. Validate and Restart NGINX

```bash
nginx -t
brew services restart nginx
```

### 5. Test RPC Proxy

```bash
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"1.0","id":"curltest","method":"getblockcount","params":[]}'
```

Expected output:

```json
{"result": <block_number>, "error": null, "id": "curltest"}
```

## Running RabbitMQ

The indexer uses RabbitMQ as a message queue. Start it using the provided script:

```bash
./bin/rabbitmq-startup.sh
```

Ensure Docker is running before executing this command.

## Environment Configuration

Create a `.env` file in the root directory with the following variables:

```dotenv
# MongoDB Atlas Connection
DB_USERNAME=<your_db_username>
DB_PASSWORD=<your_db_password>
DB_ADDRESS="mongodb+srv://cluster0.<shard>.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
DB_DB_NAME=babylon-indexer-test

# Bitcoind RPC (adjust based on setup)
BTC_RPCHOST=127.0.0.1:38332           # For local Signet
# BTC_RPCHOST=127.0.0.1:8545          # For remote Mainnet via NGINX

BTC_RPCUSER=admin
BTC_RPCPASS=password
BTC_NETPARAMS=signet                  # Use 'mainnet' for Mainnet RPC

# Babylon Network
BBN_RPC__ADDR=https://babylon-testnet-rpc-archive-1.nodes.guru # User a Mainnet RPC for 'babylon genesis mainnet'
```

## Running the Indexer

Finally, run the indexer using the following command. The `config-local.yml` file serves as a base, and actual values are overridden via the `.env` file.

```bash
go run cmd/babylon-staking-indexer/main.go --config config/config-local.yml
```

If everything is set up correctly, the indexer will start and connect to MongoDB, Babylon and Bitcoind successfully.
