To setup the CertProff smart contracts, there are a few steps to take:
1. Connect to the metamask Sepolia Testnet through the browserwallet option (must have the metamask extension)
2. deploy the Institution contract with the desired metamask wallet (shall be referred to as account1)
3. copy the institutionContract adress and deploy the registry contract with this address.
4. copy the registryContract address and use that to deploy the credentialToken and verification contracts
5. IMPORTANT - in the index.html file, update the contract addresses with the current deployed addresses of the contracts (lines 202-216)
6. in command line, navigate to the Assignment3 directory and run lite-server
7. throught the metamask extension, select account1, scroll to the bottom of the html front end, and select 'connect metamask'
8. Now, you should be able to interact with the contracts.
NOTE: each time an account is switched, use the connect metamask button afterwards.
