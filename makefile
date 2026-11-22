# Darkstar
#
#   make          render every app's theme file
#   make check    fail if any colour is below its minimum contrast
#   make palette  print every colour with its contrast ratio
#   make install  copy the theme files into ~/.config
#   make clean    delete the rendered theme files
#
# Everything lives in this file: the palette, the templates for each app
# and the awk that renders them. Templates use {{name}} for a palette
# colour and {{mix a b t}} for a blend of two colours, where t is how far
# to move from a towards b.

OUTPUTS := \
	ghostty/darkstar.toml \
	helix/darkstar.toml \
	lazygit/darkstar.yml

all: $(OUTPUTS)

ghostty/darkstar.toml: TEMPLATE = GHOSTTY
helix/darkstar.toml: TEMPLATE = HELIX
lazygit/darkstar.yml: TEMPLATE = LAZYGIT

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
	mkdir -p ~/.config/ghostty/themes ~/.config/helix/themes ~/.config/lazygit
	install -m 644 ghostty/darkstar.toml ~/.config/ghostty/themes/darkstar.toml
	install -m 644 helix/darkstar.toml ~/.config/helix/themes/darkstar.toml
	install -m 644 lazygit/darkstar.yml ~/.config/lazygit/darkstar.yml

clean:
	rm -f $(OUTPUTS)

.PHONY: all check palette install clean

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

export PALETTE := $(value palette)
export RENDER_AWK := $(value common_awk)$(newline)$(value render_awk)
export CHECK_AWK := $(value common_awk)$(newline)$(value check_awk)
export GHOSTTY := $(value ghostty)
export HELIX := $(value helix)
export LAZYGIT := $(value lazygit)
