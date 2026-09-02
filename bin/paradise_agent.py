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

SKILL_DIRS = [
    os.path.expanduser("~/.agents/skills"),
    os.path.expanduser("~/.gemini/antigravity-cli/skills"),
    os.path.expanduser("~/.gemini/antigravity-cli/builtin/skills"),
    "/usr/share/omarchy/default/agents/skills"
]

def discover_skills() -> Dict[str, Dict[str, str]]:
    skills = {}
    for base in SKILL_DIRS:
        if not os.path.exists(base):
            continue
        try:
            items = sorted(os.listdir(base))
        except Exception:
            continue
        for item in items:
            skill_path = os.path.join(base, item, "SKILL.md")
            if os.path.isfile(skill_path) and item not in skills:
                desc = ""
                try:
                    with open(skill_path, "r", encoding="utf-8", errors="replace") as f:
                        content = f.read()
                    if content.startswith("---"):
                        parts = content.split("---", 2)
                        if len(parts) >= 3:
                            for line in parts[1].split("\n"):
                                if line.strip().startswith("description:"):
                                    desc = line.split("description:", 1)[1].strip(" >-\t\r\n")
                                elif desc and (line.startswith("  ") or line.startswith("\t")):
                                    desc += " " + line.strip()
                    if not desc:
                        desc = f"Specialized expert instructions for {item}"
                except Exception:
                    desc = f"Specialized expert instructions for {item}"
                skills[item] = {
                    "name": item,
                    "path": skill_path,
                    "dir": os.path.join(base, item),
                    "description": desc.strip()
                }
    return skills

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

    # 4. Formulate skills catalog
    skills_map = discover_skills()
    skills_lines = []
    for k in sorted(skills_map.keys()):
        v = skills_map[k]
        desc_first = v["description"].split(".")[0].strip(" >-\t\r\n")
        skills_lines.append(f"- `{k}`: {desc_first[:90]}.")
    skills_catalog = "\n".join(skills_lines)

    return f"""You are Paradise Agent, an autonomous, highly skilled Linux system diagnostic and repair AI assistant operating LOCALLY and OFFLINE on Arch Linux with Hyprland and Omarchy.

[LIVE SYSTEM STATE & ENVIRONMENT]:
- Operating System: Arch Linux (rolling release, kernel Linux 6.x)
- Window Manager / Compositor: {desktop} (Wayland)
- Active Omarchy Theme: "{theme}" (Theme phong cách Cyberpunk / Vocaloid Hatsune Miku đặc trưng: 40% Cyan #00f5d4, 20% Green #00ff88, 40% Sakura Pink #ffb7d5)
- Active Wallpaper: {wallpaper} (Live video wallpaper via mpvpaper)
- Current User: {user}
- Current Shell: {shell} (Zsh)
- Default Terminal: Ghostty (chạy qua wrapper ~/.local/bin/omarchy-launch-terminal để kích hoạt Zsh)

[KEY LOCAL SYSTEM PATHS]:
- User Home: /home/{user}
- Theme & Dotfiles Repository: /home/{user}/omarchy-virtual-paradise (chứa config Hyprland, Waybar, Fastfetch, Ghostty, Alacritty, wallpapers, scripts)
- Windows Shared Directory: /home/{user}/Windows (chứa dữ liệu Windows, file .bat, scripts)
- Configs: ~/.config/hypr/, ~/.config/omarchy/

[SPECIALIZED EXPERT SKILLS]:
You have access to specialized skills on this machine. Call `load_skill(skill_name)` when relevant:
{skills_catalog}

[STANDARD DESKTOP SHORTCUTS]:
- Mở Terminal: SUPER + RETURN
- Mở Quản lý tệp (Nautilus): SUPER + E
- Mở Trình duyệt (Firefox): SUPER + B
- Mở Menu ứng dụng: SUPER + SPACE hoặc SUPER + D
- Đóng cửa sổ: SUPER + Q
- Menu Omarchy: SUPER + M
- Chụp ảnh màn hình: PRINT hoặc SUPER + SHIFT + S

Guidelines:
- PROACTIVE AGENT BEHAVIOR - NEVER REFUSE OR ASK USER TO RUN COMMANDS:
  * You are an autonomous agent equipped with local tools (`execute_bash`, `read_file`, `write_file`, `load_skill`, `get_system_health`).
  * NEVER say "Tôi không thể truy cập", "Tôi không có quyền truy cập", or tell the user to open a terminal and run commands themselves!
  * You have DIRECT local access. RUN THE COMMANDS AUTONOMOUSLY to answer the user!
- FILESYSTEM & DIRECTORIES (WINDOW / OMARCHY / HOME):
  * When the user asks about files or what is inside a folder/environment (e.g. "hiện tại trong môi trường window mình những file có gì", "trong mục omarchy-virtual-paradise có gì", "trong thư mục X có file gì"):
    IMMEDIATELY CALL `execute_bash(command="ls -la /home/{user}/Windows")` or `execute_bash(command="ls -la /home/{user}/omarchy-virtual-paradise")` or `read_file`!
    Never guess or make up files! Read the directory listing and report the actual files found.
- SYSTEM TELEMETRY & HARDWARE:
  * When asked about performance, lag, battery, RAM, CPU, or services, call `get_system_health`.
- SPECIALIZED SKILLS:
  * When asked about Omarchy/Hyprland customization, call `load_skill("omarchy")`.
  * When asked about an app crash or segfault, call `load_skill("diagnose-crash")`.
- CONVERSATION & GREETINGS:
  * For simple greetings ("xin chào", "hello", "hi") or theme questions ("theme mình là gì"), answer directly in Vietnamese without tools. Theme is "{theme}".
- OUTPUT FORMAT:
  * Speak natural, polite, and helpful Vietnamese.
"""

