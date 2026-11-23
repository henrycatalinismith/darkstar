# Darkstar
#
#   make          render every app's theme file
#   make check    fail if any colour is below its minimum contrast
#   make palette  print every colour with its contrast ratio
#   make swatches draw every colour into screenshots/<theme>/swatch.svg
#   make install  copy the theme files into ~/.config
#   make repo     build ./repo, a test git repo with fixed dates
#   make screenshots  capture each app in Ghostty (macOS only)
#   make clean    delete the rendered theme files and ./repo
#
# Everything lives in this file: the palettes, the templates for each app
# and the awk that renders them. Templates use {{red300}}, {{bright_red}}
# and so on for a palette colour. Each theme gets its own copy of every
# file, rendered from the same templates with that theme's palette.
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
	$(THEMES:%=nvim/colors/%.lua) \
	$(THEMES:%=zellij/%.kdl) \
	$(THEMES:%=zed/%.json) \
	vscode/package.json \
	$(THEMES:%=vscode/%-color-theme.json)

all: $(OUTPUTS) lazygit/darkstar.yml opencode/darkstar.json firefox/darkstar.xpi $(THEMES:%=chrome/%/manifest.json)

ghostty/%.toml: TEMPLATE = GHOSTTY
helix/%.toml: TEMPLATE = HELIX
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

# Lazygit picks gui.darkTheme or gui.lightTheme from the terminal's
# background, so this one file holds Darkstar's palette as the dark theme
# and Lightstar's as the light.
lazygit/darkstar.yml: makefile
	@mkdir -p $(@D)
	@{ echo 'gui:'; \
		echo '  darkTheme:'; printf '%s\n' "$$LAZYGIT" | PALETTE="$$PALETTE_darkstar" awk "$$RENDER_AWK" && \
		echo '  lightTheme:'; printf '%s\n' "$$LAZYGIT" | PALETTE="$$PALETTE_lightstar" awk "$$RENDER_AWK"; \
	} > $@.tmp || { rm -f $@.tmp; exit 1; }
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

# Firefox themes are add-ons. Like OpenCode, one add-on holds both modes and
# Firefox picks between them from the system's light or dark setting. Firefox
# has no themes folder to copy this into, so make install skips it. Load
# firefox/manifest.json from about:debugging to try it, or sign
# firefox/darkstar.xpi at addons.mozilla.org to install it for good.
firefox/manifest.json: makefile
	@mkdir -p $(@D)
	@{ printf '%s\n' "$$FIREFOX"; \
		echo '  "theme": {'; printf '%s\n' "$$FIREFOX_COLORS" | PALETTE="$$PALETTE_lightstar" awk "$$RENDER_AWK" && echo '  },'; \
		echo '  "dark_theme": {'; printf '%s\n' "$$FIREFOX_COLORS" | PALETTE="$$PALETTE_darkstar" awk "$$RENDER_AWK" && echo '  }'; \
		echo '}'; \
	} > $@.tmp || { rm -f $@.tmp; exit 1; }
	@mv $@.tmp $@
	@echo "  $@"

firefox/darkstar.xpi: firefox/manifest.json
	@rm -f $@
	@cd firefox && zip -q -X darkstar.xpi manifest.json
	@echo "  $@"

# Chrome themes can't switch with the system's light or dark mode, so
# Darkstar and Lightstar are separate themes, each in its own folder. Load
# one unpacked from chrome://extensions with developer mode on.
CHROME_OUTPUTS := $(THEMES:%=chrome/%/manifest.json)

chrome/%/manifest.json: makefile
	@mkdir -p $(@D)
	@printf '%s\n' "$$CHROME" | PALETTE="$$PALETTE_$*" awk "$$RENDER_AWK" > $@.tmp || { rm -f $@.tmp; exit 1; }
	@mv $@.tmp $@
	@echo "  $@"

check:
	@for t in $(THEMES); do echo "$$t"; PALETTE=$$(printenv "PALETTE_$$t") awk -v strict=1 "$$CHECK_AWK" || exit 1; done

palette:
	@for t in $(THEMES); do echo "$$t"; PALETTE=$$(printenv "PALETTE_$$t") awk -v strict=0 "$$CHECK_AWK"; done

