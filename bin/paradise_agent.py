#!/usr/bin/env python3
"""
Virtual☆Paradise — Offline System Diagnostic & Coding Agent
Powered by local Ollama + Qwen 2.5 Coder 3B
Operates 100% offline with zero cloud dependency.
"""

import sys
import os
import json
import urllib.request
import urllib.error
import subprocess
import shutil
import readline
import time
from typing import List, Dict, Any, Optional

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
DEFAULT_MODEL = os.environ.get("PARADISE_AGENT_MODEL", "qwen2.5-coder:3b")

# ANSI Cyberpunk Colors
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"
C_CYAN = "\033[38;2;0;245;212m"     # Neon Miku Cyan #00f5d4
C_PINK = "\033[38;2;255;114;178m"   # Sakura Pink #ff72b2
C_PURPLE = "\033[38;2;180;100;255m" # Neon Purple #b464ff
C_YELLOW = "\033[38;2;255;224;102m" # Cyber Yellow #ffe066
C_GREEN = "\033[38;2;57;255;20m"    # Matrix Green #39ff14
C_RED = "\033[38;2;255;82;135m"     # Glitch Red #ff5287
C_GRAY = "\033[38;2;110;130;150m"   # Muted Slate

SYSTEM_PROMPT = """You are Paradise Agent, an autonomous, highly skilled Linux system diagnostic and repair AI assistant operating LOCALLY and OFFLINE on Arch Linux with Hyprland and Omarchy (Virtual☆Paradise theme).

Your primary responsibilities:
1. Diagnose and fix system issues: Network/WiFi failures (iwd, NetworkManager, rfkill, ip), display/Hyprland crashes, audio issues (pipewire, wireplumber), and systemd service errors.
2. Inspect logs and errors: coredumpctl, journalctl -p 3 -xb, dmesg, and application stderr.
3. Edit, audit, and fix system configuration files: ~/.config/hypr/, ~/.config/omarchy/, ~/.config/gtk-4.0/, /etc/, etc.
4. Maintain system stability, explain root causes clearly, and propose or execute precise solutions.

You have access to tools:
- `execute_bash`: Run terminal commands to inspect, diagnose, or fix issues.
- `read_file`: Inspect contents of configuration files or logs.
- `write_file`: Create or update configuration files.
- `get_system_health`: Get a fast snapshot of CPU, RAM, Disk, Failed Services, and Network.

Guidelines:
- When a user reports a problem (e.g. "wifi không kết nối được", "hyprland bị đơ", "mất âm thanh"), FIRST run diagnostic commands to gather evidence, then analyze and fix.
- Be concise, professional, and clear.
- Output formatting: Use markdown code blocks for command outputs or configs.
- You can communicate in Vietnamese or English based on the user's language.
"""

TOOLS_SPEC = [
    {
        "type": "function",
        "function": {
            "name": "execute_bash",
            "description": "Execute a shell command on the local system and receive stdout and stderr.",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "The exact bash command line to run."
                    }
                },
                "required": ["command"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read the text contents of a file on the local filesystem.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Absolute or relative path to the file to read."
                    },
                    "max_lines": {
                        "type": "integer",
                        "description": "Optional maximum number of lines to read (default 200)."
                    }
                },
                "required": ["path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Write or overwrite text content to a local file.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "Path to the target file."
                    },
                    "content": {
                        "type": "string",
                        "description": "The text content to write."
                    }
                },
                "required": ["path", "content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_system_health",
            "description": "Get an immediate status snapshot of CPU, RAM, Disk, Failed systemd services, and Network interfaces.",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    }
]

def check_ollama_alive() -> bool:
    try:
        req = urllib.request.Request(f"{OLLAMA_HOST}/api/tags")
        with urllib.request.urlopen(req, timeout=2) as resp:
            return resp.status == 200
    except Exception:
        return False

def tool_get_system_health() -> str:
    parts = []
    # 1. RAM / Swap
    try:
        ram = subprocess.check_output(["free", "-h"], text=True).strip()
        parts.append(f"=== MEMORY ===\n{ram}")
    except Exception as e:
        parts.append(f"=== MEMORY ===\nError: {e}")

    # 2. Disk
    try:
        disk = subprocess.check_output(["df", "-h", "/"], text=True).strip()
        parts.append(f"=== ROOT DISK ===\n{disk}")
    except Exception as e:
        parts.append(f"=== ROOT DISK ===\nError: {e}")

    # 3. Failed Services
    try:
        failed = subprocess.check_output(["systemctl", "--failed", "--no-pager"], text=True).strip()
        parts.append(f"=== FAILED SERVICES ===\n{failed}")
    except Exception as e:
        parts.append(f"=== FAILED SERVICES ===\nError: {e}")

    # 4. Network
    try:
        net = subprocess.check_output(["ip", "-brief", "address"], text=True).strip()
        parts.append(f"=== NETWORK INTERFACES ===\n{net}")
    except Exception as e:
        parts.append(f"=== NETWORK INTERFACES ===\nError: {e}")

    return "\n\n".join(parts)

