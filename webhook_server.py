from flask import Flask, request
import os
from datetime import datetime, timedelta

app = Flask(__name__)

# ✅ Path to your MQL5 Files folder (LOCAL terminal, not Common)
mt5_files_path = r"C:\Users\alaaa\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files"

os.makedirs(mt5_files_path, exist_ok=True)


@app.route('/<symbol>', methods=['POST'])
def webhook(symbol):
    try:
        data = request.data.decode().strip()
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
        print("❌ Error:", e)
        return f"Error: {e}", 500

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
