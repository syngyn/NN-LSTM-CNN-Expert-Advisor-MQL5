#!/usr/bin/env python3
"""
AI Trading Strategy Backtesting Script
Tests the H1 AI scalping strategy using historical data without server connection
"""

import argparse
import json
import warnings
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime, timedelta
import joblib
import logging

import tensorflow as tf
from tensorflow.keras.models import load_model
from features import compute_features, ensure_column_order

warnings.filterwarnings('ignore')
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Custom attention layer for model loading
class TemporalAttention(tf.keras.layers.Layer):
    def __init__(self, attn_units: int = 64, use_context: bool = True, **kwargs):
        super().__init__(**kwargs)
        self.attn_units = attn_units
        self.use_context = use_context
        self.W = tf.keras.layers.Dense(attn_units, activation='tanh')
        self.V = tf.keras.layers.Dense(1)
        if use_context:
            self.context_layer = tf.keras.layers.Dense(attn_units, activation='relu')

    def call(self, inputs):
        score = self.V(self.W(inputs))
        weights = tf.nn.softmax(score, axis=1)
        if self.use_context:
            context = tf.reduce_sum(weights * inputs, axis=1)
            context = self.context_layer(context)
            return context
        else:
            return tf.reduce_sum(weights * inputs, axis=1)

    def get_config(self):
        config = super().get_config()
        config.update({
            "attn_units": self.attn_units,
            "use_context": self.use_context
        })
        return config

