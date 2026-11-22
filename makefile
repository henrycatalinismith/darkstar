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
# Everything lives in this file: the palettes, the templates for each app
# and the awk that renders them. Templates use {{red}} and so on for a
# palette colour and {{mix a b t}} for a blend of two colours, where t is how far
# to move from a towards b. Each theme gets its own copy of every file,
# rendered from the same templates with that theme's palette.
#
# Design goals:
#
#   1. Every colour is readable as text
#
#      Every colour reaches at least WCAG AA against the background. This is
#      a departure from Solarized which defines several colours that it intends
#      as background colours despite the reality that terminal software authors
#      use all palette colours as foreground colours in practice. Solarized is
#      broken in many real-life workloads as a result of this and patching this
#      problem is the original inspiration for creating Darkstar.
#
#   2. Real bright variants
#
#      Every colour has a "bright" variant which is a brighter version of
#      itself rather than a grey. Solarized reuses its greys for many of the
#      bright variants which leads to confusing outcomes in terminal software
#      that expects e.g. "bright blue" to actually be blue and patching this
#      issue is one of the other original goals that led to the creation of
#      Darkstar.
#
#   3. Feel like Solarized
#,
#      Solarized is an absolutely legendary colour palette and its hues carry
#      nostalgic connotations of home for many people. The third but by no
#      means least important design pillar of Darkstar is that achieving the
#      two design goals above must be balanced with preserving Solarized's hues
#      in the accent colours to the maximum possible extent because otherwise
#      the entire endeavour is meaningless.
#
# Design tradeoffs:
#
#   1. The light palette's accent colours differ from dark mode's
#
#      Reusing the same exact foreground accent colours in both dark and light
#      mode is a very impressive technical achievement in Solarized. Darkstar
#      prioritises usability over preserving this very cool symmetry.
#
#   2. The light themes don't use the same accent colours as the dark themes
#
#      Yellow on white is very difficult. Accessible contrast ratios are not
#      really achievable for this colour pair, which is a huge shame because the
#      Solarized yellow accent colour looks fantastic and really pops against
#      the dark mode background. Instead of attempting to mirror the colours
#      perfectly and use yellow in all the same places in both modes, we
#      replace it with other colours in light mode and let colours play to
#      their strengths rather than botch accessibility in the name of symmetry.
#
#   3. Higher contrast
#
#      Solarized has relatively low contrast between the foreground and
#      background colours. This has upsides for some people as certain kinds
#      of visual impairment make bright foreground colours on dark backgrounds
#      difficult to read. Darkstar trades away that niche accessibility win in
#      exchange for better baseline contrast accessibility across the board.
 
THEMES := darkstar lightstar

OUTPUTS := \
	$(THEMES:%=ghostty/%.toml) \
	$(THEMES:%=helix/%.toml) \
	$(THEMES:%=lazygit/%.yml) \
	$(THEMES:%=nvim/colors/%.lua) \
	$(THEMES:%=zellij/%.kdl) \
	$(THEMES:%=zed/%.json) \
	vscode/package.json \
	$(THEMES:%=vscode/%-color-theme.json)

all: $(OUTPUTS) opencode/darkstar.json

ghostty/%.toml: TEMPLATE = GHOSTTY
helix/%.toml: TEMPLATE = HELIX
lazygit/%.yml: TEMPLATE = LAZYGIT
nvim/colors/%.lua: TEMPLATE = NVIM
zellij/%.kdl: TEMPLATE = ZELLIJ
zed/%.json: TEMPLATE = ZED
vscode/package.json: TEMPLATE = VSCODE_PACKAGE
vscode/%-color-theme.json: TEMPLATE = VSCODE_THEME

# The theme is the first word of the file name, e.g. lightstar in
# vscode/lightstar-color-theme.json.
theme = $(firstword $(subst -, ,$(basename $(notdir $@))))

$(OUTPUTS): makefile
	@mkdir -p $(@D)
	@printf '%s\n' "$$$(TEMPLATE)" | PALETTE="$$PALETTE_$(theme)" awk "$$RENDER_AWK" > $@.tmp || { rm -f $@.tmp; exit 1; }
	@mv $@.tmp $@
	@echo "  $@"

# OpenCode themes hold a light and a dark mode in one file, so this one
# combines Darkstar's palette as the dark mode and Lightstar's as the light.
opencode/darkstar.json: makefile
	@mkdir -p $(@D)
	@{ printf '%s\n' "$$OPENCODE"; \
		printf '%s\n' "$$OPENCODE_MODE" | PALETTE="$$PALETTE_darkstar" awk "$$RENDER_AWK" && echo ','; \
		printf '%s\n' "$$OPENCODE_MODE" | PALETTE="$$PALETTE_lightstar" awk "$$RENDER_AWK" && echo '}'; \
	} > $@.tmp || { rm -f $@.tmp; exit 1; }
	@mv $@.tmp $@
	@echo "  $@"

check:
	@for t in $(THEMES); do echo "$$t"; PALETTE=$$(printenv "PALETTE_$$t") awk -v strict=1 "$$CHECK_AWK" || exit 1; done

palette:
	@for t in $(THEMES); do echo "$$t"; PALETTE=$$(printenv "PALETTE_$$t") awk -v strict=0 "$$CHECK_AWK"; done

VSCODE_EXTENSION := ~/.vscode/extensions/henrycatalinismith.darkstar-0.1.0

install: all
	mkdir -p ~/.config/ghostty/themes ~/.config/helix/themes ~/.config/lazygit ~/.config/nvim/colors ~/.config/opencode/themes ~/.config/zellij/themes ~/.config/zed/themes $(VSCODE_EXTENSION)
	for t in $(THEMES); do \
		install -m 644 ghostty/$$t.toml ~/.config/ghostty/themes/$$t.toml && \
		install -m 644 helix/$$t.toml ~/.config/helix/themes/$$t.toml && \
		install -m 644 lazygit/$$t.yml ~/.config/lazygit/$$t.yml && \
		install -m 644 nvim/colors/$$t.lua ~/.config/nvim/colors/$$t.lua && \
		install -m 644 zellij/$$t.kdl ~/.config/zellij/themes/$$t.kdl && \
		install -m 644 zed/$$t.json ~/.config/zed/themes/$$t.json && \
		install -m 644 vscode/$$t-color-theme.json $(VSCODE_EXTENSION)/$$t-color-theme.json || exit 1; \
	done
	install -m 644 opencode/darkstar.json ~/.config/opencode/themes/darkstar.json
	install -m 644 vscode/package.json $(VSCODE_EXTENSION)/package.json

clean:
	rm -f $(OUTPUTS) opencode/darkstar.json
	rm -rf repo

# A small git repo with fixed authors, dates and contents, so the
# screenshots come out the same every time.
repo: makefile
	@sh -c "$$FIXTURE_SH"
	@echo "  $@"

# Screenshots go in screenshots/<theme>/<app>.png.
SCREENSHOTS := $(foreach t,$(THEMES),$(foreach a,ghostty helix lazygit nvim opencode zellij zed vscode,screenshots/$(t)/$(a).png))

screenshots: $(SCREENSHOTS)

# Every screenshot uses the same window size, in columns and rows.
SIZE := 110 32

define terminal_screenshot
@mkdir -p $(@D)
@THEME=$* sh -c "$$SCREENSHOT_SH" screenshot $@ $(SIZE) $(WAIT) "$$$(SCENE)" "$(TITLE)"
@echo "  $@"
endef

screenshots/%/ghostty.png: SCENE = GHOSTTY_SCENE
screenshots/%/ghostty.png: TITLE = Ghostty
screenshots/%/ghostty.png: WAIT = 1
screenshots/%/ghostty.png: ghostty/%.toml makefile
	$(terminal_screenshot)

screenshots/%/helix.png: SCENE = HELIX_SCENE
screenshots/%/helix.png: TITLE = Helix
screenshots/%/helix.png: WAIT = 2
screenshots/%/helix.png: ghostty/%.toml helix/%.toml repo makefile
	$(terminal_screenshot)

screenshots/%/lazygit.png: SCENE = LAZYGIT_SCENE
screenshots/%/lazygit.png: TITLE = Lazygit
screenshots/%/lazygit.png: WAIT = 3
screenshots/%/lazygit.png: ghostty/%.toml lazygit/%.yml repo makefile
	$(terminal_screenshot)

screenshots/%/nvim.png: SCENE = NVIM_SCENE
screenshots/%/nvim.png: TITLE = Neovim
screenshots/%/nvim.png: WAIT = 2
screenshots/%/nvim.png: ghostty/%.toml nvim/colors/%.lua repo makefile
	$(terminal_screenshot)

screenshots/%/opencode.png: SCENE = OPENCODE_SCENE
screenshots/%/opencode.png: TITLE = opencode
screenshots/%/opencode.png: WAIT = 5
screenshots/%/opencode.png: ghostty/%.toml opencode/darkstar.json repo makefile
	$(terminal_screenshot)

screenshots/%/zellij.png: SCENE = ZELLIJ_SCENE
screenshots/%/zellij.png: TITLE = Zellij
screenshots/%/zellij.png: WAIT = 3
screenshots/%/zellij.png: ghostty/%.toml zellij/%.kdl repo makefile
	$(terminal_screenshot)

