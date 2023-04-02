import json
import requests
import os
import base64
import binascii

# System call
os.system("")

# Class of different styles
class style():
    BLACK = '\033[30m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'
    UNDERLINE = '\033[4m'
    RESET = '\033[0m'


while True:
    print("\n======================================")
    print("Please select an option:")
    print("1. Submit PFB transaction")
    print("2. Query namespaceshare")
    print("3. Exit")

    choice = input("Enter your choice (1, 2, or 3): ")

    if choice == '1':        
        print("\nKindly provide your PFB data:")
        namespace_id = input("Enter your namespace: ")
        data = input("Enter your data: ")
        print("\nYour transaction is executing .......")
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
		
		# Print out detail transaction
        print(f"Your namespaceid " + style.GREEN + f"{namespace_id}" + style.RESET + " has been submitted at block height " + style.GREEN + f"{height}" + style.RESET)
        print(f"Your transaction hash is " + style.GREEN + f"{txh}" + style.RESET)		        
        print(f"TXH link :" + style.YELLOW + f"https://testnet.mintscan.io/celestia-incentivized-testnet/txs/{txh}" + style.RESET)        
    
    elif choice == '2':
        print("\nKindly provide your info:")
        namespace_id = input("Enter your namespace: ")
        blockheight = input("Enter submitted blockheight: ")
        shares_url = f"https://celestia.candy-crush-saga.xyz/namespaced_shares/{namespace_id}/height/{blockheight}"; # API for getting namespaceshares
        data_url = f"https://celestia.candy-crush-saga.xyz/namespaced_data/{namespace_id}/height/{blockheight}"; # API for getting original submitted data
		
        shares_response = requests.get(shares_url) # # Get shares data
        data_response = requests.get(data_url) # Get original submitted data
		
		# Convert original data from base64 to hexa format
        json_data_response = json.loads(data_response.text)
        orig_data = json_data_response['data'][0]
        decoded_bytes = base64.b64decode(orig_data)
        hex_orig_data = binascii.hexlify(decoded_bytes).decode("utf-8")
		
		# Print out information
        print(f"\nYour original submitted hex data at blockheight " + style.GREEN + f"{blockheight}" + style.RESET + " is " + style.GREEN + f"{hex_orig_data}" + style.RESET)				
        print(style.YELLOW + "\nYour namespaceshare has detail data as below" + style.RESET)
        print(json.dumps(shares_response.json(), indent=4, sort_keys=True, ensure_ascii=False))
		
    elif choice == '3':
        # Exit program        
        print(style.GREEN + "\nExiting program...." + style.RESET)
        break
    
    else:
        # Invalid choice
        print("\nInvalid choice. Please select option 1, 2, or 3.")
