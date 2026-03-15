from flask import Flask
import os

app = Flask(__name__)

@app.route("/")
def home():
    return "Hello from Flask! Python code ! From Github Action"

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    # MUST be 0.0.0.0 to be accessible outside the container
    app.run(host="0.0.0.0", port=port)