swatches: $(THEMES:%=screenshots/%/swatch.svg)

screenshots/%/swatch.svg: makefile
	@mkdir -p $(@D)
	@PALETTE="$$PALETTE_$*" awk "$$SWATCH_AWK" > $@.tmp || { rm -f $@.tmp; exit 1; }
	@mv $@.tmp $@
	@echo "  $@"

VSCODE_EXTENSION := ~/.vscode/extensions/henrycatalinismith.darkstar-0.1.0

install: all
	mkdir -p ~/.config/ghostty/themes ~/.config/helix/themes ~/.config/lazygit ~/.config/nvim/colors ~/.config/opencode/themes ~/.config/zellij/themes ~/.config/zed/themes $(VSCODE_EXTENSION)
	for t in $(THEMES); do \
		install -m 644 ghostty/$$t.toml ~/.config/ghostty/themes/$$t.toml && \
		install -m 644 helix/$$t.toml ~/.config/helix/themes/$$t.toml && \
		install -m 644 nvim/colors/$$t.lua ~/.config/nvim/colors/$$t.lua && \
		install -m 644 zellij/$$t.kdl ~/.config/zellij/themes/$$t.kdl && \
		install -m 644 zed/$$t.json ~/.config/zed/themes/$$t.json && \
		install -m 644 vscode/$$t-color-theme.json $(VSCODE_EXTENSION)/$$t-color-theme.json || exit 1; \
	done
	install -m 644 lazygit/darkstar.yml ~/.config/lazygit/darkstar.yml
	install -m 644 opencode/darkstar.json ~/.config/opencode/themes/darkstar.json
	install -m 644 vscode/package.json $(VSCODE_EXTENSION)/package.json

clean:
	rm -f $(OUTPUTS) lazygit/darkstar.yml opencode/darkstar.json firefox/manifest.json firefox/darkstar.xpi $(THEMES:%=chrome/%/manifest.json)
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
screenshots/%/lazygit.png: ghostty/%.toml lazygit/darkstar.yml repo makefile
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

.PHONY: all check palette swatches install clean screenshots

