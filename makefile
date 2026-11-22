# Darkstar
#
#   make          render every app's theme file
#   make check    fail if any colour is below its minimum contrast
#   make palette  print every colour with its contrast ratio
#   make install  copy the theme files into ~/.config
#   make repo     build ./repo, a test git repo with fixed dates
#   make screenshots  capture each app in Ghostty (macOS only)
#   make clean    delete the rendered theme files and ./repo
#
# Everything lives in this file: the palette, the templates for each app
# and the awk that renders them. Templates use {{name}} for a palette
# colour and {{mix a b t}} for a blend of two colours, where t is how far
# to move from a towards b.

OUTPUTS := \
	ghostty/darkstar.toml \
	helix/darkstar.toml \
	lazygit/darkstar.yml \
	opencode/darkstar.json

all: $(OUTPUTS)

ghostty/darkstar.toml: TEMPLATE = GHOSTTY
helix/darkstar.toml: TEMPLATE = HELIX
lazygit/darkstar.yml: TEMPLATE = LAZYGIT
opencode/darkstar.json: TEMPLATE = OPENCODE

$(OUTPUTS): makefile
	@mkdir -p $(@D)
	@printf '%s\n' "$$$(TEMPLATE)" | awk "$$RENDER_AWK" > $@.tmp || { rm -f $@.tmp; exit 1; }
	@mv $@.tmp $@
	@echo "  $@"

check:
	@awk -v strict=1 "$$CHECK_AWK"

palette:
	@awk -v strict=0 "$$CHECK_AWK"

install: all
	mkdir -p ~/.config/ghostty/themes ~/.config/helix/themes ~/.config/lazygit ~/.config/opencode/themes
	install -m 644 ghostty/darkstar.toml ~/.config/ghostty/themes/darkstar.toml
	install -m 644 helix/darkstar.toml ~/.config/helix/themes/darkstar.toml
	install -m 644 lazygit/darkstar.yml ~/.config/lazygit/darkstar.yml
	install -m 644 opencode/darkstar.json ~/.config/opencode/themes/darkstar.json

clean:
	rm -f $(OUTPUTS)
	rm -rf repo

# A small git repo with fixed authors, dates and contents, so the
# screenshots come out the same every time.
repo: makefile
	@sh -c "$$FIXTURE_SH"
	@echo "  $@"

SCREENSHOTS := \
	screenshots/ghostty.png \
	screenshots/helix.png \
	screenshots/lazygit.png \
	screenshots/opencode.png

screenshots: $(SCREENSHOTS)

# Every screenshot uses the same window size, in columns and rows.
SIZE := 110 32

screenshots/ghostty.png: SCENE = GHOSTTY_SCENE
screenshots/ghostty.png: TITLE = Ghostty
screenshots/ghostty.png: WAIT = 1
screenshots/ghostty.png: ghostty/darkstar.toml

screenshots/helix.png: SCENE = HELIX_SCENE
screenshots/helix.png: TITLE = Helix
screenshots/helix.png: WAIT = 2
screenshots/helix.png: ghostty/darkstar.toml helix/darkstar.toml repo

screenshots/lazygit.png: SCENE = LAZYGIT_SCENE
screenshots/lazygit.png: TITLE = Lazygit
screenshots/lazygit.png: WAIT = 3
screenshots/lazygit.png: ghostty/darkstar.toml lazygit/darkstar.yml repo

screenshots/opencode.png: SCENE = OPENCODE_SCENE
screenshots/opencode.png: TITLE = opencode
screenshots/opencode.png: WAIT = 5
screenshots/opencode.png: ghostty/darkstar.toml opencode/darkstar.json repo

$(SCREENSHOTS): makefile
	@mkdir -p $(@D)
	@sh -c "$$SCREENSHOT_SH" screenshot $@ $(SIZE) $(WAIT) "$$$(SCENE)" "$(TITLE)"
	@echo "  $@"

.PHONY: all check palette install clean screenshots

