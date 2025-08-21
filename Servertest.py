#!/usr/bin/env python3
"""
Test script for LSTM CNN Prediction Server
Tests all endpoints and validates responses
"""

import requests
import json
import time
import numpy as np
from typing import Dict, Any
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ServerTester:
    """Test suite for the prediction server"""
    
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.timeout = 30
        
    def test_health_check(self) -> bool:
        """Test health check endpoint"""
        try:
            logger.info("Testing health check endpoint...")
            
            response = self.session.get(f"{self.base_url}/health")
            
            if response.status_code != 200:
                logger.error(f"Health check failed with status: {response.status_code}")
                return False
            
            data = response.json()
            
            # Validate response structure
            required_fields = ['status', 'timestamp', 'model_trained', 'version']
            for field in required_fields:
                if field not in data:
                    logger.error(f"Missing field in health response: {field}")
                    return False
            
            logger.info(f"Health check passed: {data['status']}")
            logger.info(f"Model trained: {data['model_trained']}")
            logger.info(f"Version: {data['version']}")
            
            return True
            
        except Exception as e:
            logger.error(f"Health check error: {e}")
            return False
    
    def test_sample_data_generation(self) -> Dict[str, Any]:
        """Test sample data generation"""
        try:
            logger.info("Testing sample data generation...")
            
            response = self.session.get(f"{self.base_url}/generate_sample_data")
            
            if response.status_code != 200:
                logger.error(f"Sample data generation failed: {response.status_code}")
                return None
            
            data = response.json()
            
            if not data.get('success', False):
                logger.error(f"Sample data generation failed: {data.get('error')}")
                return None
            
            # Validate data structure
            sample_data = data['data']
            bars_count = data['bars_count']
            features_per_bar = data['features_per_bar']
            
            expected_length = bars_count * features_per_bar
            if len(sample_data) != expected_length:
                logger.error(f"Data length mismatch: {len(sample_data)} != {expected_length}")
                return None
            
            logger.info(f"Sample data generated: {bars_count} bars, {features_per_bar} features")
            logger.info(f"Data length: {len(sample_data)}")
            logger.info(f"Symbol: {data['symbol']}")
            logger.info(f"Current price: {data['current_price']}")
            
            return data
            
        except Exception as e:
            logger.error(f"Sample data generation error: {e}")
            return None
    
    def test_prediction(self, market_data: Dict[str, Any] = None) -> bool:
        """Test prediction endpoint"""
        try:
            logger.info("Testing prediction endpoint...")
            
            # Use sample data if not provided
            if market_data is None:
                market_data = self.test_sample_data_generation()
                if market_data is None:
                    return False
            
            # Prepare prediction request
            prediction_request = {
                'symbol': market_data['symbol'],
                'timeframe': market_data['timeframe'],
                'data': market_data['data'],
                'current_price': market_data['current_price'],
                'prediction_request': {
                    'hourly_count': 5,
                    'daily_count': 5
                }
            }
            
            logger.info("Sending prediction request...")
            start_time = time.time()
            
            response = self.session.post(
                f"{self.base_url}/predict",
                json=prediction_request,
                headers={'Content-Type': 'application/json'}
            )
            
            prediction_time = time.time() - start_time
            logger.info(f"Prediction completed in {prediction_time:.2f} seconds")
            
            if response.status_code != 200:
                logger.error(f"Prediction failed with status: {response.status_code}")
                logger.error(f"Response: {response.text}")
                return False
            
            result = response.json()
            
            if not result.get('success', False):
                logger.error(f"Prediction failed: {result.get('error')}")
                return False
            
            # Validate prediction structure
            required_fields = ['hourly_predictions', 'daily_predictions', 'model_info']
            for field in required_fields:
                if field not in result:
                    logger.error(f"Missing field in prediction response: {field}")
                    return False
            
            hourly_preds = result['hourly_predictions']
            daily_preds = result['daily_predictions']
            
            logger.info(f"Hourly predictions: {len(hourly_preds)} values")
            logger.info(f"Daily predictions: {len(daily_preds)} values")
            
            # Log prediction values
            current_price = result['current_price']
            logger.info(f"Current price: {current_price}")
            
            logger.info("Hourly predictions:")
            for i, pred in enumerate(hourly_preds):
                change_pct = ((pred - current_price) / current_price) * 100
                logger.info(f"  H+{i+1}: {pred:.5f} ({change_pct:+.2f}%)")
            
            logger.info("Daily predictions:")
            for i, pred in enumerate(daily_preds):
                change_pct = ((pred - current_price) / current_price) * 100
                logger.info(f"  D+{i+1}: {pred:.5f} ({change_pct:+.2f}%)")
            
            # Validate prediction values
            for pred in hourly_preds + daily_preds:
                if pred <= 0:
                    logger.error(f"Invalid prediction value: {pred}")
                    return False
                
                # Check if predictions are reasonable (within ±50% of current price)
                change_pct = abs((pred - current_price) / current_price)
                if change_pct > 0.5:
                    logger.warning(f"Large prediction change: {change_pct*100:.1f}%")
            
            logger.info("Prediction test passed!")
            return True
            
        except Exception as e:
            logger.error(f"Prediction test error: {e}")
            return False
    
    def test_model_info(self) -> bool:
        """Test model info endpoint"""
        try:
            logger.info("Testing model info endpoint...")
            
            response = self.session.get(f"{self.base_url}/model/info")
            
            if response.status_code != 200:
                logger.error(f"Model info failed with status: {response.status_code}")
                return False
            
            data = response.json()
            
            logger.info(f"Model trained: {data.get('model_trained', False)}")
            logger.info(f"Sequence length: {data.get('sequence_length', 0)}")
            logger.info(f"Features: {data.get('n_features', 0)}")
            
            if data.get('training_history'):
                logger.info(f"Training history entries: {len(data['training_history'])}")
            
            return True
            
        except Exception as e:
            logger.error(f"Model info test error: {e}")
            return False
    
    def test_training(self, market_data: Dict[str, Any] = None) -> bool:
        """Test training endpoint"""
        try:
            logger.info("Testing training endpoint...")
            
            # Use sample data if not provided
            if market_data is None:
                market_data = self.test_sample_data_generation()
                if market_data is None:
                    return False
            
            # Prepare training request
            training_request = {
                'data': market_data['data'],
                'epochs': 5  # Use fewer epochs for testing
            }
            
            logger.info("Sending training request...")
            start_time = time.time()
            
            response = self.session.post(
                f"{self.base_url}/train",
                json=training_request,
                headers={'Content-Type': 'application/json'}
            )
            
            training_time = time.time() - start_time
            logger.info(f"Training completed in {training_time:.2f} seconds")
            
            if response.status_code != 200:
                logger.error(f"Training failed with status: {response.status_code}")
                logger.error(f"Response: {response.text}")
                return False
            
            result = response.json()
            
            if not result.get('success', False):
                logger.error(f"Training failed: {result.get('error')}")
                return False
            
            metrics = result.get('training_metrics', {})
            logger.info(f"Training MSE: {metrics.get('mse', 'N/A')}")
            logger.info(f"Training MAE: {metrics.get('mae', 'N/A')}")
            logger.info(f"Epochs: {metrics.get('epochs', 'N/A')}")
            logger.info(f"Samples: {metrics.get('samples', 'N/A')}")
            
            return True
            
        except Exception as e:
            logger.error(f"Training test error: {e}")
            return False
    
    def test_error_handling(self) -> bool:
        """Test error handling"""
        try:
            logger.info("Testing error handling...")
            
            # Test invalid prediction request
            invalid_request = {'invalid': 'data'}
            
            response = self.session.post(
                f"{self.base_url}/predict",
                json=invalid_request
            )
            
            if response.status_code == 200:
                logger.error("Expected error response for invalid request")
                return False
            
            # Test malformed JSON
            response = self.session.post(
                f"{self.base_url}/predict",
                data="invalid json",
                headers={'Content-Type': 'application/json'}
            )
            
            if response.status_code == 200:
                logger.error("Expected error response for malformed JSON")
                return False
            
            logger.info("Error handling test passed!")
            return True
            
        except Exception as e:
            logger.error(f"Error handling test error: {e}")
            return False
    
    def run_comprehensive_test(self) -> bool:
        """Run all tests"""
        logger.info("=" * 50)
        logger.info("Starting comprehensive server test")
        logger.info("=" * 50)
        
        tests = [
            ("Health Check", self.test_health_check),
            ("Sample Data Generation", lambda: self.test_sample_data_generation() is not None),
            ("Model Info", self.test_model_info),
            ("Training", self.test_training),
            ("Prediction", self.test_prediction),
            ("Error Handling", self.test_error_handling),
        ]
        
        results = {}
        
        for test_name, test_func in tests:
            logger.info(f"\n--- {test_name} ---")
            try:
                result = test_func()
                results[test_name] = result
                status = "PASSED" if result else "FAILED"
                logger.info(f"{test_name}: {status}")
            except Exception as e:
                results[test_name] = False
                logger.error(f"{test_name}: FAILED - {e}")
        
        # Summary
        logger.info("\n" + "=" * 50)
        logger.info("Test Summary")
        logger.info("=" * 50)
        
        passed = sum(results.values())
        total = len(results)
        
        for test_name, result in results.items():
            status = "✓ PASSED" if result else "✗ FAILED"
            logger.info(f"{test_name:<25} {status}")
        
        logger.info(f"\nOverall: {passed}/{total} tests passed")
        
        if passed == total:
            logger.info("🎉 All tests passed!")
            return True
        else:
            logger.error(f"❌ {total - passed} tests failed!")
            return False

def main():
    """Main test function"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Test LSTM CNN Prediction Server")
    parser.add_argument("--url", default="http://localhost:8000", 
                       help="Server URL (default: http://localhost:8000)")
    parser.add_argument("--test", choices=["health", "predict", "train", "all"],
                       default="all", help="Specific test to run")
    
    args = parser.parse_args()
    
    tester = ServerTester(args.url)
    
    try:
        if args.test == "health":
            success = tester.test_health_check()
        elif args.test == "predict":
            success = tester.test_prediction()
        elif args.test == "train":
            success = tester.test_training()
        else:
            success = tester.run_comprehensive_test()
        
        exit_code = 0 if success else 1
        exit(exit_code)
        
    except KeyboardInterrupt:
        logger.info("\nTest interrupted by user")
        exit(1)
    except Exception as e:
        logger.error(f"Test suite error: {e}")
        exit(1)

if __name__ == "__main__":
    main()