# Name, hex value and the minimum contrast ratio against the background.
# 4.5 is WCAG AA and 7 is WCAG AAA. A dash means the colour isn't used for
# text, so there's nothing to check. The first few rows aren't colours:
# they're the theme's file name, display name and dark or light, for the
# templates to use.
#
# Every colour comes in eight steps, and each step does the same job in
# both themes even though the hex values differ:
#
#   100  10:1    the strongest text
#   200  7:1     bright variants
#   300  4.5:1   normal variants
#   400  3:1     muted text and borders
#   500  tint    word highlights in diffs, search matches
#   600  tint    medium backgrounds
#   700  tint    diff lines and other backgrounds behind text
#   800  tint    the faintest backgrounds
#
# Gray is all text, stepping from 14:1 down to 1.4:1. Surface is the
# background scale: 200 is the background itself, 100 sits just behind it,
# and 300 to 800 rise through cursor lines, selections and borders. The
# text steps were found in OKLCH, keeping each hue and pushing its chroma
# as far as possible at the contrast target.
#
# The last rows are roles that name a step, so templates can ask for
# bright_red or cursorline and each theme decides what that means.
define darkstar_palette
name                  darkstar  -
title                 Darkstar  -
appearance            dark  -
gray100               #d4e5ea  14
gray200               #a9babf  9
gray300               #87979c  6
gray400               #728186  4.5
gray500               #607075  3.5
gray600               #4d5c60  2.6
gray700               #39484c  1.9
gray800               #263438  1.4
red100                #ffaba0  10
red200                #ff776b  7
red300                #f1302f  4.5
red400                #c80013  3
red500                #641617  -
red600                #521313  -
red700                #441211  -
red800                #381311  -
orange100             #feac97  10
orange200             #fe7958  7
orange300             #e24922  4.5
orange400             #ba2e01  3
orange500             #5f2a1d  -
orange600             #4a2219  -
orange700             #3b1b13  -
orange800             #2e1711  -
yellow100             #ecb93b  10
yellow200             #ca9a01  7
yellow300             #9f7903  4.5
yellow400             #7d5e02  3
yellow500             #4a3911  -
yellow600             #3a2d11  -
yellow700             #2e240c  -
yellow800             #241d0d  -
green100              #b3cc3b  10
green200              #95ab07  7
green300              #758705  4.5
green400              #5b6902  3
green500              #064310  -
green600              #07370e  -
green700              #092e0d  -
green800              #0d270f  -
cyan100               #55d4c9  10
cyan200               #2ab3a8  7
cyan300               #088e85  4.5
cyan400               #036f68  3
cyan500               #1b4440  -
cyan600               #183532  -
cyan700               #122a28  -
cyan800               #112220  -
blue100               #83c7ff  10
blue200               #39a8f8  7
blue300               #0484ce  4.5
blue400               #0367a2  3
blue500               #1c3f5b  -
blue600               #183246  -
blue700               #122738  -
blue800               #11202c  -
magenta100            #fea7c7  10
magenta200            #ff6ead  7
magenta300            #e5348c  4.5
magenta400            #bf0470  3
magenta500            #5f243e  -
magenta600            #4a1e31  -
magenta700            #3b1726  -
magenta800            #2e151f  -
surface100            #001117  -
surface200            #05181d  -
surface300            #002029  -
surface400            #002b36  -
surface500            #093540  -
surface600            #163f4b  -
surface700            #204a56  -
surface800            #475b62  -
background            surface200  -
foreground            gray100  -
black                 gray400  -
red                   red300  -
green                 green300  -
yellow                yellow300  -
blue                  blue300  -
magenta               magenta300  -
cyan                  cyan300  -
white                 gray200  -
orange                orange300  -
bright_black          gray300  -
bright_red            red200  -
bright_green          green200  -
bright_yellow         yellow200  -
bright_blue           blue200  -
bright_magenta        magenta200  -
bright_cyan           cyan200  -
bright_white          gray100  -
bright_orange         orange200  -
emphasis              bright_yellow  -
caution               bright_yellow  -
caution_dim           yellow  -
caution100            yellow100  -
caution200            yellow200  -
caution300            yellow300  -
caution400            yellow400  -
caution500            yellow500  -
caution600            yellow600  -
caution700            yellow700  -
caution800            yellow800  -
cursor_color          gray300  -
cursor_text           surface400  -
selection_background  surface400  -
selection_foreground  foreground  -
cursorline            surface400  -
surface_low           surface100  -
background_two        surface300  -
raised                surface300  -
surface               surface500  -
raised_high           surface500  -
selection_primary     surface600  -
raised_max            surface600  -
very_dark             surface700  -
linenr                surface800  -
tab_strip             surface100  -
tab_selected          surface400  -
endef

