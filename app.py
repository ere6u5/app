#!/usr/bin/env python3
from flask import Flask, jsonify
import os
from datetime import datetime

app = Flask(__name__)

@app.route('/')
def hello():
    print(f"{datetime.now()} - Root endpoint accessed")  # Простой вывод в консоль
    return jsonify({
        "status": "success", 
        "message": "App Worked!1",
        "timestamp": datetime.now().isoformat()
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

@app.route('/info')
def info():
    return jsonify({
        "python_version": "3.x",
        "environment": "production"
    })

if __name__ == '__main__':
    print("Starting Flask application on port 8181")
    app.run(host='0.0.0.0', port=8181, debug=False)