# Zed sizes its windows in points rather than cells. 983×664 matches the
# Ghostty windows above.
screenshots/%/zed.png: zed/%.json repo makefile
	@mkdir -p $(@D)
	@THEME=$* sh -c "$$ZED_SCREENSHOT_SH" zed-screenshot $@ 983 664
	@echo "  $@"

screenshots/%/vscode.png: vscode/package.json vscode/%-color-theme.json repo makefile
	@mkdir -p $(@D)
	@THEME=$* sh -c "$$VSCODE_SCREENSHOT_SH" vscode-screenshot $@ 983 664
	@echo "  $@"

.PHONY: all check palette install clean screenshots

# Name, hex value and the minimum contrast ratio against the background.
# 4.5 is WCAG AA and 7 is WCAG AAA. A dash means the colour isn't used for
# text, so there's nothing to check. The first few rows aren't colours:
# they're the theme's file name, display name and dark or light, for the
# templates to use. The last few rows are roles that name another colour,
# so each theme can choose what its functions and warnings look like.
define darkstar_palette
name                  darkstar  -
title                 Darkstar  -
appearance            dark      -
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
emphasis              bright_yellow  -
caution               bright_yellow  -
caution_dim           yellow   -
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
raised                background_two  -
raised_high           surface  -
raised_max            selection_primary  -
extreme               #ffffff  -
endef

# Lightstar is Darkstar for light backgrounds.
#
# The background is a white with the faintest cool tint, and the foreground
# has the same contrast against it as Darkstar's foreground. The UI greys
# share the background's tint.
#
# Each accent is as saturated as its hue allows while reaching exactly
# 4.5 (AA), or 7 (AAA) for the bright variants. Mirroring Darkstar's
# higher ratios made them too dark: on a light background, high contrast
# only leaves room for colours close to black. That's also why bright
# colours are darker here rather than lighter.
#
# Most accents keep their Solarized hue, but two are shifted. At Solarized's
# hues, blue turns a dull navy and green turns olive when darkened, so blue
# moves towards true blue and green towards true green.
#
# Readable yellow text can only be brown on a light background, so Lightstar
# avoids yellow text altogether. Its emphasis role, used for functions and
# the like, is cyan, and its caution roles are orange. Yellow itself is only
# for programs that print terminal colour 3.
#
# The raised rows are chosen by eye. The same contrast step looks bigger
# on a light background than on a dark one, so they sit much closer to the
# background than Darkstar's do.
define lightstar_palette
name                  lightstar  -
title                 Lightstar  -
appearance            light      -
background            #fcfcff  -
foreground            #262626  7
black                 #617880  4.5
red                   #ea031a  4.5
green                 #058824  4.5
yellow                #996d04  4.5
blue                  #006bff  4.5
magenta               #e10584  4.5
cyan                  #00837b  4.5
white                 #262626  7
orange                #da3701  4.5
bright_black          #445a62  7
bright_red            #b30111  7
bright_green          #006618  7
bright_yellow         #745104  7
bright_blue           #0150c2  7
bright_magenta        #ab0263  7
bright_cyan           #09625c  7
bright_white          #000000  7
bright_orange         #a62801  7
emphasis              cyan           -
caution               bright_orange  -
caution_dim           orange         -
cursor_color          #646467  -
cursor_text           #e6e6e9  -
selection_background  #e6e6e9  -
selection_foreground  #262626  -
cursorline            #ebf6f4  -
very_dark             #bababd  -
selection_primary     #bababc  -
background_two        #f4f4f8  -
linenr                #a0a0a3  -
surface               #d1d1d4  -
surface_low           #ffffff  -
raised                #ffffff  -
raised_high           cursorline  -
raised_max            #e9e9ec  -
extreme               #000000  -
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
  if (hexes[name] in hexes) return colour(hexes[name])
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
"attribute" = "emphasis"
"type" = "bright_blue"
"type.parameter" = "bright_magenta"
"type.enum.variant" = "emphasis"
"constructor" = "emphasis"
"constant" = "bright_magenta"
"constant.builtin" = "bright_magenta"
"constant.builtin.boolean" = "emphasis"
"constant.numeric" = "bright_blue"
"constant.character" = "emphasis"
"string" = "bright_green"
"string.regexp" = "emphasis"
"string.special" = "emphasis"
"comment" = { fg = "black", modifiers = ["italic"] }
"comment.block.documentation" = { fg = "emphasis", modifiers = ["italic"] }
"variable" = "white"
"variable.builtin" = "bright_red"
"label" = "magenta"
"punctuation" = "white"
"keyword" = "bright_red"
"keyword.directive" = "bright_orange"
"operator" = "white"
"function" = "emphasis"
"function.macro" = "bright_orange"
"function.builtin" = "magenta"
"tag" = "bright_magenta"
"namespace" = "white"
"namespace.mod" = "bright_blue"
"namespace.mod_type" = "magenta"
"markup.heading" = "bright_green"
"markup.list" = "bright_red"
"markup.bold" = { fg = "emphasis", modifiers = ["bold"] }
"markup.italic" = { fg = "emphasis", modifiers = ["italic"] }
"markup.strikethrough" = { modifiers = ["crossed_out"] }
"markup.link.url" = "bright_blue"
"markup.link.text" = "emphasis"
"markup.link.label" = "bright_magenta"
"markup.raw" = "bright_magenta"
"markup.quote" = "bright_green"
"diff.plus" = "bright_green"
"diff.minus" = "bright_red"
"diff.delta" = "bright_yellow"
"special" = "bright_orange"