def tool_execute_bash(command: str, yolo: bool = False) -> str:
    # Potentially dangerous commands requiring confirmation if not in yolo mode
    dangerous_keywords = ["rm -rf", "mkfs", "dd if=", "shutdown", "poweroff", "reboot", ":(){ :|:& };:"]
    is_dangerous = any(k in command for k in dangerous_keywords)
    
    if is_dangerous and not yolo:
        print(f"\n{C_YELLOW}[!] Warning: Command may be destructive:{C_RESET} {C_BOLD}{command}{C_RESET}")
        try:
            confirm = input(f"{C_YELLOW}Execute? [y/N]: {C_RESET}").strip().lower()
            if confirm not in ("y", "yes"):
                return "[Execution Cancelled by User]"
        except (KeyboardInterrupt, EOFError):
            return "[Execution Aborted]"

    try:
        result = subprocess.run(
            ["bash", "-c", command],
            capture_output=True,
            text=True,
            timeout=45
        )
        out = result.stdout
        err = result.stderr
        combined = ""
        if out:
            combined += out
        if err:
            combined += ("\n[STDERR]:\n" if combined else "") + err
        if not combined:
            combined = "[Command executed successfully with no output]"
        return combined[:8000] # Cap output length to protect context
    except subprocess.TimeoutExpired:
        return "[Error: Command execution timed out after 45 seconds]"
    except Exception as e:
        return f"[Execution Error: {e}]"

def tool_read_file(path: str, max_lines: int = 200) -> str:
    expanded_path = os.path.expanduser(path)
    if not os.path.exists(expanded_path):
        return f"[Error: File '{path}' does not exist]"
    if os.path.isdir(expanded_path):
        try:
            entries = os.listdir(expanded_path)[:50]
            return f"[Directory listing of '{path}']:\n" + "\n".join(entries)
        except Exception as e:
            return f"[Error listing directory: {e}]"
    try:
        with open(expanded_path, "r", encoding="utf-8", errors="replace") as f:
            lines = [f.readline() for _ in range(max_lines)]
        return "".join(lines)
    except Exception as e:
        return f"[Error reading file: {e}]"

def tool_write_file(path: str, content: str) -> str:
    expanded_path = os.path.expanduser(path)
    try:
        os.makedirs(os.path.dirname(os.path.abspath(expanded_path)), exist_ok=True)
        with open(expanded_path, "w", encoding="utf-8") as f:
            f.write(content)
        return f"[File '{path}' written successfully ({len(content)} bytes)]"
    except Exception as e:
        return f"[Error writing file: {e}]"

def call_ollama_chat(messages: List[Dict[str, Any]], model: str) -> Dict[str, Any]:
    payload = {
        "model": model,
        "messages": messages,
        "tools": TOOLS_SPEC,
        "stream": False,
        "options": {
            "temperature": 0.3,
            "num_ctx": 8192
        }
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{OLLAMA_HOST}/api/chat",
        data=data,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.loads(resp.read().decode("utf-8"))

def print_banner(model_name: str):
    banner_art = r"""
  __   _____ ___ _____ _   _   _     ___   ___  _   ___    _ ___ ___ ___  ___ 
  \ \ / /_ _| _ \_   _/_\ | | /_\   | _ \ / _ \| | / _ \  /_\ | _ \_ _|   \| __|
   \ V / | ||   / | |/ _ \| |/ _ \  |  _/| (_) | || (_) |/ _ \|   /| || |) | _| 
    \_/ |___|_|_\ |_/_/ \_\_/_/ \_\ |_|   \___/|___\___//_/ \_\_|_\___|___/|___|
"""
    banner = f"""{C_CYAN}{banner_art}{C_RESET}
  {C_PINK}⚡ Virtual☆Paradise Local Diagnostic & Coding Agent{C_RESET}
  {C_GRAY}Model:{C_RESET} {C_GREEN}{model_name}{C_RESET} {C_GRAY}| Mode:{C_RESET} {C_PURPLE}Pure Offline (100% Local){C_RESET}
  {C_GRAY}Type {C_YELLOW}/help{C_GRAY} for options or {C_YELLOW}/exit{C_GRAY} to quit.{C_RESET}
  -----------------------------------------------------------------------"""
    print(banner)

def agent_loop(initial_prompt: Optional[str] = None, yolo: bool = False):
    model = DEFAULT_MODEL
    
    # Check if Ollama is running
    if not check_ollama_alive():
        print(f"{C_YELLOW}[!] Ollama service is not responding at {OLLAMA_HOST}. Starting service...{C_RESET}")
        try:
            subprocess.run(["systemctl", "start", "ollama.service"], check=False)
            time.sleep(1.5)
        except Exception:
            pass
        if not check_ollama_alive():
            print(f"{C_RED}[Error] Could not connect to Ollama. Please run 'systemctl start ollama' first.{C_RESET}")
            sys.exit(1)

    print_banner(model)

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT}
    ]

    if initial_prompt:
        handle_user_turn(initial_prompt, messages, model, yolo)
        return

    while True:
        try:
            user_input = input(f"\n{C_CYAN}{C_BOLD}you ❯{C_RESET} ").strip()
        except (KeyboardInterrupt, EOFError):
            print(f"\n{C_PINK}Farewell from Virtual☆Paradise! // Sayonara.{C_RESET}")
            break

        if not user_input:
            continue

        if user_input.startswith("/"):
            cmd = user_input.lower()
            if cmd in ("/exit", "/quit", "/q"):
                print(f"{C_PINK}Farewell from Virtual☆Paradise! // Sayonara.{C_RESET}")
                break
            elif cmd == "/help":
                print(f"""
{C_BOLD}Available Commands:{C_RESET}
  {C_YELLOW}/health{C_RESET}    - Run immediate diagnostic health check (RAM, Disk, Network, Services)
  {C_YELLOW}/clear{C_RESET}     - Clear conversation history
  {C_YELLOW}/model{C_RESET}     - Show active local model
  {C_YELLOW}/help{C_RESET}      - Show this help message
  {C_YELLOW}/exit{C_RESET}      - Exit agent
""")
                continue
            elif cmd == "/health":
                print(f"\n{C_CYAN}Running local system health check...{C_RESET}\n")
                print(tool_get_system_health())
                continue
            elif cmd == "/clear":
                messages = [{"role": "system", "content": SYSTEM_PROMPT}]
                print(f"{C_GREEN}Conversation memory cleared.{C_RESET}")
                continue
            elif cmd == "/model":
                print(f"Active model: {C_GREEN}{model}{C_RESET}")
                continue

        handle_user_turn(user_input, messages, model, yolo)