TOOLS_SPEC = [
    {
        "type": "function",
        "function": {
            "name": "execute_bash",
            "description": "Execute a bash shell command to inspect files, check system status, or run actions. Example: 'ls -la /home/doe/Windows'",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "The command string to run in bash (e.g. 'ls -la /home/doe/Windows')."
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
            "description": "Read file contents or list all files inside a directory. Path can be a file or directory path.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "File or directory path (e.g. '/home/doe/Windows' or '~/.config/hypr/hyprland.conf')."
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
    },
    {
        "type": "function",
        "function": {
            "name": "load_skill",
            "description": "Load comprehensive instructions and expert procedures for a specialized skill (e.g. 'omarchy', 'diagnose-crash', 'agy-customizations', 'antigravity_guide'). Call this when asked to customize desktop/Hyprland, diagnose an application crash, or follow expert system workflows.",
            "parameters": {
                "type": "object",
                "properties": {
                    "skill_name": {
                        "type": "string",
                        "description": "Name of the skill to load (e.g. 'omarchy', 'diagnose-crash', 'agy-customizations')."
                    }
                },
                "required": ["skill_name"]
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

def unwrap_tool_arg(val: Any) -> Any:
    """Unwrap schema-wrapped dictionaries or malformed arguments emitted by small models."""
    if isinstance(val, dict):
        for key in ("command", "path", "skill_name", "description", "value", "input", "content"):
            if key in val and isinstance(val[key], (str, int, float, list)):
                return unwrap_tool_arg(val[key])
        for k, v in val.items():
            if k not in ("type", "description", "properties", "required"):
                return unwrap_tool_arg(v)
        if "description" in val:
            return val["description"]
        return str(val)
    return val

def tool_execute_bash(command: Any, yolo: bool = False) -> str:
    command = str(unwrap_tool_arg(command)).strip()
    if not command:
        return "[Error: Empty bash command provided]"

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

def tool_read_file(path: Any, max_lines: int = 200) -> str:
    path = str(unwrap_tool_arg(path)).strip()
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

def tool_write_file(path: Any, content: Any) -> str:
    path = str(unwrap_tool_arg(path)).strip()
    content = str(unwrap_tool_arg(content))
    expanded_path = os.path.expanduser(path)
    try:
        os.makedirs(os.path.dirname(os.path.abspath(expanded_path)), exist_ok=True)
        with open(expanded_path, "w", encoding="utf-8") as f:
            f.write(content)
        return f"[File '{path}' written successfully ({len(content)} bytes)]"
    except Exception as e:
        return f"[Error writing file: {e}]"

def tool_load_skill(skill_name: Any) -> str:
    skill_name = str(unwrap_tool_arg(skill_name)).strip()
    skills = discover_skills()
    normalized = skill_name.lower().replace("_", "-").strip()
    matched = None
    for k, v in skills.items():
        if k.lower().replace("_", "-").strip() == normalized:
            matched = v
            break
    if not matched:
        for k, v in skills.items():
            if normalized in k.lower() or k.lower() in normalized:
                matched = v
                break
    if not matched:
        return f"[Error: Skill '{skill_name}' not found. Available skills: {', '.join(skills.keys())}]"

    try:
        with open(matched["path"], "r", encoding="utf-8", errors="replace") as f:
            content = f.read()

        # Strip YAML frontmatter cleanly
        lines = content.split("\n")
        filtered_lines = []
        in_frontmatter = False
        frontmatter_done = False
        for line in lines:
            if line.strip() == "---":
                if not in_frontmatter and not frontmatter_done:
                    in_frontmatter = True
                    continue
                elif in_frontmatter:
                    in_frontmatter = False
                    frontmatter_done = True
                    continue
            if not in_frontmatter:
                filtered_lines.append(line)

        body = "\n".join(filtered_lines).strip()
        pruned = body[:1800]
        if len(body) > 1800:
            pruned += f"\n... [Skill has {len(body) - 1800} more bytes. Read '{matched['path']}' if specific details needed]"

        subfiles = []
        try:
            for f_name in os.listdir(matched["dir"]):
                if f_name.endswith(".md") and f_name != "SKILL.md":
                    subfiles.append(f_name)
        except Exception:
            pass

        extra_note = ""
        if subfiles:
            extra_note = f"\n[Guides: {', '.join(subfiles)}]"

        return f"=== LOADED SKILL: {matched['name']} ===\n{pruned}\n{extra_note}"
    except Exception as e:
        return f"[Error loading skill '{skill_name}': {e}]"

def call_ollama_chat(messages: List[Dict[str, Any]], model: str, enable_tools: bool = True) -> Dict[str, Any]:
    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {
            "temperature": 0.2,
            "num_ctx": 4096
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
    with urllib.request.urlopen(req, timeout=240) as resp:
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
  {C_YELLOW}/skills{C_RESET}     - List all specialized skills available to the agent
  {C_YELLOW}/health{C_RESET}     - Run immediate diagnostic health check (RAM, Disk, Network, Services)
  {C_YELLOW}/clear{C_RESET}      - Clear conversation history
  {C_YELLOW}/model{C_RESET}      - Show active local model
  {C_YELLOW}/help{C_RESET}       - Show this help message
  {C_YELLOW}/exit{C_RESET}       - Exit agent
""")
                continue
            elif cmd in ("/skills", "/skill"):
                skills_map = discover_skills()
                print(f"\n{C_PINK}{C_BOLD}=== AVAILABLE SPECIALIZED EXPERT SKILLS ({len(skills_map)} skills) ==={C_RESET}\n")
                for k, v in skills_map.items():
                    print(f"  {C_CYAN}• {k}{C_RESET} {C_GRAY}({v['path']}){C_RESET}")
                    print(f"    {v['description'][:140]}...\n")
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
                    if raw_name in ("get_system_health", "execute_bash", "read_file", "write_file", "load_skill"):
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
                    if candidate in ("get_system_health", "execute_bash", "read_file", "write_file", "load_skill"):
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
            fn_name = str(fn.get("name", "")).strip()
            fn_args = fn.get("arguments", {})
            if isinstance(fn_args, str):
                try:
                    fn_args = json.loads(fn_args)
                except Exception:
                    pass
            if not isinstance(fn_args, dict):
                fn_args = {"command": str(fn_args)}

            # Clean and unwrap all schema-wrapped arguments
            clean_args = {}
            for k, v in fn_args.items():
                clean_args[k] = unwrap_tool_arg(v)
            fn_args = clean_args

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
            elif fn_name == "load_skill":
                s_name = fn_args.get("skill_name", "")
                tool_output = tool_load_skill(s_name)
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
