#!/usr/bin/env python3
"""
CORRECTED LSTM CNN Model Training Script
Fixes scaling issues and ensures proper data preparation
"""

import os
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime, timedelta
import logging
from sklearn.preprocessing import MinMaxScaler, StandardScaler
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
import joblib
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, models, optimizers, callbacks

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class CorrectedForexDataGenerator:
    """Generate realistic forex data with proper scaling"""
    
    def __init__(self, symbol="EURUSD", start_price=1.1650):
        self.symbol = symbol
        self.start_price = start_price
        
    def generate_realistic_data(self, n_bars=10000) -> pd.DataFrame:
        """Generate realistic forex price movements with PROPER scaling"""
        logger.info(f"Generating {n_bars} bars of PROPERLY SCALED data for {self.symbol}")
        
        np.random.seed(42)
        
        data = []
        current_price = self.start_price  # Start with realistic EURUSD price
        
        for i in range(n_bars):
            # Realistic forex price movements (much smaller than before)
            trend = np.random.normal(0, 0.00005)  # Very small trend
            volatility = np.random.uniform(0.0002, 0.0008)  # Realistic forex volatility
            
            # Price change
            change = np.random.normal(trend, volatility)
            current_price += change
            
            # Keep price in realistic range for EURUSD
            current_price = max(0.9500, min(1.3000, current_price))
            
            # Generate OHLC
            spread = np.random.uniform(0.00008, 0.00015)  # Realistic spread
            open_price = current_price + np.random.normal(0, volatility/4)
            
            high_offset = abs(np.random.normal(0, volatility/3))
            low_offset = abs(np.random.normal(0, volatility/3))
            
            high_price = current_price + high_offset
            low_price = current_price - low_offset
            close_price = current_price + np.random.normal(0, volatility/4)
            
            # Ensure OHLC consistency
            high_price = max(high_price, open_price, close_price)
            low_price = min(low_price, open_price, close_price)
            
            # Keep all prices in realistic range
            open_price = max(0.9500, min(1.3000, open_price))
            high_price = max(0.9500, min(1.3000, high_price))
            low_price = max(0.9500, min(1.3000, low_price))
            close_price = max(0.9500, min(1.3000, close_price))
            
            # Volume (realistic range)
            volume = np.random.uniform(500, 5000)
            
            # Technical indicators with realistic ranges
            rsi = np.random.uniform(20, 80)
            macd = np.random.normal(0, 0.00005)  # Much smaller MACD values
            ma_20 = close_price + np.random.normal(0, 0.0001)  # MA close to price
            bb_upper = close_price + (volatility * 2)
            bb_lower = close_price - (volatility * 2)
            atr = volatility * 10000  # Convert to points
            stochastic = np.random.uniform(10, 90)
            
            # Create timestamp
            timestamp = datetime.now() - timedelta(hours=n_bars-i)
            
            data.append({
                'timestamp': timestamp,
                'open': open_price,
                'high': high_price,
                'low': low_price,
                'close': close_price,
                'volume': volume,
                'rsi': rsi,
                'macd': macd,
                'ma_20': ma_20,
                'bb_upper': bb_upper,
                'bb_lower': bb_lower,
                'atr': atr,
                'stochastic': stochastic
            })
            
            current_price = close_price
        
        df = pd.DataFrame(data)
        df.set_index('timestamp', inplace=True)
        
        # Validation checks
        logger.info(f"Generated data validation:")
        logger.info(f"  Close price range: [{df['close'].min():.5f}, {df['close'].max():.5f}]")
        logger.info(f"  Close price mean: {df['close'].mean():.5f}")
        logger.info(f"  RSI range: [{df['rsi'].min():.1f}, {df['rsi'].max():.1f}]")
        logger.info(f"  MACD range: [{df['macd'].min():.6f}, {df['macd'].max():.6f}]")
        logger.info(f"  Volume range: [{df['volume'].min():.0f}, {df['volume'].max():.0f}]")
        
        return df

