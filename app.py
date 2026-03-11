from flask import Flask
import os

app = Flask(__name__)

@app.route("/")
def home():
    return "Hello from Flask! App is serving 🚀"

if __name__ == "__main__":
    # Get the port from environment variable, default to 5000
    port = int(os.environ.get("PORT", 5000))
    # Listen on all interfaces so it is accessible from Docker container port mapping
    app.run(host="0.0.0.0", port=port)
