#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OVER SSH PLUS - WEBSOCKET PROXY (PYTHON 3)
High-performance WebSocket to SSH/Dropbear tunnel forwarder.
"""
import socket
import select
import sys
import time
import getopt
from threading import Thread, Lock

LISTENING_ADDR = '0.0.0.0'
try:
    LISTENING_PORT = int(sys.argv[1])
except Exception:
    LISTENING_PORT = 80

BUFLEN = 65536
TIMEOUT = 60
DEFAULT_HOST = "127.0.0.1:22"
PASS = ''

MSG = 'OVER_SSH_PLUS'
RESPONSE = f"HTTP/1.1 101 {MSG}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n".encode('utf-8')


class Server(Thread):
    def __init__(self, host, port):
        super().__init__()
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        try:
            self.soc.bind((self.host, self.port))
            self.soc.listen(128)
            self.running = True
        except Exception as e:
            print(f"[!] Erro ao iniciar na porta {self.port}: {e}")
            return

        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(True)
                    conn = ConnectionHandler(c, self, addr)
                    conn.daemon = True
                    conn.start()
                    self.addConn(conn)
                except socket.timeout:
                    continue
                except Exception:
                    break
        finally:
            self.running = False
            try:
                self.soc.close()
            except Exception:
                pass

    def addConn(self, conn):
        with self.threadsLock:
            if self.running:
                self.threads.append(conn)

    def removeConn(self, conn):
        with self.threadsLock:
            if conn in self.threads:
                self.threads.remove(conn)

    def close(self):
        self.running = False
        with self.threadsLock:
            for c in list(self.threads):
                c.close()


class ConnectionHandler(Thread):
    def __init__(self, socClient, server, addr):
        super().__init__()
        self.clientClosed = False
        self.targetClosed = True
        self.client = socClient
        self.server = server
        self.target = None
        self.addr = addr

    def close(self):
        if not self.clientClosed:
            try:
                self.client.shutdown(socket.SHUT_RDWR)
            except Exception:
                pass
            try:
                self.client.close()
            except Exception:
                pass
            self.clientClosed = True

        if not self.targetClosed and self.target:
            try:
                self.target.shutdown(socket.SHUT_RDWR)
            except Exception:
                pass
            try:
                self.target.close()
            except Exception:
                pass
            self.targetClosed = True

    def run(self):
        try:
            data = self.client.recv(BUFLEN)
            if not data:
                return

            header_str = data.decode('utf-8', errors='ignore')

            # Parse X-Real-Host ou Host
            host_port = self.find_header(header_str, 'X-Real-Host')
            if not host_port:
                host_port = DEFAULT_HOST

            passwd = self.find_header(header_str, 'X-Pass')
            if PASS and passwd != PASS:
                self.client.sendall(b"HTTP/1.1 400 WrongPass!\r\n\r\n")
                return

            self.connect_target(host_port)
            self.client.sendall(RESPONSE)
            self.forward_data()

        except Exception:
            pass
        finally:
            self.close()
            self.server.removeConn(self)

    def find_header(self, text, header):
        h_lower = header.lower() + ":"
        for line in text.split('\r\n'):
            if line.lower().startswith(h_lower):
                return line.split(':', 1)[1].strip()
        return ''

    def connect_target(self, host_port):
        if ':' in host_port:
            host, port_str = host_port.split(':', 1)
            port = int(port_str)
        else:
            host = host_port
            port = 22

        addr_info = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)[0]
        self.target = socket.socket(addr_info[0], addr_info[1], addr_info[2])
        self.target.settimeout(10)
        self.target.connect(addr_info[4])
        self.target.settimeout(None)
        self.targetClosed = False

    def forward_data(self):
        socs = [self.client, self.target]
        idle_count = 0
        while True:
            r, _, w_err = select.select(socs, [], socs, 3)
            if w_err:
                break
            if r:
                idle_count = 0
                for s in r:
                    try:
                        data = s.recv(BUFLEN)
                        if not data:
                            return
                        if s is self.client:
                            self.target.sendall(data)
                        else:
                            self.client.sendall(data)
                    except Exception:
                        return
            else:
                idle_count += 3
                if idle_count >= TIMEOUT * 10:
                    break


def parse_args(argv):
    global LISTENING_ADDR, LISTENING_PORT
    try:
        opts, _ = getopt.getopt(argv, "hb:p:", ["bind=", "port="])
    except getopt.GetoptError:
        sys.exit(2)
    for opt, arg in opts:
        if opt in ("-b", "--bind"):
            LISTENING_ADDR = arg
        elif opt in ("-p", "--port"):
            LISTENING_PORT = int(arg)


def main():
    parse_args(sys.argv[1:])
    print(f"\033[1;32m[✓] INICIANDO PROXY WEBSOCKET PYTHON 3 NA PORTA {LISTENING_PORT}...\033[0m")
    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.daemon = True
    server.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nParando Proxy WebSocket...")
        server.close()


if __name__ == '__main__':
    main()