class CorrectedLSTMCNNTrainer:
    """LSTM CNN Model Trainer with CORRECTED scaling"""
    
    def __init__(self, sequence_length=60, n_features=12, prediction_steps=5):
        self.sequence_length = sequence_length
        self.n_features = n_features
        self.prediction_steps = prediction_steps
        self.model = None
        
        # Use MinMaxScaler for both features and prices - THIS IS CRITICAL
        self.price_scaler = MinMaxScaler(feature_range=(0, 1))
        self.feature_scaler = MinMaxScaler(feature_range=(0, 1))
        
        self.is_trained = False
        
    def prepare_features(self, df: pd.DataFrame) -> np.ndarray:
        """Prepare feature matrix - EXACT same order as MQL5 EA"""
        logger.info("Preparing features with CORRECTED scaling...")
        
        # EXACT same order as MQL5 EA
        feature_columns = [
            'open', 'high', 'low', 'close', 'volume',
            'rsi', 'macd', 'ma_20', 'bb_upper', 'bb_lower', 'atr', 'stochastic'
        ]
        
        # Validate all columns exist
        for col in feature_columns:
            if col not in df.columns:
                raise ValueError(f"Missing feature column: {col}")
        
        features = df[feature_columns].values
        
        # Log feature ranges before scaling
        logger.info("Feature ranges BEFORE scaling:")
        for i, col in enumerate(feature_columns):
            logger.info(f"  {col}: [{features[:, i].min():.6f}, {features[:, i].max():.6f}]")
        
        # Handle NaN values
        features = np.nan_to_num(features, nan=0.0, posinf=0.0, neginf=0.0)
        
        return features
    
    def create_sequences(self, features: np.ndarray, target_prices: np.ndarray) -> tuple:
        """Create sequences for LSTM training"""
        logger.info("Creating sequences...")
        
        X, y = [], []
        
        for i in range(self.sequence_length, len(features) - self.prediction_steps):
            # Input sequence
            X.append(features[i-self.sequence_length:i])
            
            # Target: next prediction_steps close prices
            y.append(target_prices[i:i+self.prediction_steps])
        
        X = np.array(X)
        y = np.array(y)
        
        logger.info(f"Sequence shapes - X: {X.shape}, y: {y.shape}")
        return X, y
    
    def build_model(self) -> None:
        """Build LSTM CNN model"""
        logger.info("Building CORRECTED LSTM CNN model...")
        
        self.model = keras.Sequential([
            # CNN layers
            layers.Conv1D(filters=64, kernel_size=3, activation='relu', 
                   input_shape=(self.sequence_length, self.n_features)),
            layers.BatchNormalization(),
            layers.Conv1D(filters=64, kernel_size=3, activation='relu'),
            layers.MaxPooling1D(pool_size=2),
            layers.Dropout(0.2),
            
            layers.Conv1D(filters=50, kernel_size=3, activation='relu'),
            layers.BatchNormalization(),
            layers.Conv1D(filters=50, kernel_size=3, activation='relu'),
            layers.MaxPooling1D(pool_size=2),
            layers.Dropout(0.2),
            
            # LSTM layers
            layers.LSTM(100, return_sequences=True),
            layers.Dropout(0.3),
            layers.LSTM(50, return_sequences=False),
            layers.Dropout(0.3),
            
            # Dense layers
            layers.Dense(25, activation='relu'),
            layers.BatchNormalization(),
            layers.Dense(10, activation='relu'),
            layers.Dense(self.prediction_steps)  # Output layer
        ])
        
        self.model.compile(
            optimizer=optimizers.Adam(learning_rate=0.001),
            loss='mse',
            metrics=['mae']
        )
        
        logger.info(f"Model built with {self.model.count_params()} parameters")
        self.model.summary()
    
    def train(self, df: pd.DataFrame, validation_split=0.2, epochs=50, batch_size=32):
        """Train the model with CORRECTED scaling"""
        logger.info("Starting CORRECTED model training...")
        
        # Prepare features
        features = self.prepare_features(df)
        target_prices = df['close'].values.reshape(-1, 1)  # Reshape for scaler
        
        logger.info("SCALING DATA CORRECTLY...")
        
        # Fit and transform features
        features_scaled = self.feature_scaler.fit_transform(features)
        
        # Fit and transform target prices 
        target_scaled = self.price_scaler.fit_transform(target_prices).flatten()
        
        # Log scaling results
        logger.info("Scaling results:")
        logger.info(f"  Original price range: [{target_prices.min():.5f}, {target_prices.max():.5f}]")
        logger.info(f"  Scaled price range: [{target_scaled.min():.5f}, {target_scaled.max():.5f}]")
        logger.info(f"  Features scaled range: [{features_scaled.min():.5f}, {features_scaled.max():.5f}]")
        
        # Test round-trip scaling
        test_price = np.array([[1.1650]])  # Typical EURUSD price
        test_scaled = self.price_scaler.transform(test_price)
        test_unscaled = self.price_scaler.inverse_transform(test_scaled)
        logger.info(f"  Round-trip test: {test_price[0][0]:.5f} -> {test_scaled[0][0]:.5f} -> {test_unscaled[0][0]:.5f}")
        
        # Create sequences
        X, y = self.create_sequences(features_scaled, target_scaled)
        
        if len(X) == 0:
            raise ValueError("No sequences created")
        
        # Build model
        if self.model is None:
            self.build_model()
        
        # Callbacks
        callbacks_list = [
            callbacks.EarlyStopping(patience=10, restore_best_weights=True),
            callbacks.ReduceLROnPlateau(factor=0.5, patience=5),
            callbacks.ModelCheckpoint('best_model.h5', save_best_only=True)
        ]
        
        # Train
        history = self.model.fit(
            X, y,
            epochs=epochs,
            batch_size=batch_size,
            validation_split=validation_split,
            callbacks=callbacks_list,
            verbose=1
        )
        
        self.is_trained = True
        
        # Test prediction to verify scaling
        self._test_prediction_scaling(X, target_prices)
        
        return history
    
    def _test_prediction_scaling(self, X, original_prices):
        """Test that predictions are in the right scale"""
        logger.info("Testing prediction scaling...")
        
        # Make a test prediction
        test_pred_scaled = self.model.predict(X[:1], verbose=0)
        test_pred_unscaled = self.price_scaler.inverse_transform(test_pred_scaled)[0]
        
        current_price = original_prices[-1][0]
        
        logger.info(f"Scaling test results:")
        logger.info(f"  Current price: {current_price:.5f}")
        logger.info(f"  Predicted prices: {test_pred_unscaled}")
        
        for i, pred in enumerate(test_pred_unscaled):
            change_pct = ((pred - current_price) / current_price) * 100
            logger.info(f"    Hour {i+1}: {pred:.5f} (change: {change_pct:+.2f}%)")
            
            if abs(change_pct) > 50:  # Flag unrealistic predictions
                logger.warning(f"    ⚠️  Potentially unrealistic prediction!")
    
    def save_model(self, filepath='lstm_cnn_model.h5'):
        """Save the CORRECTED model and scalers"""
        if not self.is_trained:
            raise ValueError("Model not trained yet")
        
        self.model.save(filepath)
        
        # Save scalers
        joblib.dump(self.price_scaler, 'price_scaler.pkl')
        joblib.dump(self.feature_scaler, 'feature_scaler.pkl')
        
        # Save configuration
        config = {
            'sequence_length': self.sequence_length,
            'n_features': self.n_features,
            'prediction_steps': self.prediction_steps,
            'price_scaler_info': {
                'min_': self.price_scaler.min_.tolist(),
                'scale_': self.price_scaler.scale_.tolist(),
                'data_min_': self.price_scaler.data_min_.tolist(),
                'data_max_': self.price_scaler.data_max_.tolist(),
                'feature_range': self.price_scaler.feature_range
            },
            'feature_scaler_info': {
                'min_': self.feature_scaler.min_.tolist(),
                'scale_': self.feature_scaler.scale_.tolist(),
                'n_features_in_': int(self.feature_scaler.n_features_in_),
                'feature_range': self.feature_scaler.feature_range
            }
        }
        
        with open('model_config.json', 'w') as f:
            json.dump(config, f, indent=2)
        
        logger.info(f"CORRECTED model saved to {filepath}")
        logger.info("Scaler information saved to model_config.json")

def main():
    logger.info("Starting CORRECTED LSTM CNN training...")
    
    # Generate corrected data
    generator = CorrectedForexDataGenerator("EURUSD", start_price=1.1650)
    df = generator.generate_realistic_data(10000)
    
    logger.info(f"Data loaded: {df.shape}")
    logger.info(f"Price range: [{df['close'].min():.5f}, {df['close'].max():.5f}]")
    
    # Initialize trainer
    trainer = CorrectedLSTMCNNTrainer(
        sequence_length=60,
        n_features=12,
        prediction_steps=5
    )
    
    # Train model
    try:
        history = trainer.train(df, epochs=50, batch_size=32)
        
        # Save model
        trainer.save_model()
        
        logger.info("CORRECTED training completed successfully!")
        
    except Exception as e:
        logger.error(f"Training failed: {str(e)}")
        raise

if __name__ == '__main__':
    main()