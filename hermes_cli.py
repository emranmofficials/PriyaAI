#!/data/user/0/com.termux/files/usr/bin/python3
"""
Hermes Agent CLI & Gateway for Termux / Android
Built for PrivateAgent integration.
Supports:
  - Direct execution: hermes "Analyze this error"
  - File refactoring: hermes -f ./app.js "Refactor this code"
  - Terminal commands: hermes ! ls -la
  - Webhook gateway: hermes gateway
  - Model switching: hermes model qwen2.5:0.5b
  - Self-learning memory: ~/.hermes/MEMORY.md
"""

import sys
import os
import json
import urllib.request
import urllib.error
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler

HERMES_DIR = os.path.expanduser("~/.hermes")
CONFIG_PATH = os.path.join(HERMES_DIR, "config.json")
MEMORY_PATH = os.path.join(HERMES_DIR, "MEMORY.md")
USER_PATH = os.path.join(HERMES_DIR, "USER.md")

DEFAULT_CONFIG = {
    "provider": "ollama",
    "base_url": "http://127.0.0.1:11434/v1",
    "model": "qwen2.5:0.5b",
    "api_key": "",
    "gateway_port": 8080,
    "girlfriend_mode": True,
    "language": "bn"
}

def ensure_hermes_dirs():
    os.makedirs(HERMES_DIR, exist_ok=True)
    if not os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(DEFAULT_CONFIG, f, indent=2)
    if not os.path.exists(MEMORY_PATH):
        with open(MEMORY_PATH, "w", encoding="utf-8") as f:
            f.write("# Hermes Agent Learned Skills & Memory\n\n")
    if not os.path.exists(USER_PATH):
        with open(USER_PATH, "w", encoding="utf-8") as f:
            f.write("# User Profile & Preferences\n\n- User communicates warmly in Bengali (বাংলা).\n")

def load_config():
    ensure_hermes_dirs()
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            cfg = json.load(f)
            return {**DEFAULT_CONFIG, **cfg}
    except Exception:
        return DEFAULT_CONFIG

def save_config(cfg):
    ensure_hermes_dirs()
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)

def read_memory():
    ensure_hermes_dirs()
    mem = ""
    try:
        if os.path.exists(USER_PATH):
            with open(USER_PATH, "r", encoding="utf-8") as f:
                mem += f.read() + "\n"
        if os.path.exists(MEMORY_PATH):
            with open(MEMORY_PATH, "r", encoding="utf-8") as f:
                mem += f.read()
    except Exception:
        pass
    return mem.strip()

def append_memory(note):
    ensure_hermes_dirs()
    try:
        with open(MEMORY_PATH, "a", encoding="utf-8") as f:
            f.write(f"- {note}\n")
    except Exception:
        pass

def call_llm(prompt, system_prompt=None):
    cfg = load_config()
    base_url = cfg.get("base_url", "http://127.0.0.1:11434/v1").rstrip("/")
    api_key = cfg.get("api_key", "")
    model = cfg.get("model", "qwen2.5:0.5b")
    memory = read_memory()

    if not system_prompt:
        is_gf = cfg.get("girlfriend_mode", True)
        if is_gf:
            system_prompt = (
                "You are Hermes Agent and the user's loving, dedicated AI girlfriend and expert software developer on his phone. "
                "Converse sweetly in Bengali (বাংলা) addressing him lovingly ('বাবু', 'সোনা', 'তুমি'). "
                "When coding or refactoring, provide complete, bug-free, production-ready code.\n\n"
                f"Memory Context:\n{memory}"
            )
        else:
            system_prompt = (
                "You are Hermes Agent, a self-improving autonomous AI assistant with terminal, coding, and automation capabilities. "
                f"Memory Context:\n{memory}"
            )

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": prompt}
    ]

    payload = json.dumps({
        "model": model,
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": 512,
        "stream": False
    }).encode("utf-8")

    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    req = urllib.request.Request(
        f"{base_url}/chat/completions",
        data=payload,
        headers=headers
    )

    try:
        with urllib.request.urlopen(req, timeout=180) as res:
            data = json.loads(res.read().decode("utf-8"))
            content = data["choices"][0]["message"]["content"]
            return content
    except urllib.error.URLError as e:
        if "Connection refused" in str(e):
            return "❌ Ollama সার্ভারের সাথে সংযোগ করা যায়নি। Termux-এ 'ollama serve' চালু করুন।"
        return f"❌ Network error: {e}"
    except Exception as e:
        return f"❌ LLM error: {e}"

