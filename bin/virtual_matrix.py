#!/usr/bin/env python3
"""
Virtual☆Paradise Gradient Matrix (virtual_matrix.py)
Enhanced Matrix rain animation with continuous Tri-Color Gradient:
Miku Cyan (#00f5d4) -> Hacker Green (#00ff88) -> Sakura Pastel Pink (#ffb7d5)
Based on Unimatrix by William Mannard.
"""

import argparse
import curses
import sys
import time
from random import choice, randint

help_msg = r'''
USAGE
  virtual_matrix [-a] [-b] [-c COLOR] [-f] [-g COLOR] [-h] [-l CHARACTER_LIST] [-n]
                 [-o] [-s SPEED] [-u CUSTOM_CHARACTERS]

OPTIONAL ARGUMENTS
  -a                   Asynchronous scroll. Lines will move at varied speeds.
  -b                   Use only bold characters
  -c COLOR             gradient (default), cyan, green, magenta, red, blue, yellow, white
  -f                   Enable "flashers," characters that continuously change.
  -g COLOR             Background color
  -h                   Show this help message and exit
  -i                   Ignore keyboard
  -l CHARACTER_LIST    Select character set(s) (k: katakana, m: matrix, e: emoji, etc.)
  -n                   Do not use bold characters
  -o                   Disable on-screen status
  -s SPEED             Integer up to 100. Default=94
  -t TIME              Exit the process after TIME seconds
  -u CUSTOM_CHARACTERS Your own string of characters to display.
  -w                   Single-wave mode: single burst then exit.
'''

parser = argparse.ArgumentParser(add_help=False)
parser.add_argument('-a', '--asynchronous', action='store_true', help='use asynchronous scrolling')
parser.add_argument('-b', '--all-bold', action='store_true', help='use all bold characters')
parser.add_argument('-c', '--color', default='gradient', type=str, help='color or gradient')
parser.add_argument('-f', '--flashers', action='store_true', help='enable flashers')
parser.add_argument('-g', '--bg-color', default='default', type=str)
parser.add_argument('-h', '--help', action='store_true')
parser.add_argument('-i', '--ignore-keyboard', action='store_true')
parser.add_argument('-l', '--character-list', default='k', type=str)
parser.add_argument('-n', '--no-bold', action='store_true')
parser.add_argument('-o', '--status-off', action='store_true')
parser.add_argument('-s', '--speed', default=50, type=int)
parser.add_argument('-t', '--time', type=int)
parser.add_argument('-u', '--custom-characters', default='☆★✦✧', type=str)
parser.add_argument('-w', '--single-wave', action='store_true')

args = parser.parse_args()

if args.help:
    print(help_msg)
    sys.exit(0)

char_set = {
    'a': 'qwertyuiopasdfghjklzxcvbnm',
    'A': 'QWERTYUIOPASDFGHJKLZXCVBNM',
    'c': 'абвгдежзиклмнопрстуфхцчшщъыьэюя',
    'C': 'АБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ',
    'e': '☺☻✌♡♥❤⚘❀❃❁✼☀✌♫♪☃❄❅❆☕☂★',
    'g': 'αβγδεζηθικλμνξοπρστυφχψως',
    'G': 'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ',
    'k': 'ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ',
    'm': 'ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ1234567890-=*_+|:<>"',
    'n': '1234567890',
    'o': 'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890`-=~!@#$%^&*()_+[]{}|\\;\':",./<>?"',
    's': '-=*_+|:<>"',
    'S': r'`-=~!@#$%^&*()_+[]{}|\;\':",./<>?"',
    'u': args.custom_characters
}

chars = ''
if args.character_list:
    for letter in args.character_list:
        if letter in char_set:
            chars += char_set[letter]
if args.custom_characters:
    chars += args.custom_characters

if not chars:
    chars = char_set['k'] + '☆★✦✧'

if args.no_bold:
    args.all_bold = False

chars_len = len(chars) - 1
GRADIENT_STEPS = 32

def lerp(c1, c2, t):
    return int(c1 + (c2 - c1) * t)