# Name, hex value and the minimum contrast ratio against the background.
# 4.5 is WCAG AA and 7 is WCAG AAA. A dash means the colour isn't used for
# text, so there's nothing to check.
define palette
background            #05181d  -
foreground            #eee8d5  7
black                 #6c838b  4.5
red                   #e9403a  4.5
green                 #859900  4.5
yellow                #b58900  4.5
blue                  #268bd2  4.5
magenta               #de428c  4.5
cyan                  #2aa198  4.5
white                 #eee8d5  7
orange                #db5231  4.5
bright_black          #8ea6ac  7
bright_red            #ff796e  7
bright_green          #83c746  7
bright_yellow         #efc541  7
bright_blue           #5da4ff  7
bright_magenta        #ff81ca  7
bright_cyan           #56d8c9  7
bright_white          #fbf0cc  7
bright_orange         #ed8649  7
cursor_color          #839496  -
cursor_text           #002b36  -
selection_background  #002b36  -
selection_foreground  #eee8d5  -
cursorline            #002b36  -
very_dark             #204a56  -
selection_primary     #234a56  -
background_two        #0b1f23  -
linenr                #475b62  -
surface               #163a44  -
surface_low           #08191e  -
endef

define common_awk
function hexdigit(d) { return index("0123456789abcdef", tolower(d)) - 1 }
function channel(c, i) { return hexdigit(substr(c, i, 1)) * 16 + hexdigit(substr(c, i + 1, 1)) }

BEGIN {
  lines = split(ENVIRON["PALETTE"], rows, "\n")
  for (i = 1; i <= lines; i++) {
    if (split(rows[i], f, " ") < 3) continue
    hexes[f[1]] = f[2]
    minimum[f[1]] = f[3]
    order[++count] = f[1]
  }
}
endef

define render_awk
function colour(name) {
  if (name ~ /^#/) return name
  if (!(name in hexes)) {
    printf "line %d: unknown colour '%s'\n", NR, name > "/dev/stderr"
    failed = 1
    exit 1
  }
  return hexes[name]
}

function mix(a, b, t,   i, x, y, out) {
  a = colour(a)
  b = colour(b)
  out = "#"
  for (i = 2; i <= 6; i += 2) {
    x = channel(a, i)
    y = channel(b, i)
    out = out sprintf("%02x", int(x + (y - x) * t + 0.5))
  }
  return out
}

{
  line = $0
  while (match(line, /\{\{[^}]*\}\}/)) {
    n = split(substr(line, RSTART + 2, RLENGTH - 4), w, " ")
    if (n == 1) value = colour(w[1])
    else if (n == 4 && w[1] == "mix") value = mix(w[2], w[3], w[4])
    else {
      printf "line %d: can't render '%s'\n", NR, substr(line, RSTART, RLENGTH) > "/dev/stderr"
      failed = 1
      exit 1
    }
    line = substr(line, 1, RSTART - 1) value substr(line, RSTART + RLENGTH)
  }
  print line
}

END { if (failed) exit 1 }
endef

define check_awk
function linear(v) {
  v /= 255
  return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4
}

function luminance(c) {
  return 0.2126 * linear(channel(c, 2)) + 0.7152 * linear(channel(c, 4)) + 0.0722 * linear(channel(c, 6))
}

function contrast(a, b,   x, y) {
  x = luminance(a) + 0.05
  y = luminance(b) + 0.05
  return x > y ? x / y : y / x
}

function rating(r) {
  if (r >= 7) return "AAA"
  if (r >= 4.5) return "AA"
  if (r >= 3) return "AA Large"
  return "Fail"
}

BEGIN {
  for (i = 1; i <= count; i++) {
    name = order[i]
    if (minimum[name] == "-") continue
    r = contrast(hexes[name], hexes["background"])
    status = ""
    if (r < minimum[name]) {
      status = "  below " minimum[name]
      failed = 1
    }
    printf "%-16s %s  %5.2f  %s%s\n", name, hexes[name], r, rating(r), status
  }
  if (strict && failed) exit 1
}
endef

define ghostty
background = {{background}}
foreground = {{foreground}}
palette = 0={{black}}
palette = 1={{red}}
palette = 2={{green}}
palette = 3={{yellow}}
palette = 4={{blue}}
palette = 5={{magenta}}
palette = 6={{cyan}}
palette = 7={{white}}
palette = 8={{bright_black}}
palette = 9={{bright_red}}
palette = 10={{bright_green}}
palette = 11={{bright_yellow}}
palette = 12={{bright_blue}}
palette = 13={{bright_magenta}}
palette = 14={{bright_cyan}}
palette = 15={{bright_white}}
cursor-color = {{cursor_color}}
cursor-text = {{cursor_text}}
selection-background = {{selection_background}}
selection-foreground = {{selection_foreground}}
endef

