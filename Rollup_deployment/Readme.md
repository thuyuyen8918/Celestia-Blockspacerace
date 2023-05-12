## A. Introduction
- The part is used to setup a rollup chain `Archway` - converted from Cosmos-SDK L1 appchain `Archway` - on top of Celestia DA layer.
- In this guide, we will setup a Sequencer node and a Full node on `Archway` rollup chain

## B. Installation of Rollup chain
### 1. Prerequisite
- A Celestia DA Full/Light node should be available. You can refer the [link](https://docs.celestia.org/nodes/celestia-node) for setting up your DA node. 
- I will use my owned DA Fullnode in this guide.

### 2. Notes
- In this guide, i will use Rollkit SDK version `v0.45.10-rollkit-v0.7.3-no-fraud-proofs` and Rollkit Tendermint version `v0.34.22-0.20221202214355-3605c597500d`.
- However Rollkit SDK version should be adjusted to adapt with `Archway` Cosmos SDK. I have added a adjusted code into scripts of rollup depoyment.
- Currently Rollkit only support a Sequencer Node.

### 3. Setup Sequencer Node of `Archway` rollupchain
- Download script and run it to setup automatically the sequencer node on top of Celestia Blockspacerace DA network.
```
cd $HOME
git clone https://github.com/thuyuyen8918/Celestia-Blockspacerace
cd Celestia-Blockspacerace/Rollup_deployment/
chmod +x archway_sequencer.sh
./archway_sequencer.sh
```
- Then script will automatically install prerequiste software, download repo and compile binary file of Rollup chain `archwayd`.
  ![image](https://github.com/thuyuyen8918/Celestia-Blockspacerace/assets/109055532/0a3646fa-5d2c-4a65-8e2d-1e9c0fd920d7)

- If you setup previous rollup chain `Archwayd` and wanna re-run, kindly select your choice: `y` for new setup and `n` for re-run previous one.
  ![image](https://github.com/thuyuyen8918/Celestia-Blockspacerace/assets/109055532/9c119bb1-caaa-417d-98d8-22ca79f8108b)

- If you setup new sequencer node, script will continue to setup new rollup chain `archwayd` automatically. Please provide underlying DA node in which your rollup chain connects to, `namespace`,...etc
  ![image](https://github.com/thuyuyen8918/Celestia-Blockspacerace/assets/109055532/3c7f0339-44ab-405a-a9c5-a032f96d1452)

- After finish setting up, basic infomation of your rollup chain `Archway` will be shown. You can use these information to setup your Rollup Full node.
  ![image](https://github.com/thuyuyen8918/Celestia-Blockspacerace/assets/109055532/9427015f-81f0-46f2-b221-985a67b90f4c)

- To check sequencer log, use below command
```
sudo journalctl -u archway-sequencer.service -f -o cat
```
  ![image](https://github.com/thuyuyen8918/Celestia-Blockspacerace/assets/109055532/3c7e9e08-2b98-4e22-bcdd-188f00ad081d).

- Check status of sequencer
```
archwayd status | jq
```
  ![image](https://github.com/thuyuyen8918/Celestia-Blockspacerace/assets/109055532/a7b07ed9-ad31-496e-98de-29778f86470d)


### 4. Setup Full Node of `Archway` rollupchain
#### 4.1 Prepration
- You can setup another Celestia DA node for your Rollup Fullnode.
- In last step of sequencer setup show some basic function of your rollup chain, later u will use it to setup your node.
  ![image](https://github.com/thuyuyen8918/Celestia-Blockspacerace/assets/109055532/9427015f-81f0-46f2-b221-985a67b90f4c)

#### 4.2 Setup Fullnode (OPTIONAL)
- Collect Node ID, IP and port of Sequencer node from sequencer server
```
# show sequencer id
archwayd status | jq -r '.NodeInfo.id'

# show sequencer p2p peer info
echo -e "$(curl -s ifconfig.me):$(archwayd status | jq -r ".NodeInfo.listen_addr" | awk -F\/ '{print $NF}')"
```
- Download script and run it to setup automatically the sequencer node on top of Celestia Blockspacerace DA network.
```
cd $HOME
git clone https://github.com/thuyuyen8918/Celestia-Blockspacerace
cd Celestia-Blockspacerace/Rollup_deployment/
chmod +x archway_fullnode.sh
./archway_fullnode.sh
```

- Script will compile binary file of `Archwayd` automatically, then you need to fill in information of your rollup chain
  ![image](https://github.com/thuyuyen8918/Celestia-Blockspacerace/assets/109055532/dd7a3977-b102-450c-995e-bafcaa13f99e)

- After finish fullnode setup, you need to download the file `genesis.json` from server of sequencer node, then upload to the path `/root/.archway/config` of fullnode server.

- Start your fullnode 
```
sudo systemctl restart archway-fullnode.service
sudo journalctl -u archway-fullnode.service -f -o cat
```
  ![image](https://github.com/thuyuyen8918/Celestia-Blockspacerace/assets/109055532/2cb36278-1c98-4b3e-8982-3e2035ae0527)

- **However, now synchronization of fullnode is unstable, sometimes fullnode gets stuck if it failed to retrieve block data as below error**.
  ![image](https://github.com/thuyuyen8918/Celestia-Blockspacerace/assets/109055532/50cf7474-f411-45a5-8ed0-24be75e1e46c)
  
  In that case, you need to re-run script `archway_fullnode.sh`, then select `n` to reset your fullnode
  ![image](https://github.com/thuyuyen8918/Celestia-Blockspacerace/assets/109055532/7b5e08a3-5650-454d-89f0-5f2d1d1f43fd)