"warning" = "caution"
"error" = { fg = "bright_red", modifiers = ["bold"] }
"info" = { fg = "bright_blue", modifiers = ["bold"] }
"hint" = { fg = "bright_green", modifiers = ["bold"] }
"diagnostic.hint" = { underline = { color = "bright_green", style = "curl" } }
"diagnostic.info" = { underline = { color = "bright_blue", style = "curl" } }
"diagnostic.warning" = { underline = { color = "caution", style = "curl" } }
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
emphasis = "{{emphasis}}"
caution = "{{caution}}"
caution_dim = "{{caution_dim}}"
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
theme = $PWD/ghostty/$THEME.toml
title = $title
window-width = $cols
window-height = $rows
window-padding-x = 12
window-padding-y = 10
font-family = Lilex
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
  printf 'export DARKSTAR=%s SCENE_DIR=%s THEME=%s\n' "'$PWD'" "'$dir'" "'$THEME'"
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
cp "$DARKSTAR/helix/$THEME.toml" "$SCENE_DIR/xdg/helix/themes/"
printf 'theme = "%s"\n' "$THEME" > "$SCENE_DIR/xdg/helix/config.toml"
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
  -ucf "$SCENE_DIR/lazygit/config.yml,$DARKSTAR/lazygit/$THEME.yml"
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
      "base": "$hue.neutral.200",
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
      "base": "$hue.neutral.500"
    },
    "scrollbar": {
      "base": "$hue.neutral.400"
    },
    "diff": {
      "text": {
        "added": "$hue.green.400",
        "removed": "$hue.red.400",
        "context": "$hue.neutral.300",
        "hunkHeader": "$hue.neutral.300"
      },
      "background": {
        "added": "$hue.green.700",
        "removed": "$hue.red.700",
        "context": "$hue.neutral.700"
      },
      "highlight": {
        "added": "$hue.green.400",
        "removed": "$hue.red.400"
      },
      "lineNumber": {
        "text": "$hue.neutral.400",
        "background": {
          "added": "$hue.green.800",
          "removed": "$hue.red.800"
        }
      }
    },
    "syntax": {
      "comment": "$hue.neutral.300",
      "keyword": "$hue.red.400",
      "function": "$hue.yellow.400",
      "variable": "$hue.neutral.200",
      "string": "$hue.green.400",
      "number": "$hue.blue.400",
      "type": "$hue.blue.400",
      "operator": "$hue.neutral.200",
      "punctuation": "$hue.neutral.200"
    },
    "markdown": {
      "text": "$hue.neutral.200",
      "heading": "$hue.green.400",
      "link": "$hue.blue.400",
      "linkText": "$hue.yellow.400",
      "code": "$hue.cyan.400",
      "blockQuote": "$hue.green.400",
      "emphasis": "$hue.yellow.400",
      "strong": "$hue.yellow.400",
      "horizontalRule": "$hue.neutral.300",
      "listItem": "$hue.red.400",
      "listEnumeration": "$hue.red.400",
      "image": "$hue.blue.400",
      "imageText": "$hue.yellow.400",
      "codeBlock": "$hue.neutral.200"
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
endef

define opencode_mode
  "{{appearance}}": {
    "hue": {
      "red": {
        "100": "{{mix bright_red extreme 0.6}}",
        "200": "{{mix bright_red extreme 0.3}}",
        "300": "{{mix bright_red extreme 0.12}}",
        "400": "{{bright_red}}",
        "500": "{{red}}",
        "600": "{{mix red background 0.6}}",
        "700": "{{mix red background 0.78}}",
        "800": "{{mix red background 0.88}}",
        "900": "{{mix red background 0.95}}"
      },
      "orange": {
        "100": "{{mix bright_orange extreme 0.6}}",
        "200": "{{mix bright_orange extreme 0.3}}",
        "300": "{{mix bright_orange extreme 0.12}}",
        "400": "{{bright_orange}}",
        "500": "{{orange}}",
        "600": "{{mix orange background 0.6}}",
        "700": "{{mix orange background 0.78}}",
        "800": "{{mix orange background 0.88}}",
        "900": "{{mix orange background 0.95}}"
      },
      "yellow": {
        "100": "{{mix caution extreme 0.6}}",
        "200": "{{mix caution extreme 0.3}}",
        "300": "{{mix caution extreme 0.12}}",
        "400": "{{caution}}",
        "500": "{{caution_dim}}",
        "600": "{{mix caution_dim background 0.6}}",
        "700": "{{mix caution_dim background 0.78}}",
        "800": "{{mix caution_dim background 0.88}}",
        "900": "{{mix caution_dim background 0.95}}"
      },
      "green": {
        "100": "{{mix bright_green extreme 0.6}}",
        "200": "{{mix bright_green extreme 0.3}}",
        "300": "{{mix bright_green extreme 0.12}}",
        "400": "{{bright_green}}",
        "500": "{{green}}",
        "600": "{{mix green background 0.6}}",
        "700": "{{mix green background 0.78}}",
        "800": "{{mix green background 0.88}}",
        "900": "{{mix green background 0.95}}"
      },
      "cyan": {
        "100": "{{mix bright_cyan extreme 0.6}}",
        "200": "{{mix bright_cyan extreme 0.3}}",
        "300": "{{mix bright_cyan extreme 0.12}}",
        "400": "{{bright_cyan}}",
        "500": "{{cyan}}",
        "600": "{{mix cyan background 0.6}}",
        "700": "{{mix cyan background 0.78}}",
        "800": "{{mix cyan background 0.88}}",
        "900": "{{mix cyan background 0.95}}"
      },
      "blue": {
        "100": "{{mix bright_blue extreme 0.6}}",
        "200": "{{mix bright_blue extreme 0.3}}",
        "300": "{{mix bright_blue extreme 0.12}}",
        "400": "{{bright_blue}}",
        "500": "{{blue}}",
        "600": "{{mix blue background 0.6}}",
        "700": "{{mix blue background 0.78}}",
        "800": "{{mix blue background 0.88}}",
        "900": "{{mix blue background 0.95}}"
      },
      "purple": {
        "100": "{{mix bright_magenta extreme 0.6}}",
        "200": "{{mix bright_magenta extreme 0.3}}",
        "300": "{{mix bright_magenta extreme 0.12}}",
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
        "500": "{{raised_max}}",
        "600": "{{raised_high}}",
        "700": "{{raised}}",
        "800": "{{surface_low}}",
        "900": "{{background}}"
      },
      "accent": "$hue.blue",
      "interactive": "$hue.blue",
      "neutral": "$hue.gray"
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
      "function": "{{emphasis}}",
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
      "linkText": "{{emphasis}}",
      "code": "{{bright_cyan}}",
      "blockQuote": "{{bright_green}}",
      "emphasis": "{{emphasis}}",
      "strong": "{{emphasis}}",
      "horizontalRule": "{{black}}",
      "listItem": "{{bright_red}}",
      "listEnumeration": "{{bright_red}}",
      "image": "{{bright_blue}}",
      "imageText": "{{emphasis}}",
      "codeBlock": "{{foreground}}"
    }
  }
endef


define opencode_scene
mkdir -p "$SCENE_DIR/xdg/opencode/themes"
cp "$DARKSTAR/opencode/darkstar.json" "$SCENE_DIR/xdg/opencode/themes/"
mode=dark
[ "$THEME" = lightstar ] && mode=light
cat > "$SCENE_DIR/xdg/opencode/cli.json" <<JSON
{
  "theme": { "name": "darkstar", "mode": "$mode" },
  "animations": false
}
JSON
export XDG_CONFIG_HOME="$SCENE_DIR/xdg" XDG_DATA_HOME="$SCENE_DIR/data"
export XDG_STATE_HOME="$SCENE_DIR/state" XDG_CACHE_HOME="$SCENE_DIR/cache"
export OPENCODE_DISABLE_AUTOUPDATE=1
cd "$DARKSTAR/repo"
exec opencode --standalone
endef


define nvim
-- {{title}} for Neovim: https://github.com/henrycatalinismith/darkstar
-- Generated by the Darkstar makefile. Edit the makefile, not this file.

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.o.background = "{{appearance}}"
vim.g.colors_name = "{{name}}"

local c = {
  background = "{{background}}",
  foreground = "{{foreground}}",
  black = "{{black}}",
  red = "{{red}}",
  green = "{{green}}",
  yellow = "{{yellow}}",
  blue = "{{blue}}",
  magenta = "{{magenta}}",
  cyan = "{{cyan}}",
  white = "{{white}}",
  orange = "{{orange}}",
  bright_black = "{{bright_black}}",
  bright_red = "{{bright_red}}",
  bright_green = "{{bright_green}}",
  bright_yellow = "{{bright_yellow}}",
  bright_blue = "{{bright_blue}}",
  bright_magenta = "{{bright_magenta}}",
  bright_cyan = "{{bright_cyan}}",
  bright_white = "{{bright_white}}",
  bright_orange = "{{bright_orange}}",
  emphasis = "{{emphasis}}",
  caution = "{{caution}}",
  caution_dim = "{{caution_dim}}",
  cursorline = "{{cursorline}}",
  very_dark = "{{very_dark}}",
  selection = "{{selection_primary}}",
  background_two = "{{background_two}}",
  linenr = "{{linenr}}",
  surface = "{{surface}}",
  diff_add = "{{mix green background 0.82}}",
  diff_delete = "{{mix red background 0.82}}",
  diff_change = "{{mix caution_dim background 0.88}}",
  diff_text = "{{mix caution_dim background 0.7}}",
}

local groups = {
  -- Editor
  Normal = { fg = c.foreground, bg = c.background },
  NormalNC = { link = "Normal" },
  NormalFloat = { fg = c.foreground, bg = c.background_two },
  FloatBorder = { fg = c.very_dark, bg = c.background_two },
  FloatTitle = { fg = c.foreground, bg = c.background_two, bold = true },
  Cursor = { fg = c.background, bg = c.foreground },
  lCursor = { link = "Cursor" },
  CursorIM = { link = "Cursor" },
  TermCursor = { link = "Cursor" },
  CursorLine = { bg = c.cursorline },
  CursorColumn = { bg = c.cursorline },
  ColorColumn = { bg = c.very_dark },
  LineNr = { fg = c.linenr },
  LineNrAbove = { link = "LineNr" },
  LineNrBelow = { link = "LineNr" },
  CursorLineNr = { fg = c.blue, bold = true },
  SignColumn = { bg = c.background },
  FoldColumn = { fg = c.linenr },
  Folded = { fg = c.bright_black, bg = c.background_two },
  Visual = { bg = c.selection },
  VisualNOS = { link = "Visual" },
  Search = { fg = c.background, bg = c.caution_dim },
  IncSearch = { fg = c.background, bg = c.caution },
  CurSearch = { link = "IncSearch" },
  Substitute = { fg = c.background, bg = c.bright_orange },
  MatchParen = { bg = c.background_two, bold = true },
  NonText = { fg = c.very_dark },
  EndOfBuffer = { fg = c.very_dark },
  Whitespace = { fg = c.very_dark },
  SpecialKey = { fg = c.linenr },
  Conceal = { fg = c.bright_black },
  WinSeparator = { fg = c.very_dark },
  VertSplit = { link = "WinSeparator" },
  StatusLine = { fg = c.foreground, bg = c.surface },
  StatusLineNC = { fg = c.bright_black, bg = c.background_two },
  TabLine = { fg = c.bright_black, bg = c.background_two },
  TabLineFill = { bg = c.background_two },
  TabLineSel = { fg = c.foreground, bg = c.background, bold = true },
  WinBar = { fg = c.foreground, bold = true },
  WinBarNC = { fg = c.bright_black },
  Pmenu = { fg = c.foreground, bg = c.background_two },
  PmenuSel = { fg = c.foreground, bg = c.selection },
  PmenuSbar = { bg = c.background_two },
  PmenuThumb = { bg = c.very_dark },
  PmenuKind = { fg = c.bright_blue, bg = c.background_two },
  PmenuExtra = { fg = c.bright_black, bg = c.background_two },
  WildMenu = { link = "PmenuSel" },
  QuickFixLine = { bg = c.cursorline },
  Directory = { fg = c.bright_blue },
  Title = { fg = c.bright_green, bold = true },
  Question = { fg = c.bright_green },
  MoreMsg = { fg = c.bright_green },
  ModeMsg = { fg = c.foreground, bold = true },
  MsgArea = { fg = c.foreground },
  WarningMsg = { fg = c.caution },
  ErrorMsg = { fg = c.bright_red, bold = true },
  SpellBad = { undercurl = true, sp = c.bright_red },
  SpellCap = { undercurl = true, sp = c.caution },
  SpellRare = { undercurl = true, sp = c.bright_magenta },
  SpellLocal = { undercurl = true, sp = c.bright_cyan },

  -- Diffs
  DiffAdd = { bg = c.diff_add },
  DiffDelete = { fg = c.bright_red, bg = c.diff_delete },
  DiffChange = { bg = c.diff_change },
  DiffText = { bg = c.diff_text },
  Added = { fg = c.bright_green },
  Removed = { fg = c.bright_red },
  Changed = { fg = c.caution },
  diffAdded = { link = "Added" },
  diffRemoved = { link = "Removed" },
  diffChanged = { link = "Changed" },

  -- Syntax
  Comment = { fg = c.black, italic = true },
  SpecialComment = { fg = c.emphasis, italic = true },
  Constant = { fg = c.bright_magenta },
  String = { fg = c.bright_green },
  Character = { fg = c.emphasis },
  Number = { fg = c.bright_blue },
  Float = { fg = c.bright_blue },
  Boolean = { fg = c.emphasis },
  Identifier = { fg = c.foreground },
  Function = { fg = c.emphasis },
  Statement = { fg = c.bright_red },
  Conditional = { fg = c.bright_red },
  Repeat = { fg = c.bright_red },
  Label = { fg = c.magenta },
  Keyword = { fg = c.bright_red },
  Exception = { fg = c.bright_red },
  Operator = { fg = c.foreground },
  PreProc = { fg = c.bright_orange },
  Include = { fg = c.bright_red },
  Define = { fg = c.bright_orange },
  Macro = { fg = c.bright_orange },
  PreCondit = { fg = c.bright_orange },
  Type = { fg = c.bright_blue },
  StorageClass = { fg = c.bright_red },
  Structure = { fg = c.bright_blue },
  Typedef = { fg = c.bright_blue },
  Special = { fg = c.bright_orange },
  SpecialChar = { fg = c.emphasis },
  Tag = { fg = c.bright_magenta },
  Delimiter = { fg = c.foreground },
  Debug = { fg = c.bright_orange },
  Underlined = { underline = true },
  Ignore = { fg = c.bright_black },
  Error = { fg = c.bright_red, bold = true },
  Todo = { fg = c.caution, bold = true },

  -- Tree-sitter
  ["@variable"] = { fg = c.foreground },
  ["@variable.builtin"] = { fg = c.bright_red },
  ["@variable.parameter"] = { fg = c.foreground },
  ["@variable.member"] = { fg = c.foreground },
  ["@property"] = { fg = c.foreground },
  ["@constant"] = { fg = c.bright_magenta },
  ["@constant.builtin"] = { fg = c.bright_magenta },
  ["@constant.macro"] = { fg = c.bright_orange },
  ["@module"] = { fg = c.foreground },
  ["@label"] = { fg = c.magenta },
  ["@string"] = { fg = c.bright_green },
  ["@string.regexp"] = { fg = c.emphasis },
  ["@string.escape"] = { fg = c.emphasis },
  ["@string.special"] = { fg = c.emphasis },
  ["@string.special.url"] = { fg = c.bright_blue, underline = true },
  ["@character"] = { fg = c.emphasis },
  ["@boolean"] = { fg = c.emphasis },
  ["@number"] = { fg = c.bright_blue },
  ["@number.float"] = { fg = c.bright_blue },
  ["@type"] = { fg = c.bright_blue },
  ["@type.builtin"] = { fg = c.bright_blue },
  ["@type.definition"] = { fg = c.bright_blue },
  ["@attribute"] = { fg = c.emphasis },
  ["@function"] = { fg = c.emphasis },
  ["@function.builtin"] = { fg = c.magenta },
  ["@function.call"] = { fg = c.emphasis },
  ["@function.macro"] = { fg = c.bright_orange },
  ["@function.method"] = { fg = c.emphasis },
  ["@function.method.call"] = { fg = c.emphasis },
  ["@constructor"] = { fg = c.emphasis },
  ["@operator"] = { fg = c.foreground },
  ["@keyword"] = { fg = c.bright_red },
  ["@keyword.directive"] = { fg = c.bright_orange },
  ["@punctuation"] = { fg = c.foreground },
  ["@punctuation.delimiter"] = { fg = c.foreground },
  ["@punctuation.bracket"] = { fg = c.foreground },
  ["@punctuation.special"] = { fg = c.bright_orange },
  ["@comment"] = { link = "Comment" },
  ["@comment.documentation"] = { link = "Comment" },
  ["@comment.error"] = { fg = c.bright_red, bold = true },
  ["@comment.warning"] = { fg = c.caution, bold = true },
  ["@comment.todo"] = { link = "Todo" },
  ["@comment.note"] = { fg = c.bright_blue, bold = true },
  ["@tag"] = { fg = c.bright_magenta },
  ["@tag.attribute"] = { fg = c.emphasis },
  ["@tag.delimiter"] = { fg = c.foreground },
  ["@markup.heading"] = { fg = c.bright_green, bold = true },
  ["@markup.strong"] = { fg = c.emphasis, bold = true },
  ["@markup.italic"] = { fg = c.emphasis, italic = true },
  ["@markup.strikethrough"] = { strikethrough = true },
  ["@markup.underline"] = { underline = true },
  ["@markup.link"] = { fg = c.emphasis },
  ["@markup.link.url"] = { fg = c.bright_blue, underline = true },
  ["@markup.link.label"] = { fg = c.bright_magenta },
  ["@markup.raw"] = { fg = c.bright_magenta },
  ["@markup.quote"] = { fg = c.bright_green },
  ["@markup.list"] = { fg = c.bright_red },
  ["@diff.plus"] = { link = "Added" },
  ["@diff.minus"] = { link = "Removed" },
  ["@diff.delta"] = { link = "Changed" },

  -- Diagnostics and LSP
  DiagnosticError = { fg = c.bright_red },
  DiagnosticWarn = { fg = c.caution },
  DiagnosticInfo = { fg = c.bright_blue },
  DiagnosticHint = { fg = c.bright_green },
  DiagnosticOk = { fg = c.bright_green },
  DiagnosticUnderlineError = { undercurl = true, sp = c.bright_red },
  DiagnosticUnderlineWarn = { undercurl = true, sp = c.caution },
  DiagnosticUnderlineInfo = { undercurl = true, sp = c.bright_blue },
  DiagnosticUnderlineHint = { undercurl = true, sp = c.bright_green },
  DiagnosticUnderlineOk = { undercurl = true, sp = c.bright_green },
  DiagnosticDeprecated = { strikethrough = true },
  DiagnosticUnnecessary = { fg = c.bright_black },
  LspReferenceText = { bg = c.background_two },
  LspReferenceRead = { bg = c.background_two },
  LspReferenceWrite = { bg = c.background_two },
  LspInlayHint = { fg = c.bright_black, italic = true },
  LspSignatureActiveParameter = { bold = true, underline = true },
}

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end

local terminal = {
  c.black, c.red, c.green, c.yellow, c.blue, c.magenta, c.cyan, c.white,
  c.bright_black, c.bright_red, c.bright_green, c.bright_yellow,
  c.bright_blue, c.bright_magenta, c.bright_cyan, c.bright_white,
}
for i, colour in ipairs(terminal) do
  vim.g["terminal_color_" .. (i - 1)] = colour
end
endef

define nvim_scene
mkdir -p "$SCENE_DIR/xdg/nvim"
cat > "$SCENE_DIR/xdg/nvim/init.lua" <<'LUA'
vim.opt.packpath = { vim.env.VIMRUNTIME }
vim.opt.runtimepath:prepend(vim.env.DARKSTAR .. "/nvim")
vim.o.termguicolors = true
vim.o.number = true
vim.o.cursorline = true
vim.o.signcolumn = "yes"
vim.o.laststatus = 2
vim.opt.fillchars:append({ eob = " " })
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})
vim.cmd.colorscheme(vim.env.THEME)
LUA
export XDG_CONFIG_HOME="$SCENE_DIR/xdg" XDG_STATE_HOME="$SCENE_DIR/state"
cd "$DARKSTAR/repo"
exec nvim -i NONE -n src/cart.ts +24
endef