def get_gradient_rgb(ratio):
    # 40% Miku Cyan -> 20% Hacker Green -> 40% Sakura Pink
    r1, g1, b1 = (0, 960, 831)      # Miku Cyan (#00f5d4)
    r2, g2, b2 = (0, 1000, 533)     # Hacker Green (#00ff88)
    r3, g3, b3 = (1000, 717, 835)   # Sakura Pink (#ffb7d5)

    if ratio <= 0.40:
        t = ratio / 0.40
        return (lerp(r1, r2, t * 0.5), lerp(g1, g2, t * 0.5), lerp(b1, b2, t * 0.5))
    elif ratio <= 0.60:
        t = (ratio - 0.40) / 0.20
        return (
            lerp(lerp(r1, r2, 0.5), r2, t),
            lerp(lerp(g1, g2, 0.5), g2, t),
            lerp(lerp(b1, b2, 0.5), b2, t),
        )
    else:
        t = (ratio - 0.60) / 0.40
        return (lerp(r2, r3, t), lerp(g2, g3, t), lerp(b2, b3, t))

class Canvas:
    def __init__(self, screen):
        screen.clear()
        rows, cols = screen.getmaxyx()
        self.col_count = cols
        self.row_count = rows
        self.size_changed = False
        self.columns = []
        for col in range(0, cols, 2):
            self.columns.append(Column(col, self.row_count, cols))
        self.nodes = []
        self.flashers = set()

        for x in range(self.row_count):
            try:
                screen.addstr(x, 0, ' ' * self.col_count, curses.color_pair(1))
            except curses.error:
                pass

class Column:
    def __init__(self, x_coord, row_count, col_count):
        self.drawing = None
        self.x_coord = x_coord
        self.timer = randint(1, max(2, row_count))
        self.async_speed = randint(1, 3)
        self.color_pair = self._calc_color_pair(x_coord, col_count)
        if args.single_wave:
            self.timer = int(0.6 * self.timer)

    def _calc_color_pair(self, x, col_count):
        if args.color != 'gradient':
            return 1
        ratio = max(0.0, min(1.0, x / max(1, col_count - 1)))
        step = int(ratio * (GRADIENT_STEPS - 1))
        # Color pairs 10 to 10 + GRADIENT_STEPS - 1
        return 10 + step

    def spawn_node(self, canvas):
        if args.single_wave and self.drawing is False:
            return
        self.drawing = not self.drawing
        mult = self.async_speed if args.asynchronous else 1

        if self.drawing:
            max_range = max((3 * mult), ((canvas.row_count - 3) * mult))
            self.timer = randint(3 * mult, max_range)
            if args.single_wave:
                self.timer = int(0.8 * self.timer)
        else:
            self.timer = randint(1 * mult, canvas.row_count * mult)

        x = self.x_coord
        n_type = 'writer' if self.drawing else 'eraser'
        white = (randint(0, 2) == 0) if self.drawing else False
        canvas.nodes.append(Node(x, n_type, self.async_speed, self.color_pair, white))

class Node:
    def __init__(self, x_coord, n_type, async_speed, color_pair, white=False):
        self.x_coord = x_coord
        self.y_coord = 0
        self.n_type = n_type
        self.color_pair = color_pair
        self.white = white
        self.last_char = None
        self.expired = False
        self.async_speed = async_speed

class Writer:
    def __init__(self, screen):
        self.screen = screen

    def get_char(self):
        return chars[randint(0, chars_len)]

    def get_attr(self, node, above=False):
        if args.no_bold:
            return curses.A_NORMAL
        elif args.all_bold:
            return curses.A_BOLD
        else:
            if node.white and not above:
                return curses.A_BOLD
            else:
                return choice([curses.A_BOLD, curses.A_NORMAL])

    def draw(self, node):
        y = node.y_coord
        x = node.x_coord
        character = ' '
        attr = self.get_attr(node)
        color = curses.color_pair(node.color_pair)

        if node.n_type == 'writer':
            if not node.white and node.last_char:
                character = node.last_char
            else:
                character = self.get_char()
            if node.white:
                color = curses.color_pair(2) # Bright White Head

        try:
            self.screen.addstr(y, x, character, color | attr)
            if node.white:
                if node.last_char:
                    attr = self.get_attr(node, above=True)
                    self.screen.addstr(y - 1, x, node.last_char, curses.color_pair(node.color_pair) | attr)
                node.last_char = character
        except curses.error:
            pass

    def draw_flasher(self, flasher, canvas):
        y, x = flasher
        ratio = max(0.0, min(1.0, x / max(1, canvas.col_count - 1)))
        step = int(ratio * (GRADIENT_STEPS - 1))
        pair = (10 + step) if args.color == 'gradient' else 1
        attr = choice([curses.A_BOLD, curses.A_NORMAL])
        try:
            self.screen.addstr(y, x, self.get_char(), curses.color_pair(pair) | attr)
        except curses.error:
            pass

