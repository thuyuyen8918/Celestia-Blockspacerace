import json
import requests
import os

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
        namespaceshare = input("Enter your namespace: ")
        blockheight = input("Enter submitted blockheight: ")
        url = f"https://celestia.candy-crush-saga.xyz/namespaced_shares/{namespaceshare}/height/{blockheight}";        
        response = requests.get(url)
		
		# Print out detail data
        print(style.GREEN + "\nYour namespaceshare has detail data as below" + style.RESET)
        print(json.dumps(response.json(), indent=4, sort_keys=True, ensure_ascii=False))
		
    elif choice == '3':
        # Exit program        
        print(style.GREEN + "\nExiting program...." + style.RESET)
        break
    
    else:
        # Invalid choice
        print("\nInvalid choice. Please select option 1, 2, or 3.")