define zellij
themes {
    {{name}} {
        text_unselected {
            base "{{foreground}}"
            background "{{background}}"
            emphasis_0 "{{bright_orange}}"
            emphasis_1 "{{bright_cyan}}"
            emphasis_2 "{{bright_green}}"
            emphasis_3 "{{bright_magenta}}"
        }
        text_selected {
            base "{{foreground}}"
            background "{{selection_primary}}"
            emphasis_0 "{{bright_orange}}"
            emphasis_1 "{{bright_cyan}}"
            emphasis_2 "{{bright_green}}"
            emphasis_3 "{{bright_magenta}}"
        }
        ribbon_selected {
            base "{{background}}"
            background "{{bright_green}}"
            emphasis_0 "{{red}}"
            emphasis_1 "{{orange}}"
            emphasis_2 "{{magenta}}"
            emphasis_3 "{{blue}}"
        }
        ribbon_unselected {
            base "{{foreground}}"
            background "{{surface}}"
            emphasis_0 "{{bright_red}}"
            emphasis_1 "{{bright_orange}}"
            emphasis_2 "{{bright_magenta}}"
            emphasis_3 "{{bright_blue}}"
        }
        table_title {
            base "{{bright_green}}"
            background "{{background}}"
            emphasis_0 "{{bright_orange}}"
            emphasis_1 "{{bright_cyan}}"
            emphasis_2 "{{bright_green}}"
            emphasis_3 "{{bright_magenta}}"
        }
        table_cell_selected {
            base "{{foreground}}"
            background "{{selection_primary}}"
            emphasis_0 "{{bright_orange}}"
            emphasis_1 "{{bright_cyan}}"
            emphasis_2 "{{bright_green}}"
            emphasis_3 "{{bright_magenta}}"
        }
        table_cell_unselected {
            base "{{foreground}}"
            background "{{background}}"
            emphasis_0 "{{bright_orange}}"
            emphasis_1 "{{bright_cyan}}"
            emphasis_2 "{{bright_green}}"
            emphasis_3 "{{bright_magenta}}"
        }
        list_selected {
            base "{{foreground}}"
            background "{{selection_primary}}"
            emphasis_0 "{{bright_orange}}"
            emphasis_1 "{{bright_cyan}}"
            emphasis_2 "{{bright_green}}"
            emphasis_3 "{{bright_magenta}}"
        }
        list_unselected {
            base "{{foreground}}"
            background "{{background}}"
            emphasis_0 "{{bright_orange}}"
            emphasis_1 "{{bright_cyan}}"
            emphasis_2 "{{bright_green}}"
            emphasis_3 "{{bright_magenta}}"
        }
        frame_selected {
            base "{{foreground}}"
            background "{{background}}"
            emphasis_0 "{{bright_orange}}"
            emphasis_1 "{{bright_cyan}}"
            emphasis_2 "{{bright_magenta}}"
            emphasis_3 "{{background}}"
        }
        frame_unselected {
            base "{{linenr}}"
            background "{{background}}"
            emphasis_0 "{{bright_orange}}"
            emphasis_1 "{{bright_cyan}}"
            emphasis_2 "{{bright_magenta}}"
            emphasis_3 "{{background}}"
        }
        frame_highlight {
            base "{{bright_orange}}"
            background "{{background}}"
            emphasis_0 "{{bright_magenta}}"
            emphasis_1 "{{bright_orange}}"
            emphasis_2 "{{bright_orange}}"
            emphasis_3 "{{bright_orange}}"
        }
        exit_code_success {
            base "{{bright_green}}"
            background "{{background}}"
            emphasis_0 "{{bright_cyan}}"
            emphasis_1 "{{background}}"
            emphasis_2 "{{bright_magenta}}"
            emphasis_3 "{{bright_blue}}"
        }
        exit_code_error {
            base "{{bright_red}}"
            background "{{background}}"
            emphasis_0 "{{caution}}"
            emphasis_1 "{{background}}"
            emphasis_2 "{{background}}"
            emphasis_3 "{{background}}"
        }
        multiplayer_user_colors {
            player_1 "{{bright_magenta}}"
            player_2 "{{bright_blue}}"
            player_3 "{{bright_green}}"
            player_4 "{{caution}}"
            player_5 "{{bright_cyan}}"
            player_6 "{{bright_red}}"
            player_7 "{{bright_orange}}"
            player_8 "{{magenta}}"
            player_9 "{{blue}}"
            player_10 "{{cyan}}"
        }
    }
}
endef

