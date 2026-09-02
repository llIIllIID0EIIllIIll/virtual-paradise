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
import re
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

def build_system_prompt() -> str:
    # 1. Omarchy active theme
    theme = "Virtual Paradise"
    try:
        p = os.path.expanduser("~/.config/omarchy/current/theme.name")
        if os.path.exists(p):
            with open(p) as f:
                t = f.read().strip()
                if t:
                    theme = t
    except Exception:
        pass

    # 2. Installed themes
    themes_list = []
    try:
        out = subprocess.check_output(["omarchy", "theme", "list"], text=True, timeout=2).strip()
        if out:
            themes_list = [line.strip() for line in out.split("\n") if line.strip()]
    except Exception:
        pass

    # 3. Wallpaper
    wallpaper = "Miku_live.mp4"
    try:
        out = subprocess.check_output(["pgrep", "-a", "mpvpaper"], text=True, timeout=2).strip()
        if out:
            wallpaper = os.path.basename(out.split()[-1])
    except Exception:
        pass

    user = os.environ.get("USER", "doe")
    shell = os.environ.get("SHELL", "/usr/bin/zsh")
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "Hyprland")

    return f"""You are Paradise Agent, an autonomous, highly skilled Linux system diagnostic and repair AI assistant operating LOCALLY and OFFLINE on Arch Linux with Hyprland and Omarchy.

[LIVE SYSTEM STATE & ENVIRONMENT]:
- Operating System: Arch Linux (rolling release, kernel Linux 6.x)
- Window Manager / Compositor: {desktop} (Wayland)
- Active Omarchy Theme: "{theme}" (Theme phong cách Cyberpunk / Vocaloid Hatsune Miku đặc trưng: 40% Cyan #00f5d4, 20% Green #00ff88, 40% Sakura Pink #ffb7d5)
- Installed Themes Available: {', '.join(themes_list[:10])}...
- Active Wallpaper: {wallpaper} (Live video wallpaper via mpvpaper)
- Current User: {user}
- Current Shell: {shell} (Zsh)
- Default Terminal: Ghostty (chạy qua wrapper ~/.local/bin/omarchy-launch-terminal để kích hoạt Zsh)

[STANDARD DESKTOP SHORTCUTS]:
- Mở Terminal: SUPER + RETURN
- Mở Quản lý tệp (File Manager Nautilus): SUPER + E
- Mở Trình duyệt Web (Firefox): SUPER + B
- Mở Menu ứng dụng (Launcher): SUPER + SPACE hoặc SUPER + D
- Đóng cửa sổ: SUPER + Q
- Menu hệ thống Omarchy: SUPER + M
- Chụp ảnh màn hình: PRINT hoặc SUPER + SHIFT + S

[OMARCHY CORE COMMANDS]:
- Xem theme hiện tại: `omarchy theme current`
- Liệt kê tất cả theme: `omarchy theme list`
- Đổi sang theme khác: `omarchy theme set <Tên_Theme>`
- Đổi hình nền: `omarchy menu background`
- Cập nhật hệ thống: `omarchy update`

Guidelines:
- CRITICAL: When the user asks what theme, wallpaper, shell, or terminal they are using, answer IMMEDIATELY, ACCURATELY, and DIRECTLY from [LIVE SYSTEM STATE & ENVIRONMENT]! Specifically, their active theme is "{theme}".
- For greetings (e.g. "xin chào", "hello", "hi", "bạn là ai"), casual conversation, or general questions asking about shortcuts/usage, DO NOT call any tools. Reply directly, politely, and warmly in Vietnamese.
- ONLY call tools when the user asks to check live dynamic system telemetry (pin, ram, ổ cứng, lag, nhiệt độ), diagnose errors, read/write files, or run system actions.
- When a user reports a problem or asks about performance, call `get_system_health` first.
- Be concise, professional, friendly, and speak natural Vietnamese.
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
            "description": "Get an immediate status snapshot of CPU, RAM, Disk usage, Battery percentage & charging status, Top resource-consuming processes, Failed systemd services, and Network interfaces. Call this first whenever the user asks about system status, battery, free disk space, or why the computer is slow/laggy.",
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

    # 5. Battery & Power
    try:
        import glob
        bat_info = []
        for b in glob.glob("/sys/class/power_supply/*"):
            name = os.path.basename(b)
            cap_file = os.path.join(b, "capacity")
            stat_file = os.path.join(b, "status")
            if os.path.exists(cap_file) and os.path.exists(stat_file):
                with open(cap_file) as f1, open(stat_file) as f2:
                    bat_info.append(f"{name}: {f1.read().strip()}% ({f2.read().strip()})")
        if bat_info:
            parts.append(f"=== BATTERY & POWER ===\n" + "\n".join(bat_info))
    except Exception:
        pass

    # 6. Top Processes by RAM & CPU
    try:
        top_proc = subprocess.check_output(
            ["ps", "-eo", "pid,comm,%cpu,%mem", "--sort=-%mem"],
            text=True
        ).strip()
        lines = top_proc.split("\n")[:6]
        parts.append(f"=== TOP PROCESSES BY MEMORY ===\n" + "\n".join(lines))
    except Exception:
        pass

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

def call_ollama_chat(messages: List[Dict[str, Any]], model: str, enable_tools: bool = True) -> Dict[str, Any]:
    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {
            "temperature": 0.2,
            "num_ctx": 8192
        }
    }
    if enable_tools:
        payload["tools"] = TOOLS_SPEC

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{OLLAMA_HOST}/api/chat",
        data=data,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        return json.loads(resp.read().decode("utf-8"))

def get_banner_art() -> str:
    raw_lines = [
        "██╗   ██╗██╗██████╗ ████████╗██╗   ██╗ █████╗ ██╗         ██████╗  █████╗ ██████╗  █████╗ ██████╗ ██╗███████╗███████╗",
        "██║   ██║██║██╔══██╗╚══██╔══╝██║   ██║██╔══██╗██║         ██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██║██╔════╝██╔════╝",
        "██║   ██║██║██████╔╝   ██║   ██║   ██║███████║██║         ██████╔╝███████║██████╔╝███████║██║  ██║██║███████╗█████╗  ",
        "╚██╗ ██╔╝██║██╔══██╗   ██║   ██║   ██║██╔══██║██║         ██╔═══╝ ██╔══██║██╔══██╗██╔══██║██║  ██║██║╚════██║██╔══╝  ",
        " ╚████╔╝ ██║██║  ██║   ██║   ╚██████╔╝██║  ██║███████╗    ██║     ██║  ██║██║  ██║██║  ██║██████╔╝██║███████║███████╗",
        "  ╚═══╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚═╝╚══════╝╚══════╝"
    ]
    # Signature Virtual☆Paradise 40/20/40 Palette:
    # 40% Miku Cyan (#00f5d4) -> 20% Cyber Green (#00ff88) -> 40% Sakura Pink (#ffb7d5)
    c_cyan  = (0, 245, 212)
    c_green = (0, 255, 136)
    c_pink  = (255, 183, 213)

    h = len(raw_lines)
    w = max(len(l) for l in raw_lines)
    alpha = 2.0

    def lerp(c1, c2, p):
        p = max(0.0, min(1.0, p))
        return (
            int(c1[0] + (c2[0] - c1[0]) * p),
            int(c1[1] + (c2[1] - c1[1]) * p),
            int(c1[2] + (c2[2] - c1[2]) * p)
        )

    formatted_banner = []
    for r, line in enumerate(raw_lines):
        out = []
        for c, char in enumerate(line):
            if char == ' ':
                out.append(' ')
                continue
            t = (c + alpha * r) / (w + alpha * (h - 1))
            t = max(0.0, min(1.0, t))
            
            # True visual 40% Cyan / 20% Green / 40% Sakura Pink (Expanded Green band)
            if t < 0.28:
                red, green, blue = c_cyan
            elif t < 0.38:
                red, green, blue = lerp(c_cyan, c_green, (t - 0.28) / 0.10)
            elif t < 0.62:
                red, green, blue = c_green
            elif t < 0.72:
                red, green, blue = lerp(c_green, c_pink, (t - 0.62) / 0.10)
            else:
                red, green, blue = c_pink

            out.append(f"\033[38;2;{red};{green};{blue}m{char}\033[0m")
        formatted_banner.append("  " + "".join(out))
    return "\n".join(formatted_banner)

def print_banner(model_name: str):
    banner_text = get_banner_art()
    banner = f"""
{banner_text}

  {C_PINK}⚡ Virtual☆Paradise Local Diagnostic & Coding Agent{C_RESET}
  {C_GRAY}Model:{C_RESET} {C_GREEN}{model_name}{C_RESET} {C_GRAY}| Mode:{C_RESET} {C_PURPLE}Pure Offline (100% Local){C_RESET}
  {C_GRAY}Type {C_YELLOW}/help{C_GRAY} for options or {C_YELLOW}/exit{C_GRAY} to quit.{C_RESET}
  ---------------------------------------------------------------------------------------------------------------"""
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
        {"role": "system", "content": build_system_prompt()}
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
                messages = [{"role": "system", "content": build_system_prompt()}]
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
            res = call_ollama_chat(messages, model, enable_tools=(step == 1))
        except Exception as e:
            print(f"\n{C_RED}[Model Error]: {e}{C_RESET}")
            break

        msg = res.get("message", {})
        content = msg.get("content", "")
        tool_calls = msg.get("tool_calls", [])

        # Clear thinking line
        print(" " * 40, end="\r")

        # Fallback: Parse inline JSON or text tool calls emitted directly in content
        if not tool_calls and content:
            trimmed = content.strip()
            if "```json" in trimmed:
                try:
                    trimmed = trimmed.split("```json")[1].split("```")[0].strip()
                except Exception:
                    pass
            elif "```" in trimmed:
                try:
                    trimmed = trimmed.split("```")[1].split("```")[0].strip()
                except Exception:
                    pass

            if trimmed.startswith("{") and "name" in trimmed:
                try:
                    parsed = json.loads(trimmed)
                    raw_name = str(parsed.get("name", "")).strip()
                    raw_args = parsed.get("arguments") or parsed.get("parameters", {})
                    if raw_name in ("get_system_health", "execute_bash", "read_file", "write_file"):
                        tool_calls = [{"function": {"name": raw_name, "arguments": raw_args}}]
                        content = ""
                    elif raw_name:
                        tool_calls = [{"function": {"name": "execute_bash", "arguments": {"command": raw_name}}}]
                        content = ""
                except Exception:
                    pass

            if not tool_calls:
                m = re.search(r'[\"\']?name[\"\']?\s*[:=]\s*[\"\']?([a-zA-Z0-9_ -]+)[\"\']?', trimmed)
                if m:
                    candidate = m.group(1).strip()
                    if candidate in ("get_system_health", "execute_bash", "read_file", "write_file"):
                        tool_calls = [{"function": {"name": candidate, "arguments": {}}}]
                        content = ""
                    elif candidate.startswith(("omarchy", "cat", "ls", "ps", "ip", "systemctl")):
                        tool_calls = [{"function": {"name": "execute_bash", "arguments": {"command": candidate}}}]
                        content = ""
                elif "get_system_health" in trimmed and len(trimmed) < 45:
                    tool_calls = [{"function": {"name": "get_system_health", "arguments": {}}}]
                    content = ""

        if not msg.get("tool_calls") and tool_calls:
            msg["tool_calls"] = tool_calls
            msg["content"] = ""

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
                "name": fn_name,
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
