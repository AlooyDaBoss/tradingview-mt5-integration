from flask import Flask, request
import os
from datetime import datetime, timedelta
from enum import Enum, auto

app = Flask(__name__)
class Direction(Enum):
    buy = "buy",
    sell = "sell",
    unknown = "UNKOWN",

# ✅ Path to your MQL5 Files folder (LOCAL terminal, not Common)
mt5_files_path = r"C:\Users\alaaa\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files"

os.makedirs(mt5_files_path, exist_ok=True)

xau_usd_15_min_direction = Direction.unknown
nasdaq_15_min_direction = Direction.unknown

@app.route('/<symbol>', methods=['POST'])
def webhook(symbol):
    try:
        symbol = symbol.lower()
        data = request.data.decode().strip().lower()

        if (not(
            (symbol == "xauusd" and data == xau_usd_15_min_direction._name_) or
            (symbol == "us100" and data == nasdaq_15_min_direction._name_)
        )):
            return f"15M signal doesnt match the 2M signal for symbol: {symbol}, 15M direction: {xau_usd_15_min_direction._name_}, 2M direction: {data}"
        else:
            gmt_plus_3 = datetime.utcnow() + timedelta(hours=3)
            timestamp = int(gmt_plus_3.timestamp())
            print("✅ Received signal:", data)

            file_name = f"{symbol}-signal.txt"
            file_path = os.path.join(mt5_files_path, file_name)
            print("💾 Writing to:", file_path)

            with open(file_path, "w") as f:
                f.write(f"{data}|{timestamp}")

            return f"✅ Signal written successfully to {symbol}", 200
    except Exception as e:
        print("❌ Error in webhook:", e)
        return f"Error in webhook: {e}", 500


@app.route('/changeDirection/<symbol>', methods=['POST'])
def changeDirection(symbol):
    global xau_usd_15_min_direction, nasdaq_15_min_direction
    try:
        symbol = symbol.lower()
        data = request.data.decode().strip().lower()
        print("✅ Received change direction signal:", data)

        # Update direction based on symbol and data
        if symbol == "xauusd":
            if data == "buy":
                xau_usd_15_min_direction = Direction.buy
            elif data == "sell":
                xau_usd_15_min_direction = Direction.sell
        elif symbol == "us100":
            if data == "buy":
                nasdaq_15_min_direction = Direction.buy
            elif data == "sell":
                nasdaq_15_min_direction = Direction.sell

        return "New direction: " + showDirections()
    except Exception as e:
        print("❌ Error in changeDirection:", e)
        return f"Error in changeDirection: {e}", 500


@app.route('/getDirections', methods=['GET'])
def getDirections():
    return showDirections()


def showDirections():
    return f"15M XAUUSD: {xau_usd_15_min_direction._name_}, 15M US100: {nasdaq_15_min_direction._name_}"

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)