define zellij_scene
mkdir -p "$SCENE_DIR/zellij/themes"
cp "$DARKSTAR/zellij/$THEME.kdl" "$SCENE_DIR/zellij/themes/"
cat > "$SCENE_DIR/zellij/config.kdl" <<KDL
theme "$THEME"
show_startup_tips false
show_release_notes false
session_serialization false
on_force_close "quit"
pane_frames true
pane_frame_style "full"
default_shell "sh"
KDL
cat > "$SCENE_DIR/zellij/layout.kdl" <<KDL
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }
    tab name="basket" focus=true {
        pane split_direction="vertical" {
            pane name="log" focus=true command="sh" {
                args "-c" "tput civis; stty -echo; git log --graph --oneline --decorate --color=always --all; sleep 600"
                cwd "$DARKSTAR/repo"
            }
            pane split_direction="horizontal" {
                pane name="status" command="git" {
                    args "-c" "color.status=always" "status" "--short" "--branch"
                    cwd "$DARKSTAR/repo"
                }
                pane name="test" command="sh" {
                    args "-c" "printf 'node test/cart.test.ts\n'; exit 1"
                    cwd "$DARKSTAR/repo"
                }
            }
        }
    }
    tab name="notes" {
        pane
    }
    tab name="server" {
        pane
    }
}
KDL
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export ZELLIJ_SOCKET_DIR="$(mktemp -d /tmp/zj.XXXX)"
exec zellij --config-dir "$SCENE_DIR/zellij" --new-session-with-layout "$SCENE_DIR/zellij/layout.kdl" --session darkstar-screenshot
endef


define zed
{
  "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
  "name": "{{title}}",
  "author": "Henry Catalini Smith",
  "themes": [
    {
      "name": "{{title}}",
      "appearance": "{{appearance}}",
      "style": {
        "background": "{{background_two}}",
        "border": "{{very_dark}}",
        "border.variant": "{{very_dark}}",
        "border.focused": "{{blue}}",
        "border.selected": "{{blue}}",
        "border.transparent": "#00000000",
        "border.disabled": "{{very_dark}}",
        "elevated_surface.background": "{{background_two}}",
        "surface.background": "{{background_two}}",
        "element.background": "{{surface}}",
        "element.hover": "{{very_dark}}",
        "element.active": "{{selection_primary}}",
        "element.selected": "{{selection_primary}}",
        "element.disabled": "{{background_two}}",
        "drop_target.background": "{{bright_blue}}33",
        "ghost_element.background": "#00000000",
        "ghost_element.hover": "{{very_dark}}",
        "ghost_element.active": "{{selection_primary}}",
        "ghost_element.selected": "{{selection_primary}}",
        "ghost_element.disabled": "#00000000",
        "text": "{{foreground}}",
        "text.muted": "{{bright_black}}",
        "text.placeholder": "{{black}}",
        "text.disabled": "{{linenr}}",
        "text.accent": "{{bright_blue}}",
        "icon": "{{foreground}}",
        "icon.muted": "{{bright_black}}",
        "icon.disabled": "{{linenr}}",
        "icon.placeholder": "{{black}}",
        "icon.accent": "{{bright_blue}}",
        "status_bar.background": "{{background_two}}",
        "title_bar.background": "{{background_two}}",
        "title_bar.inactive_background": "{{background_two}}",
        "toolbar.background": "{{background}}",
        "tab_bar.background": "{{background_two}}",
        "tab.inactive_background": "{{background_two}}",
        "tab.active_background": "{{background}}",
        "search.match_background": "{{caution_dim}}66",
        "panel.background": "{{background_two}}",
        "panel.focused_border": "{{blue}}",
        "pane.focused_border": "{{blue}}",
        "scrollbar.thumb.background": "{{very_dark}}99",
        "scrollbar.thumb.hover_background": "{{very_dark}}",
        "scrollbar.thumb.border": "#00000000",
        "scrollbar.track.background": "#00000000",
        "scrollbar.track.border": "#00000000",
        "editor.foreground": "{{foreground}}",
        "editor.background": "{{background}}",
        "editor.gutter.background": "{{background}}",
        "editor.subheader.background": "{{background_two}}",
        "editor.active_line.background": "{{cursorline}}",
        "editor.highlighted_line.background": "{{cursorline}}",
        "editor.line_number": "{{linenr}}",
        "editor.active_line_number": "{{blue}}",
        "editor.invisible": "{{very_dark}}",
        "editor.wrap_guide": "{{very_dark}}",
        "editor.active_wrap_guide": "{{linenr}}",
        "editor.indent_guide": "{{very_dark}}",
        "editor.indent_guide_active": "{{linenr}}",
        "editor.document_highlight.read_background": "{{very_dark}}80",
        "editor.document_highlight.write_background": "{{very_dark}}",
        "terminal.background": "{{background}}",
        "terminal.foreground": "{{foreground}}",
        "terminal.bright_foreground": "{{bright_white}}",
        "terminal.dim_foreground": "{{bright_black}}",
        "terminal.ansi.black": "{{black}}",
        "terminal.ansi.red": "{{red}}",
        "terminal.ansi.green": "{{green}}",
        "terminal.ansi.yellow": "{{yellow}}",
        "terminal.ansi.blue": "{{blue}}",
        "terminal.ansi.magenta": "{{magenta}}",
        "terminal.ansi.cyan": "{{cyan}}",
        "terminal.ansi.white": "{{white}}",
        "terminal.ansi.bright_black": "{{bright_black}}",
        "terminal.ansi.bright_red": "{{bright_red}}",
        "terminal.ansi.bright_green": "{{bright_green}}",
        "terminal.ansi.bright_yellow": "{{bright_yellow}}",
        "terminal.ansi.bright_blue": "{{bright_blue}}",
        "terminal.ansi.bright_magenta": "{{bright_magenta}}",
        "terminal.ansi.bright_cyan": "{{bright_cyan}}",
        "terminal.ansi.bright_white": "{{bright_white}}",
        "link_text.hover": "{{bright_blue}}",
        "conflict": "{{bright_orange}}",
        "conflict.background": "{{mix orange background 0.82}}",
        "conflict.border": "{{orange}}",
        "created": "{{bright_green}}",
        "created.background": "{{mix green background 0.82}}",
        "created.border": "{{green}}",
        "deleted": "{{bright_red}}",
        "deleted.background": "{{mix red background 0.82}}",
        "deleted.border": "{{red}}",
        "error": "{{bright_red}}",
        "error.background": "{{mix red background 0.82}}",
        "error.border": "{{red}}",
        "hidden": "{{linenr}}",
        "hint": "{{bright_black}}",
        "hint.background": "{{background_two}}",
        "hint.border": "{{very_dark}}",
        "ignored": "{{linenr}}",
        "info": "{{bright_blue}}",
        "info.background": "{{mix blue background 0.82}}",
        "info.border": "{{blue}}",
        "modified": "{{caution}}",
        "modified.background": "{{mix caution_dim background 0.82}}",
        "modified.border": "{{caution_dim}}",
        "predictive": "{{bright_black}}",
        "renamed": "{{bright_blue}}",
        "success": "{{bright_green}}",
        "success.background": "{{mix green background 0.82}}",
        "success.border": "{{green}}",
        "unreachable": "{{bright_black}}",
        "warning": "{{caution}}",
        "warning.background": "{{mix caution_dim background 0.82}}",
        "warning.border": "{{caution_dim}}",
        "players": [
          { "cursor": "{{foreground}}", "background": "{{foreground}}", "selection": "{{selection_primary}}" },
          { "cursor": "{{bright_magenta}}", "background": "{{bright_magenta}}", "selection": "{{bright_magenta}}33" },
          { "cursor": "{{bright_green}}", "background": "{{bright_green}}", "selection": "{{bright_green}}33" },
          { "cursor": "{{bright_orange}}", "background": "{{bright_orange}}", "selection": "{{bright_orange}}33" },
          { "cursor": "{{bright_cyan}}", "background": "{{bright_cyan}}", "selection": "{{bright_cyan}}33" },
          { "cursor": "{{caution}}", "background": "{{caution}}", "selection": "{{caution}}33" }
        ],
        "syntax": {
          "attribute": { "color": "{{emphasis}}" },
          "boolean": { "color": "{{emphasis}}" },
          "comment": { "color": "{{black}}", "font_style": "italic" },
          "comment.doc": { "color": "{{black}}", "font_style": "italic" },
          "constant": { "color": "{{bright_magenta}}" },
          "constructor": { "color": "{{emphasis}}" },
          "embedded": { "color": "{{foreground}}" },
          "emphasis": { "color": "{{emphasis}}", "font_style": "italic" },
          "emphasis.strong": { "color": "{{emphasis}}", "font_weight": 700 },
          "enum": { "color": "{{emphasis}}" },
          "function": { "color": "{{emphasis}}" },
          "function.builtin": { "color": "{{magenta}}" },
          "hint": { "color": "{{bright_black}}", "font_style": "italic" },
          "keyword": { "color": "{{bright_red}}" },
          "label": { "color": "{{magenta}}" },
          "link_text": { "color": "{{emphasis}}" },
          "link_uri": { "color": "{{bright_blue}}" },
          "number": { "color": "{{bright_blue}}" },
          "operator": { "color": "{{foreground}}" },
          "predictive": { "color": "{{bright_black}}", "font_style": "italic" },
          "preproc": { "color": "{{bright_orange}}" },
          "primary": { "color": "{{foreground}}" },
          "property": { "color": "{{foreground}}" },
          "punctuation": { "color": "{{foreground}}" },
          "punctuation.bracket": { "color": "{{foreground}}" },
          "punctuation.delimiter": { "color": "{{foreground}}" },
          "punctuation.list_marker": { "color": "{{bright_red}}" },
          "punctuation.special": { "color": "{{bright_orange}}" },
          "string": { "color": "{{bright_green}}" },
          "string.escape": { "color": "{{emphasis}}" },
          "string.regex": { "color": "{{emphasis}}" },
          "string.special": { "color": "{{emphasis}}" },
          "string.special.symbol": { "color": "{{emphasis}}" },
          "tag": { "color": "{{bright_magenta}}" },
          "text.literal": { "color": "{{bright_magenta}}" },
          "title": { "color": "{{bright_green}}", "font_weight": 700 },
          "type": { "color": "{{bright_blue}}" },
          "variable": { "color": "{{foreground}}" },
          "variable.special": { "color": "{{bright_red}}" },
          "variant": { "color": "{{emphasis}}" }
        }
      }
    }
  ]
}
endef


