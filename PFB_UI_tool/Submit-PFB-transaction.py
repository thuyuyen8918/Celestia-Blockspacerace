import json
import requests

while True:
    print("======================================")
    print("Please select an option:")
    print("1. Submit PFB transaction")
    print("2. Query namespaceshare")
    print("3. Exit")

    choice = input("Enter your choice (1, 2, or 3): ")

    if choice == '1':        
        namespace_id = input("Enter your namespace: ")
        data = input("Enter your data: ")
        url = 'https://celestia.candy-crush-saga.xyz/submit_pfb'
        payload = {
            "namespace_id": namespace_id,
            "data": data,
            "gas_limit": 80000,
            "fee": 2000
        }
        
        headers = {'Content-Type': 'application/json'}
        response = requests.post(url, data=json.dumps(payload), headers=headers)
        # Print response from server in JSON format
        # print(json.dumps(response.json(), indent=4))

		# Extract height from response and print it out
        json_response = json.loads(response.text)
        height = json_response['height']
        txh = json_response['txhash']

        print(f"Your namespaceid {namespace_id} has been submitted at block height {height}.")
        print(f"Your transaction hash is {txh}.")		        
        print(f"https://testnet.mintscan.io/celestia-incentivized-testnet/txs/{txh}")        
    
    elif choice == '2':
        namespaceshare = input("Enter your namespace: ")
        blockheight = input("Enter submitted blockheight: ")
        url = f"https://celestia.candy-crush-saga.xyz/namespaced_shares/{namespaceshare}/height/{blockheight}";        
        response = requests.get(url)
        print(json.dumps(response.json(), indent=4))
		
    elif choice == '3':
        # Exit program
        print("Exiting program...")
        break
    
    else:
        # Invalid choice
        print("Invalid choice. Please select option 1, 2, or 3.")