# Lightstar is Darkstar for light backgrounds.
#
# The background is an off-white halfway between Solarized's cream and the
# teal of the surfaces, so the cream doesn't clash with the teal cursor line
# and selection above it. The surface scale drifts from that tint towards
# teal as it gets deeper.
#
# Each accent is as saturated as its hue allows at each contrast target.
# Bright variants are darker here rather than lighter, because on a light
# background more contrast means closer to black.
#
# Green is shifted halfway from Solarized's olive towards true green, which
# keeps it recognisably green once it's dark enough to read.
#
# Readable yellow text can only be brown on a light background, so Lightstar
# avoids yellow text altogether. Its emphasis role, used for functions and
# the like, is cyan, and its caution roles are orange. Yellow itself is only
# for programs that print terminal colour 3.
define lightstar_palette
name                  lightstar  -
title                 Lightstar  -
appearance            light  -
gray100               #1b282d  14
gray200               #38474b  9
gray300               #526165  6
gray400               #65747a  4.5
gray500               #77868c  3.5
gray600               #8d9da3  2.6
gray700               #a8b8be  1.9
gray800               #c5d5db  1.4
red100                #820009  10
red200                #ad000f  7
red300                #e40018  4.5
red400                #ff5048  3
red500                #febcb6  -
red600                #ffcdc7  -
red700                #fed8d4  -
red800                #ffe1de  -
orange100             #781a01  10
orange200             #a12500  7
orange300             #d53501  4.5
orange400             #fe5429  3
orange500             #ffb8a6  -
orange600             #ffcbbe  -
orange700             #ffdbd2  -
orange800             #ffe6e0  -
yellow100             #4f3a01  10
yellow200             #6c5000  7
yellow300             #906c04  4.5
yellow400             #b48808  3
yellow500             #e6c887  -
yellow600             #eed6a4  -
yellow700             #f6e2b7  -
yellow800             #faebcc  -
green100              #2b4500  10
green200              #3c5d03  7
green300              #517e03  4.5
green400              #689e06  3
green500              #b5df8a  -
green600              #c4e9a1  -
green700              #d0efb4  -
green800              #dbf3c5  -
cyan100               #004641  10
cyan200               #025f5a  7
cyan300               #0a7f78  4.5
cyan400               #08a097  3
cyan500               #82dfd6  -
cyan600               #a3e8e1  -
cyan700               #b7f2eb  -
cyan800               #ccf7f2  -
blue100               #014069  10
blue200               #00588d  7
blue300               #0676ba  4.5
blue400               #0595ea  3
blue500               #9fd2fe  -
blue600               #b9deff  -
blue700               #cfe8fe  -
blue800               #deefff  -
magenta100            #7c0246  10
magenta200            #a60060  7
magenta300            #db0381  4.5
magenta400            #fe439e  3
magenta500            #fcb4ce  -
magenta600            #ffc7da  -
magenta700            #ffd8e5  -
magenta800            #fee5ed  -
surface100            #fafcf9  -
surface200            #f4f8f1  -
surface300            #e9f3f0  -
surface400            #deedee  -
surface500            #cee2e7  -
surface600            #bcd6df  -
surface700            #a9c3cb  -
surface800            #7f979f  -
background            surface200  -
foreground            gray100  -
black                 gray400  -
red                   red300  -
green                 green300  -
yellow                yellow300  -
blue                  blue300  -
magenta               magenta300  -
cyan                  cyan300  -
white                 gray200  -
orange                orange300  -
bright_black          gray300  -
bright_red            red200  -
bright_green          green200  -
bright_yellow         yellow200  -
bright_blue           blue200  -
bright_magenta        magenta200  -
bright_cyan           cyan200  -
bright_white          gray100  -
bright_orange         orange200  -
emphasis              cyan  -
caution               bright_orange  -
caution_dim           orange  -
caution100            orange100  -
caution200            orange200  -
caution300            orange300  -
caution400            orange400  -
caution500            orange500  -
caution600            orange600  -
caution700            orange700  -
caution800            orange800  -
cursor_color          gray300  -
cursor_text           surface400  -
selection_background  surface400  -
selection_foreground  foreground  -
cursorline            surface400  -
surface_low           surface100  -
background_two        surface300  -
raised                surface300  -
surface               surface500  -
raised_high           surface500  -
selection_primary     surface600  -
raised_max            surface600  -
very_dark             surface700  -
linenr                surface800  -
tab_strip             surface400  -
tab_selected          surface100  -
endef