define lazygit
gui:
  theme:
    activeBorderColor:
      - "{{foreground}}"
      - bold
    inactiveBorderColor:
      - "{{linenr}}"
    selectedLineFgColor:
      - default
    selectedLineBgColor:
      - "{{cursorline}}"
    inactiveViewSelectedLineBgColor:
      - "{{background_two}}"
endef

define newline


endef

define helix
"attribute" = "bright_yellow"
"type" = "bright_blue"
"type.parameter" = "bright_magenta"
"type.enum.variant" = "bright_yellow"
"constructor" = "bright_yellow"
"constant" = "bright_magenta"
"constant.builtin" = "bright_magenta"
"constant.builtin.boolean" = "bright_yellow"
"constant.numeric" = "bright_blue"
"constant.character" = "bright_yellow"
"string" = "bright_green"
"string.regexp" = "bright_yellow"
"string.special" = "bright_yellow"
"comment" = { fg = "black", modifiers = ["italic"] }
"comment.block.documentation" = { fg = "bright_yellow", modifiers = ["italic"] }
"variable" = "white"
"variable.builtin" = "bright_red"
"label" = "magenta"
"punctuation" = "white"
"keyword" = "bright_red"
"keyword.directive" = "bright_orange"
"operator" = "white"
"function" = "bright_yellow"
"function.macro" = "bright_orange"
"function.builtin" = "magenta"
"tag" = "bright_magenta"
"namespace" = "white"
"namespace.mod" = "bright_blue"
"namespace.mod_type" = "magenta"
"markup.heading" = "bright_green"
"markup.list" = "bright_red"
"markup.bold" = { fg = "bright_yellow", modifiers = ["bold"] }
"markup.italic" = { fg = "bright_yellow", modifiers = ["italic"] }
"markup.strikethrough" = { modifiers = ["crossed_out"] }
"markup.link.url" = "bright_blue"
"markup.link.text" = "bright_yellow"
"markup.link.label" = "bright_magenta"
"markup.raw" = "bright_magenta"
"markup.quote" = "bright_green"
"diff.plus" = "bright_green"
"diff.minus" = "bright_red"
"diff.delta" = "bright_yellow"
"special" = "bright_orange"

"warning" = "bright_yellow"
"error" = { fg = "bright_red", modifiers = ["bold"] }
"info" = { fg = "bright_blue", modifiers = ["bold"] }
"hint" = { fg = "bright_green", modifiers = ["bold"] }
"diagnostic.hint" = { underline = { color = "bright_green", style = "curl" } }
"diagnostic.info" = { underline = { color = "bright_blue", style = "curl" } }
"diagnostic.warning" = { underline = { color = "bright_yellow", style = "curl" } }
"diagnostic.error" = { underline = { color = "bright_red", style = "curl" } }