# Zed isn't a terminal program, so it gets its own screenshot script. It
# runs a separate copy of Zed with its own settings, tries to resize the
# window to match the Ghostty ones and captures it.
#
# Arguments: output file, window width and height in points.
define zed_screenshot_sh
set -e
out="$PWD/$1"; width="$2"; height="$3"
title=$(printf '%s' "$THEME" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }')
darkstar="$PWD"
dir=$(mktemp -d /tmp/zed.XXXX)
trap 'rm -rf "$dir"' EXIT

mkdir -p "$dir/config/themes"
cp "$darkstar/zed/$THEME.json" "$dir/config/themes/"
cat > "$dir/config/settings.json" <<JSON
{
  "theme": { "mode": "system", "dark": "$title", "light": "$title" },
  "session": { "trust_all_worktrees": true },
  "auto_update": false,
  "telemetry": { "diagnostics": false, "metrics": false },
  "enable_language_server": false,
  "show_edit_predictions": false,
  "title_bar": { "show_user_picture": false, "show_sign_in": false },
  "collaboration_panel": { "button": false },
  "agent": { "enabled": false, "button": false },
  "restore_on_startup": "none",
  "cursor_blink": false,
  "ui_font_family": "Lilex",
  "ui_font_size": 15,
  "buffer_font_family": "Lilex",
  "terminal": { "font_family": "Lilex" },
  "buffer_font_size": 15
}
JSON

cd "$darkstar/repo"
/Applications/Zed.app/Contents/MacOS/zed --user-data-dir "$dir" . src/cart.ts:24 > /dev/null 2>&1 &
pid=$!

window=
for i in $(seq 50); do
  window=$(osascript -l JavaScript -e "$WINDOW_ID_JS" "$pid")
  [ -n "$window" ] && break
  sleep 0.2
done
if [ -z "$window" ]; then
  echo "couldn't find the Zed window" >&2
  kill "$pid"
  exit 1
fi

osascript -e "tell application \"System Events\" to tell (first process whose unix id is $pid) to set size of window 1 to {$width, $height}" > /dev/null 2>&1 ||
  echo "couldn't resize the Zed window: does this terminal have Accessibility permission?" >&2

sleep 4
screencapture -x -o -l "$window" "$out" || {
  echo "screencapture failed: does this terminal have Screen Recording permission?" >&2
  kill "$pid"
  exit 1
}
kill "$pid"
wait "$pid" 2>/dev/null || true
endef


define vscode_package
{
  "name": "darkstar",
  "displayName": "Darkstar",
  "description": "Solarized without the contrast bugs",
  "version": "0.1.0",
  "publisher": "henrycatalinismith",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/henrycatalinismith/darkstar"
  },
  "engines": {
    "vscode": "^1.70.0"
  },
  "categories": ["Themes"],
  "contributes": {
    "themes": [
      {
        "label": "Darkstar",
        "uiTheme": "vs-dark",
        "path": "./darkstar-color-theme.json"
      },
      {
        "label": "Lightstar",
        "uiTheme": "vs",
        "path": "./lightstar-color-theme.json"
      }
    ]
  }
}
endef