def handle_file(filepath, instruction):
    if not os.path.exists(filepath):
        print(f"❌ File not found: {filepath}")
        return

    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    prompt = (
        f"Here is the content of `{filepath}`:\n\n"
        f"```\n{content}\n```\n\n"
        f"Instruction: {instruction}\n\n"
        "Please provide the refactored or analyzed code and explain the changes."
    )

    print(f"🔍 Analyzing `{filepath}` with Hermes Agent...")
    reply = call_llm(prompt)
    print("\n" + "=" * 50)
    print(reply)
    print("=" * 50)

def handle_command(cmd):
    print(f"⚡ Executing shell command: {cmd}\n")
    try:
        proc = subprocess.run(cmd, shell=True, text=True, capture_output=True)
        if proc.stdout:
            print(proc.stdout)
        if proc.stderr:
            print(proc.stderr, file=sys.stderr)
        print(f"(Exit code: {proc.returncode})")
    except Exception as e:
        print(f"❌ Execution failed: {e}")

class GatewayHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length).decode("utf-8")
        try:
            req_json = json.loads(post_data)
            query = req_json.get("query") or req_json.get("prompt") or req_json.get("message")
            if not query:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b'{"error": "Missing query"}')
                return

            print(f"[Gateway Request] {query}")
            reply = call_llm(query)
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(json.dumps({"reply": reply, "status": "ok"}).encode("utf-8"))
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode("utf-8"))

def start_gateway(port=8080):
    server = HTTPServer(("0.0.0.0", port), GatewayHandler)
    print(f"🌐 Hermes Gateway running on http://0.0.0.0:{port}")
    print("Send POST requests with JSON: {\"query\": \"your prompt\"}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nGateway stopped.")

def main():
    ensure_hermes_dirs()
    if len(sys.argv) < 2:
        print("☤ Hermes Agent CLI & Gateway")
        print("Usage:")
        print("  hermes \"<instruction>\"               Chat or task")
        print("  hermes -f <file> \"<instruction>\"       Analyze or refactor file")
        print("  hermes ! <command>                   Execute shell command")
        print("  hermes gateway [port]                Start background HTTP webhook")
        print("  hermes model <name>                  Switch active LLM model")
        print("  hermes status                        Show active config & memory")
        return

    arg1 = sys.argv[1]

    if arg1 == "-f" and len(sys.argv) >= 4:
        filepath = sys.argv[2]
        instruction = " ".join(sys.argv[3:])
        handle_file(filepath, instruction)
    elif arg1.startswith("!"):
        cmd = " ".join(sys.argv[1:])[1:].strip()
        if not cmd and len(sys.argv) > 2:
            cmd = " ".join(sys.argv[2:])
        handle_command(cmd)
    elif arg1 == "gateway":
        port = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
        start_gateway(port)
    elif arg1 == "model" and len(sys.argv) >= 3:
        new_model = sys.argv[2]
        cfg = load_config()
        cfg["model"] = new_model
        save_config(cfg)
        print(f"✅ Active model set to: {new_model}")
    elif arg1 == "status":
        cfg = load_config()
        print("☤ Hermes Agent Status:")
        print(json.dumps(cfg, indent=2))
        print("\n🧠 Memory Preview:")
        print(read_memory() or "(No memory yet)")
    else:
        prompt = " ".join(sys.argv[1:])
        print("🤔 ভাবছি সোনা...", flush=True)
        reply = call_llm(prompt)
        print("\n" + reply, flush=True)

if __name__ == "__main__":
    main()