"diagnostic.deprecated" = { modifiers = ["crossed_out"] }
"diagnostic.unnecessary" = { modifiers = ["dim"] }
"ui.background" = { fg = "white", bg = "background" }
"ui.bufferline" = { fg = "very_dark", bg = "background" }
"ui.bufferline.active" = { fg = "white", bg = "background" }
"ui.bufferline.background" = { bg = "background", fg = "red" }
"ui.cursor" = { fg = "cursor_text", bg = "cursor_color" }
"ui.cursor.match" = { bg = "background_two" }
"ui.cursor.primary" = { fg = "background", bg = "white" }
"ui.cursor.select" = { fg = "white", bg = "cyan" }
"ui.cursorline" = { bg = "very_dark" }
"ui.cursorline.primary" = { bg = "cursorline" }
"ui.cursorline.secondary" = { bg = "cursorline" }
"ui.help" = { bg = "background" }
"ui.linenr" = { fg = "linenr" }
"ui.linenr.selected" = { fg = "blue", modifiers = ["bold"] }
"ui.menu" = { fg = "white", bg = "background_two" }
"ui.menu.selected" = { fg = "white", bg = "black"}
"ui.popup" = { bg = "background_two" }
"ui.popup.info" = {fg = "white", bg = "background", modifiers = ["bold"]}
"ui.selection" = { bg = "selection_primary" }
"ui.selection.primary" = { bg = "selection_primary", modifiers=["bold"] }
"ui.statusline" = { fg = "very_dark", bg = "background" }
"ui.statusline.inactive" = { fg = "very_dark", bg = "background" }
"ui.text" = { fg = "white" }
"ui.text.focus" = { fg = "blue", bg="cursorline", modifiers = ["bold"]}
"ui.text.info" = {fg = "white", modifiers = ["bold"]}
"ui.virtual.indent-guide" = { fg = "black" }
"ui.virtual.inlay-hint" = { fg = "white", modifiers = ["italic"] }
"ui.virtual.jump-label" = { fg = "red", modifiers = ["bold"] }
"ui.virtual.ruler" = { bg = "black" }
"ui.virtual.whitespace" = { fg = "white" }
"ui.window" = { fg = "white" }

[palette]
background = "{{background}}"
foreground = "{{foreground}}"
black = "{{black}}"
red = "{{red}}"
green = "{{green}}"
yellow = "{{yellow}}"
blue = "{{blue}}"
magenta = "{{magenta}}"
cyan = "{{cyan}}"
white = "{{white}}"
bright_black = "{{bright_black}}"
bright_red = "{{bright_red}}"
bright_green = "{{bright_green}}"
bright_yellow = "{{bright_yellow}}"
bright_blue = "{{bright_blue}}"
bright_magenta = "{{bright_magenta}}"
bright_cyan = "{{bright_cyan}}"
bright_white = "{{bright_white}}"
orange = "{{orange}}"
bright_orange = "{{bright_orange}}"
cursor_color = "{{cursor_color}}"
cursor_text = "{{cursor_text}}"
selection_background = "{{selection_background}}"
selection_foreground = "{{selection_foreground}}"
cursorline = "{{cursorline}}"
very_dark = "{{very_dark}}"
selection_primary = "{{selection_primary}}"
background_two = "{{background_two}}"
linenr = "{{linenr}}"
surface = "{{surface}}"
surface_low = "{{surface_low}}"
endef


# Builds ./repo: a tiny TypeScript project with a few authors, a merged
# branch and some uncommitted changes, all with fixed dates.
define fixture_sh
set -e
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
rm -rf repo
mkdir -p repo/src repo/test
cd repo
git init -q -b main

as() {
  d="$1" n="$2" e="$3"
  shift 3
  GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" \
  GIT_AUTHOR_NAME="$n" GIT_COMMITTER_NAME="$n" \
  GIT_AUTHOR_EMAIL="$e" GIT_COMMITTER_EMAIL="$e" \
  git "$@"
}

ada="Ada Lovelace"; ada_email="ada@example.com"
grace="Grace Hopper"; grace_email="grace@example.com"
alan="Alan Turing"; alan_email="alan@example.com"

cat > readme.md <<'EOF'
# basket

A shopping basket with discount codes.
EOF
cat > package.json <<'EOF'
{
  "name": "basket",
  "version": "0.1.0",
  "type": "module"
}
EOF
git add -A
as "2024-03-01T09:12:00Z" "$ada" "$ada_email" commit -q -m "Initial commit"

cat > src/cart.ts <<'EOF'
export type Item = {
  sku: string;
  name: string;
  price: number;
  quantity: number;
};

export type Cart = {
  items: Item[];
};

export function addItem(cart: Cart, item: Item): Cart {
  return { ...cart, items: [...cart.items, item] };
}
EOF
git add -A
as "2024-03-02T10:30:00Z" "$ada" "$ada_email" commit -q -m "Add basket model"

cat >> src/cart.ts <<'EOF'

