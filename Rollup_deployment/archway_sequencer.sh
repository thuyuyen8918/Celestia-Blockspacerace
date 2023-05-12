#!/bin/bash

# Setup chain & wallet parameter
KEYS[0]="wallet0"
KEYS[1]="wallet1"
KEYS[2]="wallet2"
CHAINID="archwayrollup-1"
MONIKER="rollup_sequencer"
KEYRING="test"
DENOM="uconst"

# Set dedicated home directory for the archway instance
HOMEDIR="$HOME/.archway"

# Path variables
CONFIG=$HOMEDIR/config/config.toml
APP_TOML=$HOMEDIR/config/app.toml
GENESIS=$HOMEDIR/config/genesis.json
TMP_GENESIS=$HOMEDIR/config/tmp_genesis.json

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
# SDK_VER=$(sed -n 's/.*github.com\/cosmos\/cosmos-sdk //p' $HOME/archway/go.mod | head -n 1 | awk -F"\." '{print $1"."$2}')
# ROLLKIT_SDK_VER=$(curl -s https://api.github.com/repos/rollkit/cosmos-sdk/releases | jq -r '.[].name' | sort -u | grep $SDK_VER | tail -n 1)
ROLLKIT_SDK_VER="v0.45.10-rollkit-v0.7.3-no-fraud-proofs"

# TENDERMINT_VER=$(sed -n 's/.*github.com\/tendermint\/tendermint //p' $HOME/archway/go.mod | head -n 1 |  awk -F"\." '{print $1"."$2}')
# ROLLKIT_TENDERMINT_VER=$(curl -s https://api.github.com/repos/rollkit/tendermint/tags | jq -r '.[].name' | grep $TENDERMINT_VER | sort -t. -k 1,1V -k 2,2V -k 3,3V | tail -n 1)
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
systemctl is-active archway-sequencer.service && systemctl stop archway-sequencer.service

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

# Set client config
archwayd config keyring-backend $KEYRING --home "$HOMEDIR"
archwayd config chain-id $CHAINID --home "$HOMEDIR"

# Set moniker and chain-id (Moniker can be anything, chain-id must be an integer)
archwayd init $MONIKER -o --chain-id $CHAINID --home "$HOMEDIR"

# If keys exist they should be deleted
for KEY in "${KEYS[@]}"; do
	archwayd keys add "$KEY" --keyring-backend $KEYRING --home "$HOMEDIR"
done

# Change parameter token denominations to $DENOM
jq ".app_state[\"staking\"][\"params\"][\"bond_denom\"]=\"$DENOM\"" "$GENESIS" > "$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
jq ".app_state[\"crisis\"][\"constant_fee\"][\"denom\"]=\"$DENOM\"" "$GENESIS" > "$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
jq ".app_state[\"gov\"][\"deposit_params\"][\"min_deposit\"][0][\"denom\"]=\"$DENOM\"" "$GENESIS" > "$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"
jq ".app_state[\"inflation\"][\"params\"][\"mint_denom\"]=\"$DENOM\"" "$GENESIS" > "$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

# Set gas limit in genesis
jq '.consensus_params["block"]["max_gas"]="10000000"' "$GENESIS" > "$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

# Change proposal periods to pass within a reasonable time for local testing
sed -i.bak 's/"max_deposit_period": "172800s"/"max_deposit_period": "30s"/g' "$HOMEDIR"/config/genesis.json
sed -i.bak 's/"voting_period": "172800s"/"voting_period": "30s"/g' "$HOMEDIR"/config/genesis.json

# set custom pruning settings
sed -i.bak 's/pruning = "default"/pruning = "custom"/g' "$APP_TOML"
sed -i.bak 's/pruning-keep-recent = "0"/pruning-keep-recent = "2"/g' "$APP_TOML"
sed -i.bak 's/pruning-interval = "0"/pruning-interval = "10"/g' "$APP_TOML"

# Allocate genesis accounts (cosmos formatted addresses)
for KEY in "${KEYS[@]}"; do
	archwayd add-genesis-account "$KEY" 100000000000000000000000000${DENOM} --keyring-backend $KEYRING --home "$HOMEDIR"
done

# bc is required to add these big numbers
total_supply=$(echo "${#KEYS[@]} * 100000000000000000000000000 " | bc)
jq -r --arg total_supply "$total_supply" '.app_state["bank"]["supply"][0]["amount"]=$total_supply' "$GENESIS" >"$TMP_GENESIS" && mv "$TMP_GENESIS" "$GENESIS"

# Sign genesis transaction
archwayd gentx "${KEYS[0]}" 1000000000000000000000${DENOM} --keyring-backend $KEYRING --chain-id $CHAINID --home "$HOMEDIR"