class AITradingBacktester:
    def __init__(self, model_dir: str, strategy_config: dict):
        self.model_dir = Path(model_dir)
        self.strategy_config = strategy_config
        
        # Model components
        self.model = None
        self.feature_scaler = None
        self.price_scaler = None
        self.model_config = None
        self.is_return_based = False
        
        # Trading state
        self.positions = []
        self.closed_positions = []
        self.balance = strategy_config.get('initial_balance', 10000.0)
        self.equity = self.balance
        
        # Performance tracking
        self.equity_curve = []
        self.trade_log = []
        
        # Load model
        self.load_model_artifacts()
    
    def load_model_artifacts(self):
        """Load trained model and scalers"""
        try:
            # Load model with custom objects
            custom_objects = {'TemporalAttention': TemporalAttention}
            self.model = load_model(self.model_dir / 'best_attention_model.h5', custom_objects=custom_objects)
            
            # Load scalers
            self.feature_scaler = joblib.load(self.model_dir / 'feature_scaler.pkl')
            
            # Try to load price scaler (may not exist for return-based models)
            price_scaler_path = self.model_dir / 'price_scaler.pkl'
            if price_scaler_path.exists():
                self.price_scaler = joblib.load(price_scaler_path)
            
            # Load configuration
            with open(self.model_dir / 'model_config.json', 'r') as f:
                self.model_config = json.load(f)
            
            self.is_return_based = self.model_config.get('model_type') == 'return_prediction'
            
            logger.info(f"Model loaded: {'Return-based' if self.is_return_based else 'Price-based'}")
            logger.info(f"Sequence length: {self.model_config['sequence_length']}")
            logger.info(f"Prediction steps: {self.model_config['prediction_steps']}")
            
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            raise
    
    def prepare_features_for_prediction(self, df_features: pd.DataFrame, current_idx: int) -> np.ndarray:
        """Prepare features for model prediction"""
        sequence_length = self.model_config['sequence_length']
        
        if current_idx < sequence_length:
            return None
        
        # Get feature columns based on model type
        if self.is_return_based:
            feature_columns = self.model_config.get('feature_columns', 
                ['rsi', 'macd', 'atr', 'stochastic', 'volume', 'price_norm', 'high_norm', 'low_norm', 'open_norm'])
        else:
            feature_columns = self.model_config.get('feature_columns',
                ['open', 'high', 'low', 'close', 'volume', 'rsi', 'macd', 'ma_20', 'bb_upper', 'bb_lower', 'atr', 'stochastic'])
        
        # Extract sequence
        start_idx = current_idx - sequence_length
        sequence_data = df_features.iloc[start_idx:current_idx]
        
        # Handle missing columns gracefully
        available_features = []
        for col in feature_columns:
            if col in sequence_data.columns:
                available_features.append(col)
            elif col in ['price_norm', 'high_norm', 'low_norm', 'open_norm'] and self.is_return_based:
                # Calculate normalized features on the fly for return-based models
                if col == 'price_norm':
                    close_vals = sequence_data['close'].values
                    mean_close = np.mean(close_vals)
                    std_close = np.std(close_vals) if len(close_vals) > 1 else 1.0
                    norm_vals = (close_vals - mean_close) / max(std_close, 1e-8)
                    sequence_data = sequence_data.copy()
                    sequence_data[col] = norm_vals
                    available_features.append(col)
                elif col in ['high_norm', 'low_norm', 'open_norm']:
                    price_type = col.split('_')[0]
                    close_vals = sequence_data['close'].values
                    price_vals = sequence_data[price_type].values
                    norm_vals = (price_vals - close_vals) / close_vals * 100
                    sequence_data = sequence_data.copy()
                    sequence_data[col] = norm_vals
                    available_features.append(col)
        
        if not available_features:
            logger.warning("No features available for prediction")
            return None
        
        # Extract feature array
        feature_array = sequence_data[available_features].values
        
        # Scale features
        feature_array_scaled = self.feature_scaler.transform(feature_array)
        
        # Reshape for model input
        model_input = feature_array_scaled.reshape(1, sequence_length, len(available_features))
        
        return model_input
    
    def make_prediction(self, model_input: np.ndarray, current_price: float) -> list:
        """Make price predictions using the model"""
        if model_input is None:
            return [current_price] * self.model_config['prediction_steps']
        
        # Get model prediction
        prediction = self.model.predict(model_input, verbose=0)
        
        if self.is_return_based:
            # Convert returns to prices
            returns = prediction[0]  # First (and only) sample
            prices = []
            for return_pct in returns:
                # Clip to realistic range
                return_pct = np.clip(return_pct, -2.0, 2.0)
                future_price = current_price * (1 + return_pct / 100)
                prices.append(float(future_price))
            return prices
        else:
            # Price-based model
            if self.price_scaler is not None:
                prices = self.price_scaler.inverse_transform(prediction)[0]
                return prices.tolist()
            else:
                return prediction[0].tolist()
    
    def should_open_position(self, current_price: float, h1_prediction: float, spread: float) -> dict:
        """Determine if we should open a position based on strategy rules"""
        signal = {'action': 'hold', 'reason': '', 'order_type': None, 'lot_size': 0}
        
        # Check if we already have max positions
        if len(self.positions) >= self.strategy_config['max_positions']:
            signal['reason'] = 'Max positions reached'
            return signal
        
        # Calculate predicted change
        pred_change_pct = ((h1_prediction - current_price) / current_price) * 100
        
        # Check prediction change limits
        min_change = self.strategy_config['min_prediction_change']
        max_change = self.strategy_config['max_prediction_change']
        
        if abs(pred_change_pct) < min_change:
            signal['reason'] = f'Change too small: {pred_change_pct:.3f}%'
            return signal
        
        if abs(pred_change_pct) > max_change:
            signal['reason'] = f'Change too large: {pred_change_pct:.3f}%'
            return signal
        
        # Check spread
        if spread > self.strategy_config['max_spread']:
            signal['reason'] = f'Spread too wide: {spread}'
            return signal
        
        # Determine order type
        if pred_change_pct > 0:
            signal['order_type'] = 'buy'
        else:
            signal['order_type'] = 'sell'
        
        # Calculate position size
        signal['lot_size'] = self.calculate_position_size(current_price, h1_prediction)
        signal['action'] = 'open'
        signal['reason'] = f'Signal: {pred_change_pct:+.3f}% prediction'
        
        return signal
    
    def calculate_position_size(self, entry_price: float, target_price: float) -> float:
        """Calculate position size based on risk management"""
        risk_amount = self.balance * (self.strategy_config['risk_percent'] / 100)
        
        # Calculate stop loss distance
        sl_distance = abs(target_price - entry_price) * 0.5  # 50% of prediction distance
        
        if sl_distance == 0:
            return self.strategy_config['min_lot_size']
        
        # Simple position sizing (would need proper forex calculations in real implementation)
        pip_value = 1.0  # Simplified - normally would calculate based on pair and account currency
        lot_size = risk_amount / (sl_distance * 10000 * pip_value)  # Convert to pips
        
        # Apply limits
        lot_size = max(self.strategy_config['min_lot_size'], 
                      min(self.strategy_config['max_lot_size'], lot_size))
        
        return round(lot_size, 2)
    
    def open_position(self, timestamp: pd.Timestamp, signal: dict, current_price: float, h1_prediction: float):
        """Open a new position"""
        # Calculate entry price (simplified - assume immediate fill)
        spread = self.strategy_config.get('typical_spread', 0.00015)
        if signal['order_type'] == 'buy':
            entry_price = current_price + spread/2
        else:
            entry_price = current_price - spread/2
        
        # Calculate stop loss and take profit
        sl_distance = abs(h1_prediction - current_price) * 0.5
        tp_distance = abs(h1_prediction - current_price) * self.strategy_config['tp_multiplier']
        
        if signal['order_type'] == 'buy':
            stop_loss = entry_price - sl_distance
            take_profit = entry_price + tp_distance
        else:
            stop_loss = entry_price + sl_distance  
            take_profit = entry_price - tp_distance
        
        position = {
            'id': len(self.positions) + len(self.closed_positions),
            'timestamp': timestamp,
            'type': signal['order_type'],
            'entry_price': entry_price,
            'lot_size': signal['lot_size'],
            'stop_loss': stop_loss,
            'take_profit': take_profit,
            'h1_target': h1_prediction,
            'bars_open': 0,
            'current_profit': 0,
            'reason': signal['reason']
        }
        
        self.positions.append(position)
        logger.info(f"Opened {signal['order_type'].upper()} position: {entry_price:.5f} (SL: {stop_loss:.5f}, TP: {take_profit:.5f})")
    
    def update_positions(self, timestamp: pd.Timestamp, current_price: float):
        """Update existing positions and check for closes"""
        positions_to_close = []
        
        for i, pos in enumerate(self.positions):
            pos['bars_open'] += 1
            
            # Calculate current profit
            if pos['type'] == 'buy':
                pos['current_profit'] = (current_price - pos['entry_price']) * pos['lot_size'] * 100000
            else:
                pos['current_profit'] = (pos['entry_price'] - current_price) * pos['lot_size'] * 100000
            
            # Check for stop loss / take profit
            should_close = False
            close_reason = ''
            
            if pos['type'] == 'buy':
                if current_price <= pos['stop_loss']:
                    should_close = True
                    close_reason = 'Stop Loss'
                elif current_price >= pos['take_profit']:
                    should_close = True
                    close_reason = 'Take Profit'
            else:
                if current_price >= pos['stop_loss']:
                    should_close = True
                    close_reason = 'Stop Loss'
                elif current_price <= pos['take_profit']:
                    should_close = True
                    close_reason = 'Take Profit'
            
            # Check for force close after N bars
            force_close_bars = self.strategy_config.get('force_close_after_bars', 0)
            if force_close_bars > 0 and pos['bars_open'] >= force_close_bars:
                should_close = True
                close_reason = f'Force close after {force_close_bars} bars'
            
            if should_close:
                positions_to_close.append((i, pos, close_reason, current_price))
        
        # Close positions (reverse order to maintain indices)
        for i, pos, reason, close_price in reversed(positions_to_close):
            self.close_position(timestamp, pos, reason, close_price)
            del self.positions[i]
    
    def close_position(self, timestamp: pd.Timestamp, position: dict, reason: str, close_price: float):
        """Close a position and record the trade"""
        # Calculate final profit
        if position['type'] == 'buy':
            profit = (close_price - position['entry_price']) * position['lot_size'] * 100000
        else:
            profit = (position['entry_price'] - close_price) * position['lot_size'] * 100000
        
        # Update balance
        self.balance += profit
        
        # Record trade
        trade = {
            'id': position['id'],
            'open_time': position['timestamp'],
            'close_time': timestamp,
            'type': position['type'],
            'entry_price': position['entry_price'],
            'close_price': close_price,
            'lot_size': position['lot_size'],
            'bars_held': position['bars_open'],
            'profit': profit,
            'close_reason': reason,
            'h1_target': position['h1_target'],
            'target_hit': abs(close_price - position['h1_target']) < abs(position['entry_price'] - position['h1_target']) * 0.2
        }
        
        self.closed_positions.append(trade)
        logger.info(f"Closed {position['type'].upper()} position: {profit:+.2f} USD ({reason})")
    
    def run_backtest(self, data_path: str, start_date: str = None, end_date: str = None):
        """Run the complete backtest"""
        logger.info("=" * 60)
        logger.info("STARTING AI TRADING STRATEGY BACKTEST")
        logger.info("=" * 60)
        
        # Load and prepare data
        logger.info("Loading historical data...")
        df_raw = pd.read_csv(data_path)
        
        if 'timestamp' in df_raw.columns:
            df_raw['timestamp'] = pd.to_datetime(df_raw['timestamp'])
            df_raw = df_raw.set_index('timestamp')
        
        # Filter date range if specified
        if start_date:
            df_raw = df_raw[df_raw.index >= start_date]
        if end_date:
            df_raw = df_raw[df_raw.index <= end_date]
        
        logger.info(f"Backtesting period: {df_raw.index[0]} to {df_raw.index[-1]}")
        logger.info(f"Total bars: {len(df_raw)}")
        
        # Compute features
        logger.info("Computing technical features...")
        df_features = compute_features(df_raw)
        df_features = ensure_column_order(df_features)
        df_features = df_features.dropna()
        
        logger.info(f"Features computed: {len(df_features)} bars available")
        
        # Initialize tracking
        sequence_length = self.model_config['sequence_length']
        start_idx = sequence_length + 50  # Allow warmup period
        
        logger.info("Starting backtesting simulation...")
        
        for i in range(start_idx, len(df_features)):
            current_timestamp = df_features.index[i]
            current_price = df_features['close'].iloc[i]
            
            # Update equity curve
            current_equity = self.balance + sum([pos['current_profit'] for pos in self.positions])
            self.equity_curve.append({
                'timestamp': current_timestamp,
                'balance': self.balance,
                'equity': current_equity
            })
            
            # Update existing positions first
            self.update_positions(current_timestamp, current_price)
            
            # Check for new signals every N bars (to avoid overtrading)
            signal_frequency = self.strategy_config.get('signal_frequency', 1)
            if i % signal_frequency == 0:
                
                # Prepare features for prediction
                model_input = self.prepare_features_for_prediction(df_features, i)
                
                if model_input is not None:
                    # Make prediction
                    predictions = self.make_prediction(model_input, current_price)
                    h1_prediction = predictions[0] if predictions else current_price
                    
                    # Check for trading signal
                    spread = self.strategy_config.get('typical_spread', 0.00015)
                    signal = self.should_open_position(current_price, h1_prediction, spread)
                    
                    if signal['action'] == 'open':
                        self.open_position(current_timestamp, signal, current_price, h1_prediction)
        
        # Close any remaining positions
        final_price = df_features['close'].iloc[-1]
        final_timestamp = df_features.index[-1]
        
        for pos in self.positions.copy():
            self.close_position(final_timestamp, pos, 'End of backtest', final_price)
        self.positions.clear()
        
        logger.info("Backtesting completed!")
        
        # Generate results
        self.generate_results()
    
    def generate_results(self):
        """Generate comprehensive backtest results"""
        logger.info("=" * 60)
        logger.info("BACKTEST RESULTS")
        logger.info("=" * 60)
        
        if not self.closed_positions:
            logger.warning("No trades executed during backtest period")
            return
        
        # Basic statistics
        total_trades = len(self.closed_positions)
        winning_trades = len([t for t in self.closed_positions if t['profit'] > 0])
        losing_trades = total_trades - winning_trades
        
        total_profit = sum([t['profit'] for t in self.closed_positions])
        gross_profit = sum([t['profit'] for t in self.closed_positions if t['profit'] > 0])
        gross_loss = sum([t['profit'] for t in self.closed_positions if t['profit'] < 0])
        
        win_rate = (winning_trades / total_trades) * 100 if total_trades > 0 else 0
        
        # Calculate additional metrics
        if winning_trades > 0:
            avg_win = gross_profit / winning_trades
            max_win = max([t['profit'] for t in self.closed_positions if t['profit'] > 0])
        else:
            avg_win = 0
            max_win = 0
        
        if losing_trades > 0:
            avg_loss = gross_loss / losing_trades
            max_loss = min([t['profit'] for t in self.closed_positions if t['profit'] < 0])
        else:
            avg_loss = 0
            max_loss = 0
        
        profit_factor = abs(gross_profit / gross_loss) if gross_loss != 0 else float('inf')
        
        # Print results
        logger.info(f"Initial Balance: ${self.strategy_config['initial_balance']:,.2f}")
        logger.info(f"Final Balance: ${self.balance:,.2f}")
        logger.info(f"Total Net Profit: ${total_profit:+,.2f}")
        logger.info(f"Return: {(total_profit/self.strategy_config['initial_balance']*100):+.2f}%")
        logger.info("")
        logger.info(f"Total Trades: {total_trades}")
        logger.info(f"Winning Trades: {winning_trades} ({win_rate:.1f}%)")
        logger.info(f"Losing Trades: {losing_trades} ({100-win_rate:.1f}%)")
        logger.info("")
        logger.info(f"Gross Profit: ${gross_profit:,.2f}")
        logger.info(f"Gross Loss: ${gross_loss:,.2f}")
        logger.info(f"Profit Factor: {profit_factor:.2f}")
        logger.info("")
        logger.info(f"Average Win: ${avg_win:,.2f}")
        logger.info(f"Average Loss: ${avg_loss:,.2f}")
        logger.info(f"Max Win: ${max_win:,.2f}")
        logger.info(f"Max Loss: ${max_loss:,.2f}")
        
        # Target accuracy
        target_hits = len([t for t in self.closed_positions if t['target_hit']])
        target_accuracy = (target_hits / total_trades) * 100 if total_trades > 0 else 0
        logger.info(f"H1 Target Accuracy: {target_accuracy:.1f}%")
        
        # Save detailed results
        self.save_results()
    
    def save_results(self):
        """Save detailed results and create visualizations"""
        output_dir = Path('backtest_results')
        output_dir.mkdir(exist_ok=True)
        
        # Save trade log
        if self.closed_positions:
            trades_df = pd.DataFrame(self.closed_positions)
            trades_df.to_csv(output_dir / 'trade_log.csv', index=False)
        
        # Save equity curve
        if self.equity_curve:
            equity_df = pd.DataFrame(self.equity_curve)
            equity_df.to_csv(output_dir / 'equity_curve.csv', index=False)
            
            # Create equity curve plot
            plt.figure(figsize=(12, 6))
            plt.plot(equity_df['timestamp'], equity_df['equity'])
            plt.title('Equity Curve')
            plt.xlabel('Date')
            plt.ylabel('Equity ($)')
            plt.xticks(rotation=45)
            plt.tight_layout()
            plt.savefig(output_dir / 'equity_curve.png', dpi=150)
            plt.close()
        
        # Create profit distribution plot
        if self.closed_positions:
            profits = [t['profit'] for t in self.closed_positions]
            plt.figure(figsize=(10, 6))
            plt.hist(profits, bins=30, edgecolor='black', alpha=0.7)
            plt.title('Trade Profit Distribution')
            plt.xlabel('Profit ($)')
            plt.ylabel('Frequency')
            plt.axvline(0, color='red', linestyle='--', alpha=0.7)
            plt.tight_layout()
            plt.savefig(output_dir / 'profit_distribution.png', dpi=150)
            plt.close()
        
        logger.info(f"Results saved to: {output_dir.absolute()}")

