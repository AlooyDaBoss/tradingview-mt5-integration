import os
import json

mt5_files_path = r"C:\Users\alaaa\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files"
file_path = os.path.join(mt5_files_path, "signal.json")

signal = {
    "action": "buy",
    "symbol": "EURUSD",
    "price": 1.0999
}

with open(file_path, "w") as f:
    json.dump(signal, f)

print("File written:", file_path)