################################################################################################
# In case you want to create multiple validators at genesis
# 1. Back to `archwayd keys add` step, init more keys
# 2. Back to `archwayd add-genesis-account` step, add balance for those
# 3. Clone this ~/.archway_rollup home directory into some others, such as `~/.archway_rollup_1`, `~/.archway_rollup_2`,...
# 4. Run `gentx` in each of those folders
# 5. Copy the `gentx-*` folders under `~/.archway_rollup_n/config/gentx/` folders into the original `~/.archway_rollup/config/gentx`
################################################################################################

# Collect genesis tx
archwayd collect-gentxs --home "$HOMEDIR"

# Run this to ensure everything worked and that the genesis file is setup correctly
archwayd validate-genesis --home "$HOMEDIR"

echo -e "\nInput DA node (http://xxx.xxx.xxx.xxx:26659): "
read DA_URL

# Input Namespace
echo -e "\nInput Namespace ID (Leave blank if new one): "
read NAMESPACE_ID

if [[ $NAMESPACE_ID == "" ]] ;then
        NAMESPACE_ID=$(echo $RANDOM | md5sum | head -c 16; echo;)
        echo -e "\nNamespace is \033[0;31m$NAMESPACE_ID\033[0m\n"
fi

# Input Rollkit Blocktime
echo -e "\nInput Blocktime of Rollup chain: "
read ROLLUP_BLOCKTIME

if [[ $ROL_BLOCKTIME == "" ]] ; then
        ROLLUP_BLOCKTIME=5;
        echo -e "\nDefault blocktime of rollup chain: \033[0;31m${ROLLUP_BLOCKTIME}s\033[0m\n"
fi

# Input DA Blocktime
echo -e "\nInput Blocktime of DA network: "
read DA_BLOCKTIME

if [[ $DA_BLOCKTIME == "" ]]; then
        DA_BLOCKTIME=10;
        echo -e "\nDefault blocktime of DA network: \033[0;31m${DA_BLOCKTIME}s\033[0m\n"
fi

# Check current block height of DA network of Celestia-Blockspacerace
DA_BLOCK_HEIGHT=$(curl https://rpc-blockspacerace.pops.one/block | jq -r '.result.block.header.height')
echo $DA_BLOCK_HEIGHT

# Create systemD service
sudo tee /etc/systemd/system/archway-sequencer.service > /dev/null <<EOF
[Unit]
Description=Archwayd rollkup
After=network-online.target

[Service]
User=$USER
ExecStart=$(which archwayd) start --rollkit.aggregator true \
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
            --p2p.seed_mode \
            --log_level debug
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable archway-sequencer.service
sudo systemctl restart archway-sequencer.service

echo -e "\n\033[0;32mFnished setup a sequencer of Archway Cosmos-SDK rollup on Celestia BlockspaceRace DA Network !! \033[0m\n"; sleep 1;
echo -e "\nInfo of your chain
- Chain id : \033[0;31m${CHAINID}\033[0m
- Moniker: \033[0;31m${MONIKER}\033[0m
- Denom: \033[0;31m${DENOM}\033[0m
- Rollup blocktime: \033[0;31m${ROLLUP_BLOCKTIME}\033[0m
- DA blocktime: \033[0;31m${DA_BLOCKTIME}\033[0m
- NamespaceID: \033[0;31m${NAMESPACE_ID}\033[0m
"

echo -e "\nCheck log of Rollup node: \033[0;31msudo journalctl -u archway-sequencer.service -f -o cat\033[0m"

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
        sed -i.bak -e  "s/rollkit.da_start_height [0-9]* /rollkit.da_start_height $DA_BLOCK_HEIGHT /g; s/\"fee\":[0-9]*,/\"fee\":$FEE,/g" /etc/systemd/system/archway-sequencer.service

        sudo systemctl daemon-reload
        sudo systemctl restart archway-sequencer
        sleep 10;

        # Query current DA block height
        DA_BLOCK_HEIGHT=$(curl https://rpc-blockspacerace.pops.one/block | jq -r '.result.block.header.height')
        echo $DA_BLOCK_HEIGHT
        sleep 1;

        # Rollback fee to save fund
        FEE=100
        sed -i.bak -e  "s/rollkit.da_start_height [0-9]* /rollkit.da_start_height $DA_BLOCK_HEIGHT /g; s/\"fee\":[0-9]*,/\"fee\":$FEE,/g" /etc/systemd/system/archway-sequencer.service
        sudo systemctl daemon-reload
        sudo systemctl restart archway-sequencer

fi