def main():
    parser = argparse.ArgumentParser(description='AI Trading Strategy Backtester')
    parser.add_argument('--model_dir', type=str, required=True,
                       help='Directory containing trained model')
    parser.add_argument('--data_path', type=str, required=True,
                       help='Path to historical data CSV')
    parser.add_argument('--start_date', type=str,
                       help='Start date for backtest (YYYY-MM-DD)')
    parser.add_argument('--end_date', type=str,
                       help='End date for backtest (YYYY-MM-DD)')
    parser.add_argument('--initial_balance', type=float, default=10000,
                       help='Initial account balance')
    parser.add_argument('--risk_percent', type=float, default=1.0,
                       help='Risk percentage per trade')
    parser.add_argument('--min_prediction_change', type=float, default=0.1,
                       help='Minimum prediction change to trade (%)')
    parser.add_argument('--max_prediction_change', type=float, default=2.0,
                       help='Maximum prediction change to trade (%)')
    parser.add_argument('--force_close_after_bars', type=int, default=1,
                       help='Force close positions after N bars (0=disabled)')
    
    args = parser.parse_args()
    
    # Strategy configuration
    strategy_config = {
        'initial_balance': args.initial_balance,
        'risk_percent': args.risk_percent,
        'min_prediction_change': args.min_prediction_change,
        'max_prediction_change': args.max_prediction_change,
        'max_positions': 1,  # H1 scalping - single position
        'max_spread': 0.0003,  # 3 pips
        'typical_spread': 0.00015,  # 1.5 pips
        'tp_multiplier': 1.0,  # Take profit at exact prediction
        'min_lot_size': 0.01,
        'max_lot_size': 1.0,
        'force_close_after_bars': args.force_close_after_bars,
        'signal_frequency': 1  # Check for signals every bar
    }
    
    # Create backtester and run
    backtester = AITradingBacktester(args.model_dir, strategy_config)
    backtester.run_backtest(args.data_path, args.start_date, args.end_date)

if __name__ == '__main__':
    main()