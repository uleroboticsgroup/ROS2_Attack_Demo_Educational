#!/bin/bash

## IPTABLES para la redireccion ##
sudo iptables -A INPUT -p udp --sport 41897 -j NFQUEUE --queue-num 0
sudo iptables -A OUTPUT -p udp --dport 7429 -j NFQUEUE --queue-num 0

## Funcion que convierte hexadecimal a char ##
hex_to_char(){
	echo -ne "\x$1";
}

## Llamada a la herramienta nfqsed ##

sudo ./nfqsed -v -x /e03f/e0bf 


