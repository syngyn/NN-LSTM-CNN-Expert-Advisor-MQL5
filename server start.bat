@echo off
REM Windows batch script to start the PredictiveEA server
REM start_server.bat

echo =========================================
echo  PredictiveEA LSTM CNN Server Startup
echo =========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8 or higher
    pause
    exit /b 1
)

echo Python found: 
python --version

REM Check if virtual environment exists
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
    if %errorlevel% neq 0 (
        echo ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

REM Install/update requirements
echo Installing/updating requirements...
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo ERROR: Failed to install requirements
    pause
    exit /b 1
)

REM Run health check
echo.
echo Running health check...
python test_server.py --test health --url http://localhost:8000 >nul 2>&1
if %errorlevel% equ 0 (
    echo WARNING: Server appears to already be running
    echo.
    choice /C YN /M "Continue anyway? (Y/N)"
    if errorlevel 2 exit /b 0
)

REM Start the server
echo.
echo Starting LSTM CNN Prediction Server...
echo Server will be available at: http://localhost:8000
echo.
echo Available endpoints:
echo   GET  /health              - Health check
echo   POST /predict             - Generate predictions  
echo   POST /train               - Train model
echo   GET  /model/info          - Model information
echo   GET  /generate_sample_data - Generate test data
echo.
echo Press Ctrl+C to stop the server
echo.

python server.py

echo.
echo Server stopped.
pause

REM Linux/MacOS shell script version
REM Create start_server.sh with the following content:

#!/bin/bash
# Linux/MacOS shell script to start the PredictiveEA server
# start_server.sh

echo "========================================="
echo " PredictiveEA LSTM CNN Server Startup"
echo "========================================="
echo

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed or not in PATH"
    echo "Please install Python 3.8 or higher"
    exit 1
fi

echo "Python found:"
python3 --version

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create virtual environment"
        exit 1
    fi
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Install/update requirements
echo "Installing/updating requirements..."
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install requirements"
    exit 1
fi

# Run health check
echo
echo "Running health check..."
python test_server.py --test health --url http://localhost:8000 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "WARNING: Server appears to already be running"
    echo
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Start the server
echo
echo "Starting LSTM CNN Prediction Server..."
echo "Server will be available at: http://localhost:8000"
echo
echo "Available endpoints:"
echo "  GET  /health              - Health check"
echo "  POST /predict             - Generate predictions"
echo "  POST /train               - Train model"
echo "  GET  /model/info          - Model information"
echo "  GET  /generate_sample_data - Generate test data"
echo
echo "Press Ctrl+C to stop the server"
echo

python server.py

echo
echo "Server stopped."

# Make the script executable with:
# chmod +x start_server.sh

# Additional test script for Windows
REM test_system.bat

@echo off
echo =========================================
echo  PredictiveEA System Test
echo =========================================
echo.

REM Activate virtual environment
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
) else (
    echo ERROR: Virtual environment not found
    echo Please run start_server.bat first
    pause
    exit /b 1
)

echo Running comprehensive system tests...
echo.

REM Run tests
python test_server.py --url http://localhost:8000

if %errorlevel% equ 0 (
    echo.
    echo ✓ All tests passed! System is ready.
) else (
    echo.
    echo ✗ Some tests failed. Check the output above.
)

echo.
pause

# Additional test script for Linux/MacOS
#!/bin/bash
# test_system.sh

echo "========================================="
echo " PredictiveEA System Test"
echo "========================================="
echo

# Activate virtual environment
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
else
    echo "ERROR: Virtual environment not found"
    echo "Please run start_server.sh first"
    exit 1
fi

echo "Running comprehensive system tests..."
echo

# Run tests
python test_server.py --url http://localhost:8000

if [ $? -eq 0 ]; then
    echo
    echo "✓ All tests passed! System is ready."
else
    echo
    echo "✗ Some tests failed. Check the output above."
fi

echo