#!/usr/bin/env python3
"""
LSTM CNN Prediction Server for MT5 Expert Advisor
Provides HTTP API for financial time series prediction using LSTM CNN model
"""

import json
import logging
import numpy as np
import pandas as pd
from datetime import datetime
from typing import List, Dict, Tuple, Optional
import traceback

# Web framework
from flask import Flask, request, jsonify, Response
from flask_cors import CORS

# Machine Learning
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Conv1D, Dense, Dropout, MaxPooling1D, Flatten
from tensorflow.keras.optimizers import Adam
from sklearn.preprocessing import MinMaxScaler
from sklearn.metrics import mean_squared_error, mean_absolute_error

# Configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for MT5 requests

class LSTMCNNPredictor:
    """LSTM CNN model for financial time series prediction"""
    
    def __init__(self, sequence_length: int = 60, n_features: int = 12):
        self.sequence_length = sequence_length
        self.n_features = n_features
        self.model = None
        self.scaler = MinMaxScaler()
        self.is_trained = False
        self.training_history = []
        
    def build_model(self) -> None:
        """Build LSTM CNN hybrid model architecture"""
        logger.info("Building LSTM CNN model...")
        
        self.model = Sequential([
            # CNN layers for feature extraction
            Conv1D(filters=64, kernel_size=3, activation='relu', 
                   input_shape=(self.sequence_length, self.n_features)),
            Conv1D(filters=64, kernel_size=3, activation='relu'),
            MaxPooling1D(pool_size=2),
            Dropout(0.2),
            
            # More CNN layers
            Conv1D(filters=50, kernel_size=3, activation='relu'),
            Conv1D(filters=50, kernel_size=3, activation='relu'),
            MaxPooling1D(pool_size=2),
            Dropout(0.2),
            
            # LSTM layers for temporal dependencies
            LSTM(100, return_sequences=True),
            Dropout(0.3),
            LSTM(50, return_sequences=False),
            Dropout(0.3),
            
            # Dense layers for prediction
            Dense(25, activation='relu'),
            Dense(10, activation='relu'),
            Dense(5)  # Predict next 5 periods
        ])
        
        # Compile model
        self.model.compile(
            optimizer=Adam(learning_rate=0.001),
            loss='mse',
            metrics=['mae']
        )
        
        logger.info(f"Model built with {self.model.count_params()} parameters")
        
    def prepare_sequences(self, data: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """Prepare sequences for training/prediction"""
        if len(data) < self.sequence_length + 5:
            raise ValueError(f"Data too short. Need at least {self.sequence_length + 5} samples")
        
        # Reshape data for sequence creation
        features_per_bar = self.n_features
        n_bars = len(data) // features_per_bar
        
        # Reshape to (n_bars, n_features)
        data_reshaped = data.reshape(n_bars, features_per_bar)
        
        X, y = [], []
        
        # Create sequences
        for i in range(self.sequence_length, n_bars - 5):
            # Input sequence
            X.append(data_reshaped[i-self.sequence_length:i])
            
            # Target: next 5 close prices (assuming close is feature index 3)
            y.append(data_reshaped[i:i+5, 3])  # Next 5 close prices
        
        return np.array(X), np.array(y)
    
    def train_model(self, training_data: np.ndarray, epochs: int = 50, 
                   validation_split: float = 0.2) -> Dict:
        """Train the LSTM CNN model"""
        logger.info("Preparing training data...")
        
        # Prepare sequences
        X, y = self.prepare_sequences(training_data)
        logger.info(f"Created {len(X)} training sequences")
        
        if len(X) == 0:
            raise ValueError("No training sequences created")
        
        # Build model if not exists
        if self.model is None:
            self.build_model()
        
        # Train model
        logger.info("Starting model training...")
        history = self.model.fit(
            X, y,
            epochs=epochs,
            batch_size=32,
            validation_split=validation_split,
            verbose=1,
            shuffle=True
        )
        
        self.is_trained = True
        self.training_history = history.history
        
        # Calculate training metrics
        train_pred = self.model.predict(X)
        train_mse = mean_squared_error(y.flatten(), train_pred.flatten())
        train_mae = mean_absolute_error(y.flatten(), train_pred.flatten())
        
        logger.info(f"Training completed. MSE: {train_mse:.6f}, MAE: {train_mae:.6f}")
        
        return {
            'mse': float(train_mse),
            'mae': float(train_mae),
            'epochs': epochs,
            'samples': len(X)
        }
    
    def predict(self, input_data: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """Make predictions for hourly and daily timeframes"""
        if not self.is_trained:
            # Train with provided data if model not trained
            logger.warning("Model not trained. Training with provided data...")
            self.train_model(input_data)
        
        # Prepare input sequence
        features_per_bar = self.n_features
        n_bars = len(input_data) // features_per_bar
        
        if n_bars < self.sequence_length:
            raise ValueError(f"Input data too short. Need at least {self.sequence_length} bars")
        
        # Reshape to (n_bars, n_features)
        data_reshaped = input_data.reshape(n_bars, features_per_bar)
        
        # Take last sequence for prediction
        last_sequence = data_reshaped[-self.sequence_length:].reshape(1, self.sequence_length, self.n_features)
        
        # Make prediction
        hourly_pred = self.model.predict(last_sequence, verbose=0)[0]
        
        # For daily predictions, we'll use a simple scaling approach
        # In a real implementation, you might want separate models or different scaling
        current_price = data_reshaped[-1, 3]  # Last close price
        price_change_ratios = hourly_pred / current_price
        
        # Daily predictions: scale hourly changes and project further
        daily_pred = np.array([
            current_price * (1 + price_change_ratios[-1] * (i + 1) * 24)
            for i in range(5)
        ])
        
        # Ensure predictions are reasonable (within ±20% of current price)
        current_price = data_reshaped[-1, 3]
        hourly_pred = np.clip(hourly_pred, current_price * 0.8, current_price * 1.2)
        daily_pred = np.clip(daily_pred, current_price * 0.7, current_price * 1.3)
        
        return hourly_pred, daily_pred

# Global model instance
predictor = LSTMCNNPredictor()

@app.route('/health', methods=['GET'])
def health_check() -> Response:
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'model_trained': predictor.is_trained,
        'version': '1.0.0'
    })

