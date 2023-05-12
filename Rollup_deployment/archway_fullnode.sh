#!/bin/bash

# Set dedicated home directory for the archway instance
HOMEDIR="$HOME/.archway"

# Installing Prerequisites
echo -e "\e[1m\e[32m1. Updating packages... \e[0m" && sleep 1
sudo apt-get update && sudo apt upgrade -y

echo -e "\e[1m\e[32m2. Installing dependencies... \e[0m" && sleep 1
sudo apt install curl build-essential git wget jq make gcc tmux -y

# install go
ver="1.19.2"
cd $HOME
# Check if Go version is already 1.19
if [[ "$(go version)" != *"go$ver"* ]]; then
  echo "Installing Go version $ver"
  wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
  rm "go$ver.linux-amd64.tar.gz"
  echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
  source ~/.bash_profile
else
  echo "Go version $ver is already installed"
fi
go version


# Download Archway repo
echo -e "\e[1m\e[32m3. Downloading Archway repo... \e[0m" && sleep 1
cd $HOME
rm -rf archway
git clone https://github.com/archway-network/archway.git
cd archway
git checkout v0.4.0

# Converting to Rollkit SDK
ROLLKIT_SDK_VER="v0.45.10-rollkit-v0.7.3-no-fraud-proofs"
ROLLKIT_TENDERMINT_VER='v0.34.22-0.20221202214355-3605c597500d'

echo -e "\n\e[1m\e[32m4. Compiling binary file... \e[0m" && sleep 1
rm -rf $HOME/go/pkg/mod/github.com/rollkit/cosmos-sdk\@$ROLLKIT_SDK_VER
go mod edit -replace github.com/cosmos/cosmos-sdk=github.com/rollkit/cosmos-sdk@$ROLLKIT_SDK_VER
go mod edit -replace github.com/tendermint/tendermint=github.com/celestiaorg/tendermint@$ROLLKIT_TENDERMINT_VER
go mod tidy
go mod download

# Adjust rollkit code to adapt with archway chain
cd $HOME/go/pkg/mod/github.com/rollkit/cosmos-sdk\@$ROLLKIT_SDK_VER/store/iavl/
sed -i.bak '267,277 s/^/\/\//' store.go && sed -i.bak '278i func (st *Store) Export(version int64) (*iavl.Exporter, error) {\n    istore, err := st.GetImmutable(version)\n    if err != nil {\n        return nil, fmt.Errorf("failed to get immutable store for version %v: %w", version, err)\n    }\n    tree, ok := istore.tree.(*immutableTree)\n     if !ok || tree == nil {\n        return nil, fmt.Errorf("failed to fetch tree for version %v", version)\n    }\n\n    exporter, err := tree.Export()\n    if err != nil {\n        return nil, fmt.Errorf("failed to export tree for version %v: %w", version, err)\n    }\n\n    return exporter, nil\n}' store.go

cd $HOME/archway && make install

# Check whether Rollkit chain is running. Stop and remove existed one
systemctl is-active archway-fullnode.service && systemctl stop archway-fullnode.service

# User prompt if an existing local node configuration is found.
if [ -d "$HOMEDIR" ]; then
      printf "\nAn existing folder at '%s' was found. You can choose to delete this folder and start a new local node with new keys from genesis. When declined, the existing local node is started. \n" "$HOMEDIR"
      echo "Overwrite the existing configuration and start a new local node? [y/n]"
      read -r overwrite
else
      overwrite="Y"
fi

if [[ $overwrite == "y" || $overwrite == "Y" ]];
then
# Remove the previous folder
rm -rf "$HOMEDIR"

# Setup chain & wallet parameter
CHAINID="archwayrollup-1"
KEYRING="test"
DENOM="uconst"

read -p "Your moniker name: " MONIKER
read -p "Your namespace id: " NAMESPACE_ID
read -p "Your sequencer id: " SEQUENCER_ID
read -p "Your sequencer P2P Info: " SEQUENCER_IP_PORT
read -p "Your DA UR link (Ex: http://x.x.x.x:26659): " DA_URL
read -p "Your Rollup blocktime: " ROLLUP_BLOCKTIME
read -p "Your DA blocktime: " DA_BLOCKTIME