export function subtotal(cart: Cart): number {
  return cart.items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
EOF
git add -A
as "2024-03-04T14:05:00Z" "$grace" "$grace_email" commit -q -m "Calculate subtotal"

git checkout -q -b discount-codes
cat > src/discounts.ts <<'EOF'
export type Discount = {
  code: string;
  percent: number;
  expires?: Date;
};

const discounts: Record<string, Discount> = {
  SPRING24: { code: "SPRING24", percent: 10 },
  WELCOME: { code: "WELCOME", percent: 15 },
};

export function findDiscount(code: string): Discount | undefined {
  return discounts[code.trim().toUpperCase()];
}
EOF
git add -A
as "2024-03-05T11:20:00Z" "$alan" "$alan_email" commit -q -m "Add discount code lookup"

cat >> src/cart.ts <<'EOF'

/**
 * Applies a discount code to the cart's subtotal.
 * Unknown or expired codes leave the price unchanged.
 */
export function applyDiscount(cart: Cart, code: string, now = new Date()): number {
  const discount = findDiscount(code);
  if (!discount || (discount.expires && discount.expires < now)) {
    return subtotal(cart);
  }
  return Math.round(subtotal(cart) * (100 - discount.percent)) / 100;
}
EOF
{ printf 'import { findDiscount } from "./discounts";\n\n'; cat src/cart.ts; } > src/cart.tmp
mv src/cart.tmp src/cart.ts
git add -A
as "2024-03-06T16:45:00Z" "$alan" "$alan_email" commit -q -m "Apply discount codes to the subtotal"

git checkout -q main
cat > test/cart.test.ts <<'EOF'
import { strict as assert } from "node:assert";
import { addItem, subtotal } from "../src/cart";

const apple = { sku: "A1", name: "Apple", price: 0.4, quantity: 3 };

assert.equal(subtotal(addItem({ items: [] }, apple)), 1.2);
EOF
git add -A
as "2024-03-07T09:00:00Z" "$grace" "$grace_email" commit -q -m "Test the subtotal"

as "2024-03-08T13:15:00Z" "$ada" "$ada_email" merge -q --no-ff discount-codes -m "Merge branch 'discount-codes'"

sed -i.bak 's/version": "0.1.0"/version": "0.2.0"/' package.json && rm package.json.bak
git add -A
as "2024-03-09T10:40:00Z" "$ada" "$ada_email" commit -q -m "Release 0.2.0"

cat >> test/cart.test.ts <<'EOF'

assert.equal(applyDiscount({ items: [apple] }, "spring24"), 1.08);
EOF
sed -i.bak 's/import { addItem, subtotal }/import { addItem, applyDiscount, subtotal }/' test/cart.test.ts
rm test/cart.test.ts.bak
printf 'node_modules/\n' > .gitignore
endef

# Opens a Ghostty window with its own config, runs a scene in it, captures
# the window with screencapture and closes it again.
#
# Arguments: output file, columns, rows, seconds to wait, scene script and
# window title.
define screenshot_sh
set -e
out="$PWD/$1"; cols="$2"; rows="$3"; wait="$4"; scene="$5"; title="$6"
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

cat > "$dir/config" <<EOF
theme = $PWD/ghostty/darkstar.toml
title = $title
window-width = $cols
window-height = $rows
window-padding-x = 12
window-padding-y = 10
font-size = 14
cursor-style-blink = false
shell-integration = none
confirm-close-surface = false
window-save-state = never
quit-after-last-window-closed = true
macos-titlebar-style = native
EOF

{
  printf '#!/bin/sh\n'
  printf 'export PATH=%s\n' "'$PATH'"
  printf 'export DARKSTAR=%s SCENE_DIR=%s\n' "'$PWD'" "'$dir'"
  [ -n "$HELIX_RUNTIME" ] && printf 'export HELIX_RUNTIME=%s\n' "'$HELIX_RUNTIME'"
  printf 'printf "\\033[H\\033[2J"\n'
  printf '%s\n' "$scene"
} > "$dir/scene"
chmod +x "$dir/scene"

open -na Ghostty.app --args --config-default-files=false \
  --config-file="$dir/config" -e "$dir/scene"

pid=; window=
for i in $(seq 50); do
  pid=$(pgrep -f "config-file=$dir/config" | head -1)
  if [ -n "$pid" ]; then
    window=$(osascript -l JavaScript -e "$WINDOW_ID_JS" "$pid")
    [ -n "$window" ] && break
  fi
  sleep 0.2
done
if [ -z "$window" ]; then
  echo "couldn't find the Ghostty window" >&2
  [ -n "$pid" ] && kill "$pid"
  exit 1
fi

sleep "$wait"
screencapture -x -o -l "$window" "$out" || {
  echo "screencapture failed: does this terminal have Screen Recording permission?" >&2
  kill "$pid"
  exit 1
}
kill "$pid"
endef

# Prints the macOS window number of the first window belonging to a PID.
define window_id_js
ObjC.import("CoreGraphics")
function run(argv) {
  const pid = parseInt(argv[0], 10)
  const list = ObjC.castRefToObject($.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly, 0))
  const window = ObjC.deepUnwrap(list).find(w => w.kCGWindowOwnerPID === pid && w.kCGWindowLayer === 0)
  return window ? String(window.kCGWindowNumber) : ""
}
endef