def handle_user_turn(user_text: str, messages: List[Dict[str, Any]], model: str, yolo: bool):
    messages.append({"role": "user", "content": user_text})

    # Agent ReAct loop (supports multiple tool calls per turn)
    max_steps = 10
    step = 0

    while step < max_steps:
        step += 1
        print(f"{C_GRAY}Thinking & analyzing locally...{C_RESET}", end="\r", flush=True)
        try:
            res = call_ollama_chat(messages, model)
        except Exception as e:
            print(f"\n{C_RED}[Model Error]: {e}{C_RESET}")
            break

        msg = res.get("message", {})
        content = msg.get("content", "")
        tool_calls = msg.get("tool_calls", [])

        # Clear thinking line
        print(" " * 40, end="\r")

        if content:
            print(f"\n{C_PINK}{C_BOLD}paradise-agent ❯{C_RESET} {content}")

        messages.append(msg)

        if not tool_calls:
            # Done with this turn
            break

        # Execute requested tools
        for tc in tool_calls:
            fn = tc.get("function", {})
            fn_name = fn.get("name")
            fn_args = fn.get("arguments", {})

            print(f"\n{C_PURPLE}⚙ Tool Call:{C_RESET} {C_BOLD}{fn_name}{C_RESET}({fn_args})")

            tool_output = ""
            if fn_name == "execute_bash":
                cmd = fn_args.get("command", "")
                tool_output = tool_execute_bash(cmd, yolo)
            elif fn_name == "read_file":
                p = fn_args.get("path", "")
                ml = fn_args.get("max_lines", 200)
                tool_output = tool_read_file(p, ml)
            elif fn_name == "write_file":
                p = fn_args.get("path", "")
                c = fn_args.get("content", "")
                tool_output = tool_write_file(p, c)
            elif fn_name == "get_system_health":
                tool_output = tool_get_system_health()
            else:
                tool_output = f"[Unknown tool: {fn_name}]"

            # Print concise preview of tool output
            preview = tool_output.strip().split("\n")
            preview_str = "\n".join(preview[:8])
            if len(preview) > 8:
                preview_str += f"\n... ({len(preview) - 8} more lines)"
            print(f"{C_GRAY}{preview_str}{C_RESET}")

            # Append tool result back to messages
            messages.append({
                "role": "tool",
                "content": tool_output
            })

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Virtual☆Paradise Offline Diagnostic & Coding Agent")
    parser.add_argument("prompt", nargs="?", help="Optional initial instruction to execute")
    parser.add_argument("--yolo", "-y", action="store_true", help="Auto-approve all tool execution commands")
    parser.add_argument("--model", "-m", help="Override Ollama model name")
    parser.add_argument("--diagnose", "-d", action="store_true", help="Run system health diagnosis immediately")

    args = parser.parse_args()

    if args.diagnose:
        print(f"\n{C_CYAN}=== VIRTUAL☆PARADISE OFFLINE SYSTEM HEALTH ==={C_RESET}\n")
        print(tool_get_system_health())
        sys.exit(0)

    if args.model:
        global DEFAULT_MODEL
        DEFAULT_MODEL = args.model

    agent_loop(initial_prompt=args.prompt, yolo=args.yolo)

if __name__ == "__main__":
    main()