@app.route('/predict', methods=['POST'])
def predict() -> Response:
    """Main prediction endpoint"""
    try:
        # Validate request
        if not request.is_json:
            return jsonify({'error': 'Request must be JSON'}), 400
        
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['data', 'symbol', 'timeframe']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        # Extract data
        market_data = np.array(data['data'], dtype=np.float32)
        symbol = data['symbol']
        timeframe = data['timeframe']
        
        logger.info(f"Prediction request for {symbol} {timeframe}, data shape: {market_data.shape}")
        
        # Validate data
        if len(market_data) == 0:
            return jsonify({'error': 'Empty data array'}), 400
        
        if len(market_data) < predictor.sequence_length * predictor.n_features:
            return jsonify({
                'error': f'Insufficient data. Need at least {predictor.sequence_length * predictor.n_features} values'
            }), 400
        
        # Make predictions
        hourly_predictions, daily_predictions = predictor.predict(market_data)
        
        # Prepare response
        response = {
            'success': True,
            'timestamp': datetime.now().isoformat(),
            'symbol': symbol,
            'timeframe': timeframe,
            'current_price': float(data.get('current_price', 0)),
            'hourly_predictions': hourly_predictions.tolist(),
            'daily_predictions': daily_predictions.tolist(),
            'model_info': {
                'trained': predictor.is_trained,
                'sequence_length': predictor.sequence_length,
                'features': predictor.n_features
            }
        }
        
        logger.info(f"Predictions generated successfully for {symbol}")
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Prediction error: {str(e)}")
        logger.error(traceback.format_exc())
        
        return jsonify({
            'success': False,
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500

@app.route('/train', methods=['POST'])
def train_model() -> Response:
    """Endpoint to train the model with new data"""
    try:
        if not request.is_json:
            return jsonify({'error': 'Request must be JSON'}), 400
        
        data = request.get_json()
        
        if 'data' not in data:
            return jsonify({'error': 'Missing training data'}), 400
        
        training_data = np.array(data['data'], dtype=np.float32)
        epochs = data.get('epochs', 50)
        
        logger.info(f"Training request with {len(training_data)} data points for {epochs} epochs")
        
        # Train model
        metrics = predictor.train_model(training_data, epochs=epochs)
        
        response = {
            'success': True,
            'timestamp': datetime.now().isoformat(),
            'training_metrics': metrics,
            'message': 'Model trained successfully'
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Training error: {str(e)}")
        logger.error(traceback.format_exc())
        
        return jsonify({
            'success': False,
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500

@app.route('/model/info', methods=['GET'])
def model_info() -> Response:
    """Get model information"""
    return jsonify({
        'model_trained': predictor.is_trained,
        'sequence_length': predictor.sequence_length,
        'n_features': predictor.n_features,
        'training_history': predictor.training_history[-10:] if predictor.training_history else [],
        'timestamp': datetime.now().isoformat()
    })

@app.route('/generate_sample_data', methods=['GET'])
def generate_sample_data() -> Response:
    """Generate sample data for testing"""
    try:
        # Generate synthetic market data
        n_bars = 200
        n_features = 12
        
        # Create realistic price movement
        np.random.seed(42)
        base_price = 1.1000
        
        sample_data = []
        current_price = base_price
        
        for i in range(n_bars):
            # Random walk with slight trend
            change = np.random.normal(0, 0.001)
            current_price += change
            
            # OHLC
            open_price = current_price
            high_price = current_price + abs(np.random.normal(0, 0.0005))
            low_price = current_price - abs(np.random.normal(0, 0.0005))
            close_price = open_price + np.random.normal(0, 0.0003)
            
            # Volume
            volume = np.random.uniform(1000, 10000)
            
            # Technical indicators (simplified)
            rsi = np.random.uniform(20, 80) / 100.0
            macd = np.random.normal(0, 0.0001)
            ma = close_price
            bb_upper = close_price + 0.002
            bb_lower = close_price - 0.002
            atr = np.random.uniform(0.0005, 0.002)
            stoch = np.random.uniform(0, 100) / 100.0
            
            # Normalize prices
            norm_open = (open_price - base_price) / base_price
            norm_high = (high_price - base_price) / base_price
            norm_low = (low_price - base_price) / base_price
            norm_close = (close_price - base_price) / base_price
            norm_volume = volume / 10000.0
            norm_ma = (ma - base_price) / base_price
            norm_bb_upper = (bb_upper - base_price) / base_price
            norm_bb_lower = (bb_lower - base_price) / base_price
            
            bar_data = [
                norm_open, norm_high, norm_low, norm_close, norm_volume,
                rsi, macd, norm_ma, norm_bb_upper, norm_bb_lower, atr, stoch
            ]
            
            sample_data.extend(bar_data)
            current_price = close_price
        
        response = {
            'success': True,
            'data': sample_data,
            'bars_count': n_bars,
            'features_per_bar': n_features,
            'symbol': 'EURUSD',
            'timeframe': 'H1',
            'current_price': current_price,
            'timestamp': datetime.now().isoformat()
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Sample data generation error: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    logger.info("Starting LSTM CNN Prediction Server...")
    logger.info("Available endpoints:")
    logger.info("  GET  /health - Health check")
    logger.info("  POST /predict - Make predictions")
    logger.info("  POST /train - Train model")
    logger.info("  GET  /model/info - Model information")
    logger.info("  GET  /generate_sample_data - Generate test data")
    
    # Run server
    app.run(
        host='0.0.0.0',
        port=8000,
        debug=False,
        threaded=True
    )