define common_awk
function hexdigit(d) { return index("0123456789abcdef", tolower(d)) - 1 }
function channel(c, i) { return hexdigit(substr(c, i, 1)) * 16 + hexdigit(substr(c, i + 1, 1)) }

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
{
  line = $0
  while (match(line, /\{\{[^}]*\}\}/)) {
    n = split(substr(line, RSTART + 2, RLENGTH - 4), w, " ")
    if (n == 1) value = colour(w[1])
    else if (n == 2 && w[1] == "rgb") {
      value = colour(w[2])
      value = channel(value, 2) ", " channel(value, 4) ", " channel(value, 6)
    }
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
    r = contrast(hexes[name], colour("background"))
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

# Draws every step of every colour as an SVG grid. Text steps are drawn as
# text in their own colour and tints and surfaces as filled cells, with the
# hex value, contrast against the background and OKLCH value in each.
define swatch_awk
function oklch(c,   r, g, b, l, m, s, L, A, B, h) {
  r = linear(channel(c, 2)); g = linear(channel(c, 4)); b = linear(channel(c, 6))
  l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
  m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
  s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
  L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
  A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
  B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
  h = atan2(B, A) * 180 / 3.14159265358979
  if (h < 0) h += 360
  return sprintf("oklch(%.3f %.3f %.0f)", L, sqrt(A * A + B * B), h)
}

function label(x, y, text, fill) {
  printf "<text x=\"%d\" y=\"%d\" fill=\"%s\">%s</text>\n", x, y, fill, text
}

BEGIN {
  n = split("gray red orange yellow green cyan blue magenta surface", families, " ")
  bg = colour("background")
  fg = colour("foreground")
  left = 24; top = 24; head = 100; cw = 200; ch = 72
  width = left * 2 + head + cw * 8
  height = top * 2 + 50 + 30 + ch * n
  printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" font-family=\"Lilex, monospace\" font-size=\"13\">\n", width, height
  printf "<rect width=\"100%%\" height=\"100%%\" fill=\"%s\"/>\n", bg
  printf "<text x=\"%d\" y=\"%d\" fill=\"%s\" font-size=\"24\" font-weight=\"bold\">%s</text>\n", left, top + 26, fg, colour("title")
  y = top + 50 + 20
  for (s = 1; s <= 8; s++) label(left + head + (s - 1) * cw + 8, y, s "00", fg)
  for (row = 1; row <= n; row++) {
    fam = families[row]
    y = top + 50 + 30 + (row - 1) * ch
    label(left, y + 40, fam, fg)
    for (s = 1; s <= 8; s++) {
      c = colour(fam s "00")
      x = left + head + (s - 1) * cw
      text = c
      if (fam == "surface") text = fg
      else if (fam != "gray" && s > 4) text = colour(fam "200")
      if (text == c) {
        printf "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"8\" fill=\"%s\"/>\n", x + 4, y + 4, cw - 8, c
      } else {
        printf "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"%s\"/>\n", x + 4, y + 4, cw - 8, ch - 8, c
      }
      label(x + 10, y + 28, c, text)
      label(x + 10, y + 44, sprintf("%.2f:1", contrast(c, bg)), text)
      label(x + 10, y + 60, oklch(c), text)
    }
  }
  print "</svg>"
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
"ui.statusline" = { fg = "black", bg = "background" }
"ui.statusline.inactive" = { fg = "linenr", bg = "background" }
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
printf 'theme = "%s"\n\n[editor]\ncursorline = true\n' "$THEME" > "$SCENE_DIR/xdg/helix/config.toml"
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
        "100": "{{red100}}",
        "200": "{{red100}}",
        "300": "{{red200}}",
        "400": "{{bright_red}}",
        "500": "{{red}}",
        "600": "{{red500}}",
        "700": "{{red600}}",
        "800": "{{red800}}",
        "900": "{{red800}}"
      },
      "orange": {
        "100": "{{orange100}}",
        "200": "{{orange100}}",
        "300": "{{orange200}}",
        "400": "{{bright_orange}}",
        "500": "{{orange}}",
        "600": "{{orange500}}",
        "700": "{{orange600}}",
        "800": "{{orange800}}",
        "900": "{{orange800}}"
      },
      "yellow": {
        "100": "{{caution100}}",
        "200": "{{caution100}}",
        "300": "{{caution200}}",
        "400": "{{caution}}",
        "500": "{{caution_dim}}",
        "600": "{{caution500}}",
        "700": "{{caution600}}",
        "800": "{{caution800}}",
        "900": "{{caution800}}"
      },
      "green": {
        "100": "{{green100}}",
        "200": "{{green100}}",
        "300": "{{green200}}",
        "400": "{{bright_green}}",
        "500": "{{green}}",
        "600": "{{green500}}",
        "700": "{{green600}}",
        "800": "{{green800}}",
        "900": "{{green800}}"
      },
      "cyan": {
        "100": "{{cyan100}}",
        "200": "{{cyan100}}",
        "300": "{{cyan200}}",
        "400": "{{bright_cyan}}",
        "500": "{{cyan}}",
        "600": "{{cyan500}}",
        "700": "{{cyan600}}",
        "800": "{{cyan800}}",
        "900": "{{cyan800}}"
      },
      "blue": {
        "100": "{{blue100}}",
        "200": "{{blue100}}",
        "300": "{{blue200}}",
        "400": "{{bright_blue}}",
        "500": "{{blue}}",
        "600": "{{blue500}}",
        "700": "{{blue600}}",
        "800": "{{blue800}}",
        "900": "{{blue800}}"
      },
      "purple": {
        "100": "{{magenta100}}",
        "200": "{{magenta100}}",
        "300": "{{magenta200}}",
        "400": "{{bright_magenta}}",
        "500": "{{magenta}}",
        "600": "{{magenta500}}",
        "700": "{{magenta600}}",
        "800": "{{magenta800}}",
        "900": "{{magenta800}}"
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
        "added": "{{green700}}",
        "removed": "{{red700}}",
        "context": "$hue.neutral.700"
      },
      "highlight": {
        "added": "{{bright_green}}",
        "removed": "{{bright_red}}"
      },
      "lineNumber": {
        "text": "{{linenr}}",
        "background": {
          "added": "{{green800}}",
          "removed": "{{red800}}"
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
  diff_add = "{{green700}}",
  diff_delete = "{{red700}}",
  diff_change = "{{caution800}}",
  diff_text = "{{caution500}}",
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
        "conflict.background": "{{orange700}}",
        "conflict.border": "{{orange}}",
        "created": "{{bright_green}}",
        "created.background": "{{green700}}",
        "created.border": "{{green}}",
        "deleted": "{{bright_red}}",
        "deleted.background": "{{red700}}",
        "deleted.border": "{{red}}",
        "error": "{{bright_red}}",
        "error.background": "{{red700}}",
        "error.border": "{{red}}",
        "hidden": "{{linenr}}",
        "hint": "{{bright_black}}",
        "hint.background": "{{background_two}}",
        "hint.border": "{{very_dark}}",
        "ignored": "{{linenr}}",
        "info": "{{bright_blue}}",
        "info.background": "{{blue700}}",
        "info.border": "{{blue}}",
        "modified": "{{caution}}",
        "modified.background": "{{caution700}}",
        "modified.border": "{{caution_dim}}",
        "predictive": "{{bright_black}}",
        "renamed": "{{bright_blue}}",
        "success": "{{bright_green}}",
        "success.background": "{{green700}}",
        "success.border": "{{green}}",
        "unreachable": "{{bright_black}}",
        "warning": "{{caution}}",
        "warning.background": "{{caution700}}",
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
    "inputValidation.errorBackground": "{{red700}}",
    "inputValidation.errorBorder": "{{red}}",
    "inputValidation.warningBackground": "{{caution700}}",
    "inputValidation.warningBorder": "{{caution_dim}}",
    "inputValidation.infoBackground": "{{blue700}}",
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

    "diffEditor.insertedTextBackground": "{{green500}}",
    "diffEditor.removedTextBackground": "{{red500}}",
    "diffEditor.insertedLineBackground": "{{green700}}",
    "diffEditor.removedLineBackground": "{{red700}}",
    "merge.currentHeaderBackground": "{{green500}}",
    "merge.currentContentBackground": "{{green700}}",
    "merge.incomingHeaderBackground": "{{blue500}}",
    "merge.incomingContentBackground": "{{blue700}}",

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

# Firefox applies "theme" normally and "dark_theme" when the system is in
# dark mode, so Lightstar goes in the first and Darkstar in the second.
define firefox
{
  "manifest_version": 2,
  "name": "Darkstar",
  "description": "Solarized without the contrast bugs",
  "version": "0.1.0",
  "author": "Henry Catalini Smith",
  "homepage_url": "https://github.com/henrycatalinismith/darkstar",
  "browser_specific_settings": {
    "gecko": {
      "id": "darkstar@henrycatalinismith.se",
      "strict_min_version": "68.0"
    }
  },
endef

define firefox_colors
    "colors": {
      "frame": "{{tab_strip}}",
      "frame_inactive": "{{tab_strip}}",
      "tab_background_text": "{{bright_black}}",
      "tab_selected": "{{tab_selected}}",
      "tab_text": "{{foreground}}",
      "tab_line": "{{blue}}",
      "tab_loading": "{{blue}}",
      "tab_background_separator": "{{very_dark}}",
      "toolbar": "{{tab_selected}}",
      "toolbar_text": "{{foreground}}",
      "toolbar_top_separator": "{{very_dark}}",
      "toolbar_bottom_separator": "{{very_dark}}",
      "toolbar_vertical_separator": "{{very_dark}}",
      "toolbar_field": "{{tab_strip}}",
      "toolbar_field_text": "{{foreground}}",
      "toolbar_field_border": "{{very_dark}}",
      "toolbar_field_focus": "{{tab_strip}}",
      "toolbar_field_text_focus": "{{foreground}}",
      "toolbar_field_border_focus": "{{blue}}",
      "toolbar_field_highlight": "{{selection_primary}}",
      "toolbar_field_highlight_text": "{{foreground}}",
      "toolbar_field_separator": "{{very_dark}}",
      "button_background_hover": "{{surface}}",
      "button_background_active": "{{selection_primary}}",
      "icons": "{{foreground}}",
      "icons_attention": "{{bright_blue}}",
      "popup": "{{tab_strip}}",
      "popup_text": "{{foreground}}",
      "popup_border": "{{very_dark}}",
      "popup_highlight": "{{selection_primary}}",
      "popup_highlight_text": "{{foreground}}",
      "sidebar": "{{tab_strip}}",
      "sidebar_text": "{{foreground}}",
      "sidebar_border": "{{very_dark}}",
      "sidebar_highlight": "{{selection_primary}}",
      "sidebar_highlight_text": "{{foreground}}",
      "ntp_background": "{{tab_selected}}",
      "ntp_text": "{{foreground}}"
    }
endef

# Chrome themes want colours as [r, g, b] arrays, hence {{rgb ...}}.
define chrome
{
  "manifest_version": 3,
  "name": "{{title}}",
  "description": "Solarized without the contrast bugs",
  "version": "0.1.0",
  "homepage_url": "https://github.com/henrycatalinismith/darkstar",
  "theme": {
    "colors": {
      "frame": [{{rgb tab_strip}}],
      "frame_inactive": [{{rgb tab_strip}}],
      "frame_incognito": [{{rgb surface_low}}],
      "frame_incognito_inactive": [{{rgb surface_low}}],
      "background_tab": [{{rgb tab_strip}}],
      "background_tab_inactive": [{{rgb tab_strip}}],
      "background_tab_incognito": [{{rgb surface_low}}],
      "background_tab_incognito_inactive": [{{rgb surface_low}}],
      "toolbar": [{{rgb tab_selected}}],
      "toolbar_text": [{{rgb foreground}}],
      "toolbar_button_icon": [{{rgb foreground}}],
      "tab_text": [{{rgb foreground}}],
      "tab_background_text": [{{rgb bright_black}}],
      "tab_background_text_inactive": [{{rgb bright_black}}],
      "tab_background_text_incognito": [{{rgb bright_black}}],
      "tab_background_text_incognito_inactive": [{{rgb bright_black}}],
      "bookmark_text": [{{rgb foreground}}],
      "omnibox_background": [{{rgb tab_strip}}],
      "omnibox_text": [{{rgb foreground}}],
      "ntp_background": [{{rgb tab_selected}}],
      "ntp_text": [{{rgb foreground}}],
      "ntp_link": [{{rgb bright_blue}}],
      "ntp_header": [{{rgb blue}}],
      "button_background": [{{rgb tab_strip}}]
    }
  }
}
endef

export PALETTE_darkstar := $(value darkstar_palette)
export PALETTE_lightstar := $(value lightstar_palette)
export RENDER_AWK := $(value common_awk)$(newline)$(value render_awk)
export CHECK_AWK := $(value common_awk)$(newline)$(value check_awk)
export SWATCH_AWK := $(value common_awk)$(newline)$(value swatch_awk)
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
export FIREFOX := $(value firefox)
export FIREFOX_COLORS := $(value firefox_colors)
export CHROME := $(value chrome)
