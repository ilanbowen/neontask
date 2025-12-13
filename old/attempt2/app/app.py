from flask import Flask, jsonify, request
import os
import socket

app = Flask(__name__)

@app.route('/')
def index():
    return jsonify({
        'message': 'Hello from Flask on Kubernetes!',
        'version': '1.0.0',
        'hostname': socket.gethostname(),
        'environment': os.environ.get('ENVIRONMENT', 'development')
    })

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'service': 'hello-world-app'
    }), 200

@app.route('/ready')
def ready():
    # Add any readiness checks here
    return jsonify({
        'status': 'ready',
        'service': 'hello-world-app'
    }), 200

@app.route('/info')
def info():
    import sys
    return jsonify({
        'hostname': socket.gethostname(),
        'environment': os.environ.get('ENVIRONMENT', 'development'),
        'python_version': sys.version,
        'app_version': '1.0.0'
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