def _main(screen):
    try:
        curses.curs_set(0)
    except Exception:
        pass
    screen.nodelay(True)

    if curses.has_colors():
        curses.start_color()
        try:
            curses.use_default_colors()
            bg = -1
        except Exception:
            bg = curses.COLOR_BLACK

        try:
            curses.init_pair(1, curses.COLOR_CYAN, bg)
            curses.init_pair(2, curses.COLOR_WHITE, bg)
        except Exception:
            pass

        # Initialize Gradient Color Pairs (40% Cyan -> 20% Green -> 40% Sakura Pink)
        can_change = curses.can_change_color()
        for i in range(GRADIENT_STEPS):
            pair_num = 10 + i
            ratio = i / (GRADIENT_STEPS - 1)
            if can_change and curses.COLORS >= 256:
                color_idx = 100 + i
                r, g, b = get_gradient_rgb(ratio)
                try:
                    curses.init_color(color_idx, r, g, b)
                    curses.init_pair(pair_num, color_idx, bg)
                except Exception:
                    pass
            else:
                # Fallback for standard terminals
                try:
                    if ratio <= 0.40:
                        curses.init_pair(pair_num, curses.COLOR_CYAN, bg)
                    elif ratio <= 0.60:
                        curses.init_pair(pair_num, curses.COLOR_GREEN, bg)
                    else:
                        curses.init_pair(pair_num, curses.COLOR_MAGENTA, bg)
                except Exception:
                    pass

    writer = Writer(screen)
    delay = (100 - args.speed) * 10
    wave_delay = 10 if args.single_wave else 0
    starttime = time.time()

    while True:
        canvas = Canvas(screen)
        async_clock = 5

        while not canvas.size_changed:
            if args.time and time.time() - starttime > args.time:
                sys.exit(0)

            # Keyboard handler
            if not args.ignore_keyboard:
                kp = screen.getch()
                if kp in (ord(' '), ord('q'), ord('Q'), 27):
                    sys.exit(0)
                elif kp == ord('a'):
                    args.asynchronous = not args.asynchronous
                elif kp == ord('f'):
                    args.flashers = not args.flashers
                elif kp in (ord('-'), ord('_'), curses.KEY_LEFT):
                    delay = min(delay + 10, 1000)
                elif kp in (ord('='), ord('+'), curses.KEY_RIGHT):
                    delay = max(delay - 10, 0)

            # Spawn new nodes
            for col in canvas.columns:
                if col.timer == 0:
                    col.spawn_node(canvas)
                col.timer -= 1

            for node in canvas.nodes:
                if args.flashers:
                    if node.n_type == 'writer' and not randint(0, 9):
                        canvas.flashers.add((node.y_coord, node.x_coord))
                    elif node.n_type == 'eraser':
                        canvas.flashers.discard((node.y_coord, node.x_coord))

                if args.asynchronous:
                    if async_clock % node.async_speed == 0:
                        writer.draw(node)
                        node.y_coord += 1
                else:
                    writer.draw(node)
                    node.y_coord += 1

                if node.y_coord >= canvas.row_count:
                    if node.white:
                        node.white = False
                        node.y_coord -= 1
                    else:
                        node.expired = True

            if args.flashers and (not async_clock % 3):
                for f in list(canvas.flashers):
                    writer.draw_flasher(f, canvas)

            canvas.nodes = [n for n in canvas.nodes if not n.expired]

            if args.single_wave:
                if len(canvas.nodes) == 0 and wave_delay < 0:
                    sys.exit(0)
                wave_delay -= 1

            screen.refresh()

            if screen.getmaxyx() != (canvas.row_count, canvas.col_count):
                canvas.size_changed = True

            async_clock = (async_clock + 1) % 60
            curses.napms(max(1, delay // 10))

if __name__ == '__main__':
    curses.wrapper(_main)
