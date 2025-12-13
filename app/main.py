from flask import Flask
import socket

app = Flask(__name__)

@app.route("/")
def hello():
    hostname = socket.gethostname()
    return f"Hello, world from {hostname}!\n"

if __name__ == "__main__":
    # Bind to 0.0.0.0 so it’s reachable inside the container
    app.run(host="0.0.0.0", port=5000)
