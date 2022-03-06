#include "stdafx.h"
#define _WINSOCK_DEPRECATED_NO_WARNINGS
#include <stdio.h>
#include <winsock2.h>
#include <fstream>
#include <sstream>
#include <string>
#include <iostream>
#include <windows.h>
#include <ctime>
 
#pragma comment(lib,"ws2_32.lib") //Winsock Library
#pragma warning(disable:4996)// declares _SCL_SECURE_NO_WARNINGS 

#define SERVER "172.17.199.12"  //ip address of udp server
#define BUFLEN 799  //Max length of buffer
#define PORT 23   //The port on which to listen for incoming data
using namespace std;
int main(void)
{
    struct sockaddr_in si_other;
    int s, slen=sizeof(si_other);
    char buf[BUFLEN];
    char message[BUFLEN];
    WSADATA wsa;
 
    //Initialise winsock
    printf("\nInitialising Winsock...");
    if (WSAStartup(MAKEWORD(2,2),&wsa) != 0)
    {
        printf("Failed. Error Code : %d",WSAGetLastError());
        exit(EXIT_FAILURE);
    }
    printf("Initialised.\n");
     
    //create socket
    if ( (s=socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)) == SOCKET_ERROR)
    {
        printf("socket() failed with error code : %d" , WSAGetLastError());
        exit(EXIT_FAILURE);
    }
     
    //setup address structure
    memset((char *) &si_other, 0, sizeof(si_other));
    si_other.sin_family = AF_INET;
    si_other.sin_port = htons(PORT);
    si_other.sin_addr.S_un.S_addr = inet_addr(SERVER);

	ifstream fid("../Data/value09.h");
	string str, fileContents;
	while (getline(fid, str)) {
		fileContents += str;
		fileContents.push_back('\n');
	}

	int count = 0;
    //start communication
	int maxUDPpacketSize = BUFLEN, lastPos = 0;
	auto begin = clock();
    while(lastPos + maxUDPpacketSize < fileContents.length()) {
		//string ssStr = fileContents.substr(lastPos, maxUDPpacketSize);

		string ssStr;
		int numDigits = 0, toAnalyze = maxUDPpacketSize;
		while (toAnalyze > 0) {
			numDigits++;
			toAnalyze = toAnalyze / 10;
		}
	
		for (int i = 0; i < maxUDPpacketSize - numDigits; i++) {
			ssStr.append(" ");
		}
		
		snprintf(message, BUFLEN, "%s%d \0", ssStr.c_str(), maxUDPpacketSize);

		lastPos = lastPos + maxUDPpacketSize;
		//cout << sizeof(message) << endl;
        //send the message
        if (sendto(s, message, strlen(message) , 0 , (struct sockaddr *) &si_other, slen) == SOCKET_ERROR) {
            printf("sendto() failed with error code : %d" , WSAGetLastError());
            exit(EXIT_FAILURE);
        }
		Sleep(11);
		count++;
    }
	auto end = clock();
	cout << count << endl;
	cout << "time elapsed: " << double(difftime(end, begin)) << endl;
 
    closesocket(s);
    WSACleanup();
 
    return 0;
}