#!/data/user/0/com.termux/files/usr/bin/bash
# Starts Ollama server on Termux for PrivateAgent

export OLLAMA_HOST=0.0.0.0:11434
echo "Starting Ollama server on http://127.0.0.1:11434 ..."
nohup ollama serve > /data/user/0/com.termux/files/home/ollama.log 2>&1 &
sleep 2

echo "Checking running Ollama instance:"
ollama list
echo ""
echo "Ollama is ready for PrivateAgent! You can now use offline AI without any API keys."