define ghostty_scene
printf '\033[?25l\n'
for i in 0 1 2 3 4 5 6 7; do
  set -- black red green yellow blue magenta cyan white
  shift "$i"
  printf '  \033[3%sm%-16s\033[0m  \033[9%sm%s\033[0m\n' "$i" "$1" "$i" "bright $1"
done
printf '\n  default text  \033[1mbold\033[0m  \033[3mitalic\033[0m  \033[4munderline\033[0m\n'
printf '\n  \033[7m selected text \033[0m\n'
sleep 60
endef

define helix_scene
mkdir -p "$SCENE_DIR/xdg/helix/themes"
cp "$DARKSTAR/helix/darkstar.toml" "$SCENE_DIR/xdg/helix/themes/"
printf 'theme = "darkstar"\n' > "$SCENE_DIR/xdg/helix/config.toml"
export XDG_CONFIG_HOME="$SCENE_DIR/xdg" XDG_CACHE_HOME="$SCENE_DIR/cache"
cd "$DARKSTAR/repo"
exec hx src/cart.ts:24
endef

define lazygit_scene
mkdir -p "$SCENE_DIR/lazygit"
cat > "$SCENE_DIR/lazygit/config.yml" <<'EOF'
gui:
  nerdFontsVersion: "3"
  showRandomTip: false
git:
  branchLogCmd: git log --graph --color=always --abbrev-commit --decorate --date=short --pretty=medium {{branchName}} --
update:
  method: never
disableStartupPopups: true
EOF
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
cd "$DARKSTAR/repo"
exec lazygit -ucd "$SCENE_DIR/lazygit" \
  -ucf "$SCENE_DIR/lazygit/config.yml,$DARKSTAR/lazygit/darkstar.yml"
endef