# Set client config
archwayd config keyring-backend $KEYRING --home "$HOMEDIR"
archwayd config chain-id $CHAINID --home "$HOMEDIR"

# Set moniker and chain-id (Moniker can be anything, chain-id must be an integer)
archwayd init $MONIKER --chain-id $CHAINID --home "$HOMEDIR"

# Check current block height of DA network of Celestia-Blockspacerace
DA_BLOCK_HEIGHT=$(curl https://rpc-blockspacerace.pops.one/block | jq -r '.result.block.header.height')
echo $DA_BLOCK_HEIGHT

# Create systemD service
sudo tee /etc/systemd/system/archway-fullnode.service > /dev/null <<EOF
[Unit]
Description=Archwayd Fullnode
After=network-online.target

[Service]
User=$USER
ExecStart=$(which archwayd) start --home ${HOMEDIR}  \
            --rollkit.block_time ${ROLLUP_BLOCKTIME}s \
            --rollkit.da_block_time ${DA_BLOCKTIME}s \
            --rollkit.da_layer celestia \
            --rollkit.da_config='{"base_url":"$DA_URL","timeout":60000000000,"fee":100,"gas_limit":100000}' \
            --rollkit.namespace_id $NAMESPACE_ID  \
            --rollkit.da_start_height $DA_BLOCK_HEIGHT \
            --p2p.laddr "0.0.0.0:26656" \
            --rpc.laddr "tcp://0.0.0.0:26657" \
            --grpc.address "0.0.0.0:9090" \
            --grpc-web.address "0.0.0.0:9091" \
            --p2p.seeds "${SEQUENCER_ID}@${SEQUENCER_IP_PORT}" \
            --log_level debug
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable archway-fullnode.service
sudo systemctl restart archway-fullnode.service

echo -e "\n\033[0;32mFnished setup a fullnode of Archway Cosmos-SDK rollup on Celestia BlockspaceRace DA Network !! \033[0m\n"; sleep 1;
echo -e "\nInfo of your chain
- Chain id : \033[0;31m${CHAINID}\033[0m
- Moniker: \033[0;31m${MONIKER}\033[0m
- Denom: \033[0;31m${DENOM}\033[0m
- Rollup blocktime: \033[0;31m${ROLLUP_BLOCKTIME}\033[0m
- DA blocktime: \033[0;31m${DA_BLOCKTIME}\033[0m
- NamespaceID: \033[0;31m${NAMESPACE_ID}\033[0m
"

echo -e "\nKindly download genesis json file in the path /root/.archway/config/ of sequencer server, then upload to your path ${HOMEDIR}/config of fullnode server"
echo -e "\nStart Rollup Fullnode: \033[0;31msudo systemctl restart archway-fullnode.service\033[0m"
echo -e "\nCheck log of Rollup node: \033[0;31msudo journalctl -u archway-fullnode.service -f -o cat\033[0m"

fi

# Re-run a existing Cosmos Rollup chain
if [[ $overwrite == "n" || $overwrite == "N" ]];
then
        # Query current DA block height
        DA_BLOCK_HEIGHT=$(curl https://rpc-blockspacerace.pops.one/block | jq -r '.result.block.header.height')
        echo $DA_BLOCK_HEIGHT
        sleep 1;

        # Update to current blockheight and increase fee to avoid code 19
        FEE=1000
        sed -i.bak -e  "s/rollkit.da_start_height [0-9]* /rollkit.da_start_height $DA_BLOCK_HEIGHT /g; s/\"fee\":[0-9]*,/\"fee\":$FEE,/g" /etc/systemd/system/archway-fullnode.service

        sudo systemctl daemon-reload
        sudo systemctl restart archway-fullnode
        sleep 10;

        # Query current DA block height
        DA_BLOCK_HEIGHT=$(curl https://rpc-blockspacerace.pops.one/block | jq -r '.result.block.header.height')
        echo $DA_BLOCK_HEIGHT
        sleep 1;

        # Rollback fee to save fund
        FEE=100
        sed -i.bak -e  "s/rollkit.da_start_height [0-9]* /rollkit.da_start_height $DA_BLOCK_HEIGHT /g; s/\"fee\":[0-9]*,/\"fee\":$FEE,/g" /etc/systemd/system/archway-fullnode.service
        sudo systemctl daemon-reload
        sudo systemctl restart archway-fullnode

fi