define vscode_theme
{
  "$schema": "vscode://schemas/color-theme",
  "name": "{{title}}",
  "type": "{{appearance}}",
  "semanticHighlighting": true,
  "colors": {
    "foreground": "{{foreground}}",
    "descriptionForeground": "{{bright_black}}",
    "disabledForeground": "{{linenr}}",
    "errorForeground": "{{bright_red}}",
    "focusBorder": "{{blue}}",
    "icon.foreground": "{{foreground}}",
    "selection.background": "{{selection_primary}}",
    "widget.border": "{{very_dark}}",
    "widget.shadow": "#00000080",
    "sash.hoverBorder": "{{blue}}",
    "textLink.foreground": "{{bright_blue}}",
    "textLink.activeForeground": "{{bright_cyan}}",
    "textPreformat.foreground": "{{bright_magenta}}",
    "textBlockQuote.background": "{{background_two}}",
    "textBlockQuote.border": "{{very_dark}}",
    "textCodeBlock.background": "{{background_two}}",
    "progressBar.background": "{{blue}}",

    "button.background": "{{blue}}",
    "button.foreground": "{{background}}",
    "button.hoverBackground": "{{bright_blue}}",
    "button.secondaryBackground": "{{surface}}",
    "button.secondaryForeground": "{{foreground}}",
    "button.secondaryHoverBackground": "{{very_dark}}",
    "checkbox.background": "{{background_two}}",
    "checkbox.border": "{{very_dark}}",
    "dropdown.background": "{{background_two}}",
    "dropdown.border": "{{very_dark}}",
    "input.background": "{{background_two}}",
    "input.border": "{{very_dark}}",
    "input.foreground": "{{foreground}}",
    "input.placeholderForeground": "{{black}}",
    "inputOption.activeBorder": "{{blue}}",
    "inputOption.activeBackground": "{{selection_primary}}",
    "inputValidation.errorBackground": "{{mix red background 0.82}}",
    "inputValidation.errorBorder": "{{red}}",
    "inputValidation.warningBackground": "{{mix caution_dim background 0.82}}",
    "inputValidation.warningBorder": "{{caution_dim}}",
    "inputValidation.infoBackground": "{{mix blue background 0.82}}",
    "inputValidation.infoBorder": "{{blue}}",
    "badge.background": "{{blue}}",
    "badge.foreground": "{{background}}",
    "scrollbar.shadow": "#00000000",
    "scrollbarSlider.background": "{{very_dark}}80",
    "scrollbarSlider.hoverBackground": "{{very_dark}}",
    "scrollbarSlider.activeBackground": "{{linenr}}",

    "list.activeSelectionBackground": "{{selection_primary}}",
    "list.activeSelectionForeground": "{{foreground}}",
    "list.inactiveSelectionBackground": "{{surface}}",
    "list.inactiveSelectionForeground": "{{foreground}}",
    "list.hoverBackground": "{{background_two}}",
    "list.focusOutline": "{{blue}}",
    "list.highlightForeground": "{{bright_blue}}",
    "list.errorForeground": "{{bright_red}}",
    "list.warningForeground": "{{caution}}",
    "tree.indentGuidesStroke": "{{very_dark}}",

    "activityBar.background": "{{background_two}}",
    "activityBar.foreground": "{{foreground}}",
    "activityBar.inactiveForeground": "{{linenr}}",
    "activityBar.border": "{{very_dark}}",
    "activityBar.activeBorder": "{{foreground}}",
    "activityBarBadge.background": "{{blue}}",
    "activityBarBadge.foreground": "{{background}}",
    "sideBar.background": "{{background_two}}",
    "sideBar.foreground": "{{foreground}}",
    "sideBar.border": "{{very_dark}}",
    "sideBarTitle.foreground": "{{bright_black}}",
    "sideBarSectionHeader.background": "{{background_two}}",
    "sideBarSectionHeader.foreground": "{{foreground}}",
    "sideBarSectionHeader.border": "{{very_dark}}",

    "titleBar.activeBackground": "{{background_two}}",
    "titleBar.activeForeground": "{{foreground}}",
    "titleBar.inactiveBackground": "{{background_two}}",
    "titleBar.inactiveForeground": "{{bright_black}}",
    "titleBar.border": "{{very_dark}}",
    "commandCenter.background": "{{background}}",
    "commandCenter.foreground": "{{bright_black}}",
    "commandCenter.border": "{{very_dark}}",
    "menu.background": "{{background_two}}",
    "menu.foreground": "{{foreground}}",
    "menu.selectionBackground": "{{selection_primary}}",
    "menu.separatorBackground": "{{very_dark}}",

    "editorGroup.border": "{{very_dark}}",
    "editorGroupHeader.tabsBackground": "{{background_two}}",
    "editorGroupHeader.tabsBorder": "{{very_dark}}",
    "tab.activeBackground": "{{background}}",
    "tab.activeForeground": "{{foreground}}",
    "tab.activeBorderTop": "{{blue}}",
    "tab.inactiveBackground": "{{background_two}}",
    "tab.inactiveForeground": "{{bright_black}}",
    "tab.border": "{{very_dark}}",
    "tab.hoverBackground": "{{background}}",
    "breadcrumb.foreground": "{{bright_black}}",
    "breadcrumb.focusForeground": "{{foreground}}",
    "breadcrumb.activeSelectionForeground": "{{foreground}}",
    "breadcrumbPicker.background": "{{background_two}}",

    "editor.background": "{{background}}",
    "editor.foreground": "{{foreground}}",
    "editorLineNumber.foreground": "{{linenr}}",
    "editorLineNumber.activeForeground": "{{blue}}",
    "editorCursor.foreground": "{{foreground}}",
    "editorCursor.background": "{{background}}",
    "editor.lineHighlightBackground": "{{cursorline}}",
    "editor.lineHighlightBorder": "#00000000",
    "editor.selectionBackground": "{{selection_primary}}",
    "editor.inactiveSelectionBackground": "{{selection_primary}}99",
    "editor.selectionHighlightBackground": "{{very_dark}}80",
    "editor.wordHighlightBackground": "{{very_dark}}80",
    "editor.wordHighlightStrongBackground": "{{very_dark}}",
    "editor.findMatchBackground": "{{caution_dim}}80",
    "editor.findMatchHighlightBackground": "{{caution_dim}}40",
    "editor.findRangeHighlightBackground": "{{background_two}}",
    "editor.rangeHighlightBackground": "{{background_two}}",
    "editor.foldBackground": "{{background_two}}",
    "editorBracketMatch.background": "{{background_two}}",
    "editorBracketMatch.border": "{{linenr}}",
    "editorWhitespace.foreground": "{{very_dark}}",
    "editorIndentGuide.background1": "{{very_dark}}",
    "editorIndentGuide.activeBackground1": "{{linenr}}",
    "editorRuler.foreground": "{{very_dark}}",
    "editorCodeLens.foreground": "{{bright_black}}",
    "editorLink.activeForeground": "{{bright_blue}}",
    "editorInlayHint.foreground": "{{bright_black}}",
    "editorInlayHint.background": "#00000000",
    "editorGutter.background": "{{background}}",
    "editorGutter.addedBackground": "{{green}}",
    "editorGutter.modifiedBackground": "{{caution_dim}}",
    "editorGutter.deletedBackground": "{{red}}",
    "editorError.foreground": "{{bright_red}}",
    "editorWarning.foreground": "{{caution}}",
    "editorInfo.foreground": "{{bright_blue}}",
    "editorHint.foreground": "{{bright_green}}",
    "editorOverviewRuler.border": "#00000000",
    "editorOverviewRuler.errorForeground": "{{red}}",
    "editorOverviewRuler.warningForeground": "{{caution_dim}}",
    "editorOverviewRuler.infoForeground": "{{blue}}",
    "editorWidget.background": "{{background_two}}",
    "editorWidget.border": "{{very_dark}}",
    "editorSuggestWidget.background": "{{background_two}}",
    "editorSuggestWidget.border": "{{very_dark}}",
    "editorSuggestWidget.selectedBackground": "{{selection_primary}}",
    "editorSuggestWidget.highlightForeground": "{{bright_blue}}",
    "editorHoverWidget.background": "{{background_two}}",
    "editorHoverWidget.border": "{{very_dark}}",
    "peekView.border": "{{blue}}",
    "peekViewEditor.background": "{{background_two}}",
    "peekViewResult.background": "{{background_two}}",
    "peekViewTitle.background": "{{background_two}}",
    "minimap.background": "{{background}}",

    "diffEditor.insertedTextBackground": "{{mix green background 0.7}}",
    "diffEditor.removedTextBackground": "{{mix red background 0.7}}",
    "diffEditor.insertedLineBackground": "{{mix green background 0.82}}",
    "diffEditor.removedLineBackground": "{{mix red background 0.82}}",
    "merge.currentHeaderBackground": "{{mix green background 0.7}}",
    "merge.currentContentBackground": "{{mix green background 0.82}}",
    "merge.incomingHeaderBackground": "{{mix blue background 0.7}}",
    "merge.incomingContentBackground": "{{mix blue background 0.82}}",

    "gitDecoration.addedResourceForeground": "{{bright_green}}",
    "gitDecoration.modifiedResourceForeground": "{{caution}}",
    "gitDecoration.deletedResourceForeground": "{{bright_red}}",
    "gitDecoration.renamedResourceForeground": "{{bright_blue}}",
    "gitDecoration.untrackedResourceForeground": "{{bright_green}}",
    "gitDecoration.ignoredResourceForeground": "{{linenr}}",
    "gitDecoration.conflictingResourceForeground": "{{bright_orange}}",

    "panel.background": "{{background}}",
    "panel.border": "{{very_dark}}",
    "panelTitle.activeForeground": "{{foreground}}",
    "panelTitle.inactiveForeground": "{{bright_black}}",
    "panelTitle.activeBorder": "{{foreground}}",
    "statusBar.background": "{{background_two}}",
    "statusBar.foreground": "{{bright_black}}",
    "statusBar.border": "{{very_dark}}",
    "statusBar.noFolderBackground": "{{background_two}}",
    "statusBar.debuggingBackground": "{{orange}}",
    "statusBar.debuggingForeground": "{{background}}",
    "statusBarItem.remoteBackground": "{{blue}}",
    "statusBarItem.remoteForeground": "{{background}}",
    "statusBarItem.hoverBackground": "{{very_dark}}",
    "notifications.background": "{{background_two}}",
    "notifications.border": "{{very_dark}}",
    "notificationCenterHeader.background": "{{background_two}}",
    "quickInput.background": "{{background_two}}",
    "quickInputList.focusBackground": "{{selection_primary}}",
    "pickerGroup.foreground": "{{bright_blue}}",
    "pickerGroup.border": "{{very_dark}}",

    "terminal.background": "{{background}}",
    "terminal.foreground": "{{foreground}}",
    "terminalCursor.foreground": "{{cursor_color}}",
    "terminal.selectionBackground": "{{selection_primary}}",
    "terminal.ansiBlack": "{{black}}",
    "terminal.ansiRed": "{{red}}",
    "terminal.ansiGreen": "{{green}}",
    "terminal.ansiYellow": "{{yellow}}",
    "terminal.ansiBlue": "{{blue}}",
    "terminal.ansiMagenta": "{{magenta}}",
    "terminal.ansiCyan": "{{cyan}}",
    "terminal.ansiWhite": "{{white}}",
    "terminal.ansiBrightBlack": "{{bright_black}}",
    "terminal.ansiBrightRed": "{{bright_red}}",
    "terminal.ansiBrightGreen": "{{bright_green}}",
    "terminal.ansiBrightYellow": "{{bright_yellow}}",
    "terminal.ansiBrightBlue": "{{bright_blue}}",
    "terminal.ansiBrightMagenta": "{{bright_magenta}}",
    "terminal.ansiBrightCyan": "{{bright_cyan}}",
    "terminal.ansiBrightWhite": "{{bright_white}}"
  },
  "tokenColors": [
    { "scope": ["comment", "punctuation.definition.comment", "comment.block.documentation"], "settings": { "foreground": "{{black}}", "fontStyle": "italic" } },
    { "scope": ["keyword", "storage", "storage.type", "storage.modifier", "keyword.control", "keyword.operator.new", "keyword.operator.expression", "variable.language"], "settings": { "foreground": "{{bright_red}}" } },
    { "scope": ["storage.type.function.arrow"], "settings": { "foreground": "{{foreground}}" } },
    { "scope": ["keyword.operator", "punctuation", "meta.brace", "variable", "variable.other", "variable.parameter", "meta.object-literal.key", "support.variable.property"], "settings": { "foreground": "{{foreground}}" } },
    { "scope": ["keyword.control.directive", "meta.preprocessor", "entity.name.function.preprocessor", "punctuation.special"], "settings": { "foreground": "{{bright_orange}}" } },
    { "scope": ["string", "string.quoted", "string.template", "punctuation.definition.string"], "settings": { "foreground": "{{bright_green}}" } },
    { "scope": ["string.regexp", "constant.character", "constant.character.escape", "constant.other.symbol"], "settings": { "foreground": "{{emphasis}}" } },
    { "scope": ["constant.numeric", "constant.numeric.decimal"], "settings": { "foreground": "{{bright_blue}}" } },
    { "scope": ["constant.language.boolean"], "settings": { "foreground": "{{emphasis}}" } },
    { "scope": ["constant", "constant.language", "variable.other.constant", "variable.other.enummember"], "settings": { "foreground": "{{bright_magenta}}" } },
    { "scope": ["entity.name.type", "entity.name.class", "entity.other.inherited-class", "support.type", "support.class", "storage.type.primitive", "support.type.primitive", "entity.name.namespace"], "settings": { "foreground": "{{bright_blue}}" } },
    { "scope": ["entity.name.function", "meta.function-call", "support.function", "entity.name.method", "meta.decorator", "entity.other.attribute-name"], "settings": { "foreground": "{{emphasis}}" } },
    { "scope": ["support.function.builtin", "support.function.console", "support.function.math"], "settings": { "foreground": "{{magenta}}" } },
    { "scope": ["entity.name.tag", "punctuation.definition.tag"], "settings": { "foreground": "{{bright_magenta}}" } },
    { "scope": ["entity.name.label"], "settings": { "foreground": "{{magenta}}" } },
    { "scope": ["markup.heading", "entity.name.section"], "settings": { "foreground": "{{bright_green}}", "fontStyle": "bold" } },
    { "scope": ["markup.bold"], "settings": { "foreground": "{{emphasis}}", "fontStyle": "bold" } },
    { "scope": ["markup.italic"], "settings": { "foreground": "{{emphasis}}", "fontStyle": "italic" } },
    { "scope": ["markup.strikethrough"], "settings": { "fontStyle": "strikethrough" } },
    { "scope": ["markup.underline.link", "string.other.link"], "settings": { "foreground": "{{bright_blue}}" } },
    { "scope": ["markup.inline.raw", "markup.fenced_code", "markup.raw"], "settings": { "foreground": "{{bright_magenta}}" } },
    { "scope": ["markup.quote"], "settings": { "foreground": "{{bright_green}}" } },
    { "scope": ["markup.list", "punctuation.definition.list.begin"], "settings": { "foreground": "{{bright_red}}" } },
    { "scope": ["markup.inserted", "meta.diff.header.to-file"], "settings": { "foreground": "{{bright_green}}" } },
    { "scope": ["markup.deleted", "meta.diff.header.from-file"], "settings": { "foreground": "{{bright_red}}" } },
    { "scope": ["markup.changed"], "settings": { "foreground": "{{caution}}" } },
    { "scope": ["invalid", "invalid.illegal"], "settings": { "foreground": "{{bright_red}}" } }
  ],
  "semanticTokenColors": {
    "namespace": "{{foreground}}",
    "class": "{{bright_blue}}",
    "interface": "{{bright_blue}}",
    "enum": "{{bright_blue}}",
    "type": "{{bright_blue}}",
    "typeParameter": "{{bright_magenta}}",
    "enumMember": "{{emphasis}}",
    "function": "{{emphasis}}",
    "method": "{{emphasis}}",
    "function.defaultLibrary": "{{magenta}}",
    "macro": "{{bright_orange}}",
    "variable": "{{foreground}}",
    "variable.readonly": "{{foreground}}",
    "variable.defaultLibrary": "{{bright_red}}",
    "parameter": "{{foreground}}",
    "property": "{{foreground}}",
    "decorator": "{{emphasis}}",
    "keyword": "{{bright_red}}",
    "number": "{{bright_blue}}",
    "string": "{{bright_green}}",
    "regexp": "{{emphasis}}",
    "comment": { "foreground": "{{black}}", "italic": true }
  }
}
endef