define opencode
{
  "$schema": "https://opencode.ai/theme.json",
  "base": {
    "categorical": [
      "blue",
      "purple",
      "green",
      "orange",
      "red",
      "yellow",
      "cyan"
    ],
    "text": {
      "base": "{{foreground}}",
      "muted": "$hue.neutral.300",
      "action": {
        "primary": {
          "base": "$text.base",
          "$disabled": "$text.muted",
          "$focused": "$text.base",
          "$selected": "$hue.interactive.400"
        },
        "secondary": {
          "base": "$text.muted",
          "$hovered": "$text.base",
          "$focused": "$hue.interactive.200"
        },
        "destructive": {
          "base": "$hue.neutral.900",
          "$disabled": "$text.muted"
        }
      },
      "formfield": {
        "base": "$text.base",
        "$hovered": "$hue.interactive.400",
        "$focused": "$hue.interactive.400",
        "$pressed": "$hue.interactive.400",
        "$disabled": "$text.muted",
        "$selected": "$hue.interactive.400"
      },
      "feedback": {
        "error": {
          "base": "$hue.red.400"
        },
        "warning": {
          "base": "$hue.yellow.400"
        },
        "success": {
          "base": "$hue.green.400"
        },
        "info": {
          "base": "$hue.blue.400"
        }
      }
    },
    "background": {
      "base": "$hue.neutral.900",
      "raised": {
        "base": "$hue.neutral.700",
        "high": "$hue.neutral.600",
        "max": "$hue.neutral.500"
      },
      "action": {
        "primary": {
          "base": "transparent",
          "$hovered": "$hue.neutral.700",
          "$focused": "$hue.interactive.600",
          "$selected": "transparent"
        },
        "secondary": {
          "base": "transparent"
        },
        "destructive": {
          "base": "$hue.red.400"
        }
      },
      "formfield": {
        "base": "$background.base"
      },
      "feedback": {
        "error": {
          "base": "$background.base"
        },
        "warning": {
          "base": "$background.base"
        },
        "success": {
          "base": "$background.base"
        },
        "info": {
          "base": "$background.base"
        }
      }
    },
    "border": {
      "base": "{{very_dark}}"
    },
    "scrollbar": {
      "base": "{{linenr}}"
    },
    "diff": {
      "text": {
        "added": "{{bright_green}}",
        "removed": "{{bright_red}}",
        "context": "{{bright_black}}",
        "hunkHeader": "{{bright_black}}"
      },
      "background": {
        "added": "{{mix green background 0.82}}",
        "removed": "{{mix red background 0.82}}",
        "context": "$hue.neutral.700"
      },
      "highlight": {
        "added": "{{bright_green}}",
        "removed": "{{bright_red}}"
      },
      "lineNumber": {
        "text": "{{linenr}}",
        "background": {
          "added": "{{mix green background 0.88}}",
          "removed": "{{mix red background 0.88}}"
        }
      }
    },
    "syntax": {
      "comment": "{{black}}",
      "keyword": "{{bright_red}}",
      "function": "{{bright_yellow}}",
      "variable": "{{foreground}}",
      "string": "{{bright_green}}",
      "number": "{{bright_blue}}",
      "type": "{{bright_blue}}",
      "operator": "{{foreground}}",
      "punctuation": "{{foreground}}"
    },
    "markdown": {
      "text": "{{foreground}}",
      "heading": "{{bright_green}}",
      "link": "{{bright_blue}}",
      "linkText": "{{bright_yellow}}",
      "code": "{{bright_cyan}}",
      "blockQuote": "{{bright_green}}",
      "emphasis": "{{bright_yellow}}",
      "strong": "{{bright_yellow}}",
      "horizontalRule": "{{black}}",
      "listItem": "{{bright_red}}",
      "listEnumeration": "{{bright_red}}",
      "image": "{{bright_blue}}",
      "imageText": "{{bright_yellow}}",
      "codeBlock": "{{foreground}}"
    },
    "@dialog": {
      "background": {
        "base": "$background.raised.base",
        "action": {
          "primary": {
            "$hovered": "$background.raised.max"
          },
          "secondary": {
            "$hovered": "$background.raised.max"
          }
        }
      },
      "@footer": {
        "text": {
          "muted": "$hue.neutral.200"
        }
      }
    }
  },
  "dark": {
    "hue": {
      "red": {
        "100": "{{mix bright_red #ffffff 0.6}}",
        "200": "{{mix bright_red #ffffff 0.3}}",
        "300": "{{mix bright_red #ffffff 0.12}}",
        "400": "{{bright_red}}",
        "500": "{{red}}",
        "600": "{{mix red background 0.6}}",
        "700": "{{mix red background 0.78}}",
        "800": "{{mix red background 0.88}}",
        "900": "{{mix red background 0.95}}"
      },
      "orange": {
        "100": "{{mix bright_orange #ffffff 0.6}}",
        "200": "{{mix bright_orange #ffffff 0.3}}",
        "300": "{{mix bright_orange #ffffff 0.12}}",
        "400": "{{bright_orange}}",
        "500": "{{orange}}",
        "600": "{{mix orange background 0.6}}",
        "700": "{{mix orange background 0.78}}",
        "800": "{{mix orange background 0.88}}",
        "900": "{{mix orange background 0.95}}"
      },
      "yellow": {
        "100": "{{mix bright_yellow #ffffff 0.6}}",
        "200": "{{mix bright_yellow #ffffff 0.3}}",
        "300": "{{mix bright_yellow #ffffff 0.12}}",
        "400": "{{bright_yellow}}",
        "500": "{{yellow}}",
        "600": "{{mix yellow background 0.6}}",
        "700": "{{mix yellow background 0.78}}",
        "800": "{{mix yellow background 0.88}}",
        "900": "{{mix yellow background 0.95}}"
      },
      "green": {
        "100": "{{mix bright_green #ffffff 0.6}}",
        "200": "{{mix bright_green #ffffff 0.3}}",
        "300": "{{mix bright_green #ffffff 0.12}}",
        "400": "{{bright_green}}",
        "500": "{{green}}",
        "600": "{{mix green background 0.6}}",
        "700": "{{mix green background 0.78}}",
        "800": "{{mix green background 0.88}}",
        "900": "{{mix green background 0.95}}"
      },
      "cyan": {
        "100": "{{mix bright_cyan #ffffff 0.6}}",
        "200": "{{mix bright_cyan #ffffff 0.3}}",
        "300": "{{mix bright_cyan #ffffff 0.12}}",
        "400": "{{bright_cyan}}",
        "500": "{{cyan}}",
        "600": "{{mix cyan background 0.6}}",
        "700": "{{mix cyan background 0.78}}",
        "800": "{{mix cyan background 0.88}}",
        "900": "{{mix cyan background 0.95}}"
      },
      "blue": {
        "100": "{{mix bright_blue #ffffff 0.6}}",
        "200": "{{mix bright_blue #ffffff 0.3}}",
        "300": "{{mix bright_blue #ffffff 0.12}}",
        "400": "{{bright_blue}}",
        "500": "{{blue}}",
        "600": "{{mix blue background 0.6}}",
        "700": "{{mix blue background 0.78}}",
        "800": "{{mix blue background 0.88}}",
        "900": "{{mix blue background 0.95}}"
      },
      "purple": {
        "100": "{{mix bright_magenta #ffffff 0.6}}",
        "200": "{{mix bright_magenta #ffffff 0.3}}",
        "300": "{{mix bright_magenta #ffffff 0.12}}",
        "400": "{{bright_magenta}}",
        "500": "{{magenta}}",
        "600": "{{mix magenta background 0.6}}",
        "700": "{{mix magenta background 0.78}}",
        "800": "{{mix magenta background 0.88}}",
        "900": "{{mix magenta background 0.95}}"
      },
      "gray": {
        "100": "{{bright_white}}",
        "200": "{{foreground}}",
        "300": "{{bright_black}}",
        "400": "{{linenr}}",
        "500": "{{selection_primary}}",
        "600": "{{surface}}",
        "700": "{{background_two}}",
        "800": "{{surface_low}}",
        "900": "{{background}}"
      },
      "accent": "$hue.blue",
      "interactive": "$hue.blue",
      "neutral": "$hue.gray"
    }
  }
}
endef


