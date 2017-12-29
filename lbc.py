import requests, time, socket, threading, random, struct
from Crypto.Cipher import AES

class Price():
    def __init__(this):
        this.buy_price = None
        this.sell_price = None
        this.buy_price_diff = 0
        this.sell_price_diff = 0
        this.update_time = int(time.time()-time.timezone)
    def update(this, buy_price, sell_price):
        if this.buy_price:
            this.buy_price_diff = buy_price - this.buy_price
            this.sell_price_diff = sell_price - this.sell_price
        this.buy_price = buy_price
        this.sell_price = sell_price
        this.update_time = int(time.time()-time.timezone)
    def getPriceAsInt(this):
        r = []
        r.append(int(this.buy_price * 100.))
        r.append(int(this.buy_price_diff * 100.))
        r.append(int(this.sell_price * 100.))
        r.append(int(this.sell_price_diff * 100.))
        return r
    def getUpdateTime(this):
        return this.update_time
        
class LengthError(Exception):
    pass

def recErrLog(log):
    with open('log.txt', 'a') as f:
        f.write('%s == ' % time.strftime("%Y-%m-%d %H:%M:%S"))
        f.write('%s\r\n' % log)

def getPrice(url, returnIndex):
    r = requests.get(url)
    assert(r.status_code == 200)
    rj = r.json()
    ad_list=rj['data']['ad_list']
    price_list=[]
    for x in ad_list:
        tp = float(x['data']['temp_price'])
        un = x['data']['profile']['username']
        url = x['actions']['public_view']
        price_list.append((tp, un, url))
    price_list.sort()
    return price_list[returnIndex][0:2], price_list[returnIndex][2]

def pollRecord(fname):
    global price
    a, u = getPrice('https://localbitcoins.com/buy-bitcoins-online/CNY/alipay/.json', 0)
    b, u = getPrice('https://localbitcoins.com/sell-bitcoins-online/CNY/alipay/.json', -1)
    price.update(a[0], b[0])
    with open(fname, 'a') as f:
        f.write('%s,' % time.strftime("%Y-%m-%d %H:%M:%S"))
        f.write('%.2f,%s,%.2f,%s,%s\r\n' % (a + b + (u, )))

def polling():
    while True:
        try:
            pollRecord('price.csv')
        except Exception as e:
            recErrLog(e)
            time.sleep(10)
        else:
            time.sleep(300)

def daemon():
    global p, aes
    s = socket.socket()
    s.bind(('0.0.0.0', 54742))
    s.listen(1)
    while True:
        (sock, addr) = s.accept()
        sock.settimeout(5)
        try:
            key2 = sock.recv(16)
            if len(key2) != 16:
                raise LengthError('Request length not 16')
        except (socket.timeout, LengthError, ConnectionResetError) as e:
            recErrLog('%s:%d, %s' % (addr + (e, )))
        except Exception as e:
            recErrLog(e)
        else:
            key2 = aes.decrypt(key2)
            aes_resp = AES.new(key2, AES.MODE_ECB)
            r = struct.pack('<I', price.getUpdateTime())
            p = price.getPriceAsInt()
            r = r + struct.pack('<I', p[0])[:3]
            r = r + struct.pack('<i', p[1])[:3]
            r = r + struct.pack('<I', p[2])[:3]
            r = r + struct.pack('<i', p[3])[:3]
            sock.sendall(aes_resp.encrypt(r))
        finally:
            sock.close()

with open('key.bin','rb') as f:
    key = f.read(16)
if len(key) != 16:
    raise LengthError('Key length not 16')

aes = AES.new(key, AES.MODE_ECB)
price = Price()

t1 = threading.Thread(target = polling, name = 'polling')
t1.setDaemon(True)
t1.start()
t2 = threading.Thread(target = daemon, name = 'TCP server')
t2.start()
t2.join()
