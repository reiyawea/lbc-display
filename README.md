# lbc-display
A simple and naive project which let me know the current exchange rate in time.
# system structure
A server script runs on a linux machine (typically a raspberry pi), fetching bitcoin exchange rate periodically and storing in a csv file.
A client script runs on any device supporting TCP socket, access the server and get the latest exchange rate.
If the server owns a public network IP, the client could access the server from anywhere on earth.
# why making such an architecture
Server parses the json string of market data from localbitcoins.com (which is very long!) and picks out the most interested content (the most attractive price), so that the client device with even less than 20KB RAM could fetch and display the price.
I implemented the client device with ESP8266 and an OLED display, without an external MCU.
# some details on communication
An AES-ECB encryption is implemented just for fun. Server and client share an AES-128 key.
1. client establish the TCP connection
2. client send a 16-byte random string encrypted by the pre-shared key
3. server decrypts the random string
4. server generates the response string
5. server encrypts the response string and send the cipher text to client
6. client decrypts the response and display it
7. server close the TCP connection