define opencode_scene
mkdir -p "$SCENE_DIR/xdg/opencode/themes"
cp "$DARKSTAR/opencode/darkstar.json" "$SCENE_DIR/xdg/opencode/themes/"
cat > "$SCENE_DIR/xdg/opencode/cli.json" <<'JSON'
{
  "theme": { "name": "darkstar" },
  "animations": false
}
JSON
export XDG_CONFIG_HOME="$SCENE_DIR/xdg" XDG_DATA_HOME="$SCENE_DIR/data"
export XDG_STATE_HOME="$SCENE_DIR/state" XDG_CACHE_HOME="$SCENE_DIR/cache"
export OPENCODE_DISABLE_AUTOUPDATE=1
cd "$DARKSTAR/repo"
exec opencode --standalone
endef

export PALETTE := $(value palette)
export RENDER_AWK := $(value common_awk)$(newline)$(value render_awk)
export CHECK_AWK := $(value common_awk)$(newline)$(value check_awk)
export GHOSTTY := $(value ghostty)
export HELIX := $(value helix)
export LAZYGIT := $(value lazygit)
export FIXTURE_SH := $(value fixture_sh)
export SCREENSHOT_SH := $(value screenshot_sh)
export WINDOW_ID_JS := $(value window_id_js)
export GHOSTTY_SCENE := $(value ghostty_scene)
export HELIX_SCENE := $(value helix_scene)
export LAZYGIT_SCENE := $(value lazygit_scene)
export OPENCODE := $(value opencode)
export OPENCODE_SCENE := $(value opencode_scene)