# VS Code gets its own screenshot script too. It runs a separate copy of
# VS Code with its own user data and extensions folders, so Darkstar is the
# only extension and your own settings aren't touched.
#
# Arguments: output file, window width and height in points.
define vscode_screenshot_sh
set -e
out="$PWD/$1"; width="$2"; height="$3"
title=$(printf '%s' "$THEME" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }')
darkstar="$PWD"
dir=$(mktemp -d /tmp/vscode.XXXX)
trap 'rm -rf "$dir"' EXIT

mkdir -p "$dir/user/User" "$dir/extensions"
ln -s "$darkstar/vscode" "$dir/extensions/henrycatalinismith.darkstar-0.1.0"
cat > "$dir/user/User/settings.json" <<JSON
{
  "workbench.colorTheme": "$title",
  "workbench.startupEditor": "none",
  "workbench.tips.enabled": false,
  "workbench.enableExperiments": false,
  "workbench.secondarySideBar.defaultVisibility": "hidden",
  "chat.disableAIFeatures": true,
  "telemetry.telemetryLevel": "off",
  "update.mode": "none",
  "extensions.autoCheckUpdates": false,
  "extensions.ignoreRecommendations": true,
  "security.workspace.trust.enabled": false,
  "git.openRepositoryInParentFolders": "never",
  "editor.minimap.enabled": false,
  "editor.stickyScroll.enabled": false,
  "editor.bracketPairColorization.enabled": false,
  "git.blame.statusBarItem.enabled": false,
  "editor.cursorBlinking": "solid",
  "editor.fontFamily": "Lilex",
  "editor.fontSize": 14,
  "terminal.integrated.fontFamily": "Lilex",
  "window.zoomLevel": 0,
  "window.restoreWindows": "none",
  "window.commandCenter": false
}
JSON

"/Applications/Visual Studio Code.app/Contents/MacOS/Code" \
  --user-data-dir "$dir/user" --extensions-dir "$dir/extensions" \
  --new-window --disable-workspace-trust \
  "$darkstar/repo" --goto "$darkstar/repo/src/cart.ts:24" > /dev/null 2>&1 &
pid=$!

window=
for i in $(seq 75); do
  window=$(osascript -l JavaScript -e "$WINDOW_ID_JS" "$pid")
  [ -n "$window" ] && break
  sleep 0.2
done
if [ -z "$window" ]; then
  echo "couldn't find the VS Code window" >&2
  kill "$pid"
  exit 1
fi

osascript -e "tell application \"System Events\" to tell (first process whose unix id is $pid) to set size of window 1 to {$width, $height}" > /dev/null 2>&1 ||
  echo "couldn't resize the VS Code window: does this terminal have Accessibility permission?" >&2

sleep 5
screencapture -x -o -l "$window" "$out" || {
  echo "screencapture failed: does this terminal have Screen Recording permission?" >&2
  kill "$pid"
  exit 1
}
kill "$pid"
wait "$pid" 2>/dev/null || true
endef

export PALETTE_darkstar := $(value darkstar_palette)
export PALETTE_lightstar := $(value lightstar_palette)
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
export OPENCODE_MODE := $(value opencode_mode)
export OPENCODE_SCENE := $(value opencode_scene)
export NVIM := $(value nvim)
export NVIM_SCENE := $(value nvim_scene)
export ZELLIJ := $(value zellij)
export ZELLIJ_SCENE := $(value zellij_scene)
export ZED := $(value zed)
export ZED_SCREENSHOT_SH := $(value zed_screenshot_sh)
export VSCODE_PACKAGE := $(value vscode_package)
export VSCODE_THEME := $(value vscode_theme)
export VSCODE_SCREENSHOT_SH := $(value vscode_screenshot_sh)
