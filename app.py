#!/usr/bin/env python3
from flask import Flask, jsonify
import os
import logging
from systemd.journal import JournalHandler

app = Flask(__name__)

# Настройка логирования
log = logging.getLogger('myapp')
log.addHandler(JournalHandler())
log.setLevel(logging.INFO)

@app.route('/')
def hello():
    log.info("Root endpoint accessed")
    return jsonify({
        "status": "success", 
        "message": "App Worked!",
        "service": "myapp"
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

@app.route('/info')
def info():
    return jsonify({
        "python_version": os.sys.version,
        "environment": os.getenv('APP_ENV', 'development')
    })

if __name__ == '__main__':
    log.info("Starting Flask application")
    app.run(host='0.0.0.0', port=8181, debug=False)
