# 16x16 animated GIFs for the Divoom Timebox-Evo that show what a remote
# just did (script.divoom_cube_feedback in ./display.nix): one per kind of
# action, in its colour on black. Each plays its frames quickly and holds the
# last one, then loops while the script leaves it up.
#
# Shapes are drawn as rows ('#' full colour, '+' a third of it, '.' off) and
# extra pixels; the integration keeps each GIF frame's own duration.
{ pkgs }:

let
  python = pkgs.python3.withPackages (ps: [ ps.pillow ]);
in
{
  # Names the script accepts (`<name>.gif` in the media directory)
  names = [
    "light_on"
    "light_off"
    "brightness_up"
    "brightness_down"
    "volume_up"
    "volume_down"
    "speakers_on"
    "tv_on"
    "tv_off"
  ];

  gifs = pkgs.runCommand "divoom-animations" { nativeBuildInputs = [ python ]; } ''
    mkdir $out
    python3 - "$out" <<'EOF'
    import sys
    from PIL import Image

    out = sys.argv[1]
    STEP, HOLD = 120, 1200

    def blank():
        return [["."] * 16 for _ in range(16)]

    def stamp(grid, rows, x0=0, y0=0, only=None):
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                if c != ".":
                    grid[y0 + y][x0 + x] = only or c
        return grid

    def dots(grid, pixels, c="#"):
        for x, y in pixels:
            grid[y][x] = c
        return grid

    def render(grid, rgb):
        dim = tuple(v // 3 for v in rgb)
        img = Image.new("RGB", (16, 16))
        for y, row in enumerate(grid):
            for x, c in enumerate(row):
                img.putpixel((x, y), {"#": rgb, "+": dim, ".": (0, 0, 0)}[c])
        return img

    def save(name, frames, durations):
        assert len(frames) == len(durations), name
        frames[0].save(f"{out}/{name}.gif", save_all=True, append_images=frames[1:],
                       duration=durations, loop=0, disposal=1, optimize=False)

    def steps(name, grids, rgb):
        save(name, [render(g, rgb) for g in grids], [STEP] * (len(grids) - 1) + [HOLD])

    # Light: a bulb, lit from the inside, then rays
    bulb = [
        "......####......",
        ".....#++++#.....",
        "....#++++++#....",
        "....#++++++#....",
        "....#++++++#....",
        ".....#++++#.....",
        "......#++#......",
        "......####......",
        "......####......",
        ".......##.......",
    ]
    bulbAt = 3
    rays = [(7, 0), (8, 0), (1, 6), (2, 6), (13, 6), (14, 6), (3, 2), (2, 1), (12, 2), (13, 1)]

    def lamp(outline, inside, ray=None):
        g = blank()
        for y, row in enumerate(bulb):
            for x, c in enumerate(row):
                if c == "#" and outline:
                    g[bulbAt + y][x] = outline
                elif c == "+" and inside:
                    g[bulbAt + y][x] = inside
        return dots(g, rays, ray) if ray else g

    yellow = (255, 180, 40)
    lightOn = [lamp("+", None), lamp("#", None), lamp("#", "+"), lamp("#", "#"), lamp("#", "#", "+"), lamp("#", "#", "#")]
    steps("light_on", lightOn, yellow)
    steps("light_off", lightOn[::-1], yellow)

    # Brightness: a narrower bulb getting brighter or dimmer, an arrow moving
    # up or down beside it
    small = [
        "..####..",
        ".#++++#.",
        "#++++++#",
        "#++++++#",
        "#++++++#",
        ".#++++#.",
        "..#++#..",
        "..####..",
        "..####..",
        "...##...",
    ]
    arrowUp = ["..#..", ".###.", "#.#.#", "..#..", "..#..", "..#.."]

    def dimmer(inside, arrow, ay):
        g = blank()
        for y, row in enumerate(small):
            for x, c in enumerate(row):
                if c == "#":
                    g[3 + y][1 + x] = "#"
                elif c == "+" and inside:
                    g[3 + y][1 + x] = inside
        return stamp(g, arrow, 10, ay)

    ys = [8, 6, 4, 2]
    steps("brightness_up", [dimmer(None, arrowUp, ys[0]), dimmer("+", arrowUp, ys[1]), dimmer("+", arrowUp, ys[2]), dimmer("#", arrowUp, ys[3])], yellow)
    arrowDown = arrowUp[::-1]
    steps("brightness_down", [dimmer("#", arrowDown, ys[3]), dimmer("+", arrowDown, ys[2]), dimmer("+", arrowDown, ys[1]), dimmer(None, arrowDown, ys[0])], yellow)

    # Sound: a speaker and up to three waves
    speaker = [
        ".....#",
        "....##",
        "...#.#",
        "###..#",
        "#....#",
        "#....#",
        "###..#",
        "...#.#",
        "....##",
        ".....#",
    ]
    waves = [
        [(7, 6), (8, 7), (8, 8), (7, 9)],
        [(9, 4), (10, 5), (11, 6), (11, 7), (11, 8), (11, 9), (10, 10), (9, 11)],
        [(12, 2), (13, 3), (14, 4), (15, 5), (15, 6), (15, 7), (15, 8), (15, 9), (15, 10), (14, 11), (13, 12), (12, 13)],
    ]

    def sound(n, body="#"):
        g = stamp(blank(), speaker, 0, 3, body)
        for w in waves[:n]:
            dots(g, w)
        return g

    blue = (80, 170, 255)
    steps("volume_up", [sound(0), sound(1), sound(2), sound(3)], blue)
    steps("volume_down", [sound(3), sound(2), sound(1), sound(0)], blue)
    steps("speakers_on", [sound(0, "+"), sound(0), sound(1), sound(2), sound(3)], (40, 200, 110))

    # TV: the screen opening from a line, a play sign on it, or closing to a dot
    def tv(rows=0, play=False, dot=False):
        g = blank()
        for x in range(16):
            g[2][x] = g[12][x] = "#"
        for y in range(2, 13):
            g[y][0] = g[y][15] = "#"
        stamp(g, ["......####......", "....########...."], 0, 13)
        for y in range(7 - rows, 8 + rows):
            for x in range(1, 15):
                g[y][x] = "+"
        if play:
            dots(g, [(6, y) for y in range(4, 11)] + [(7, y) for y in range(5, 10)] + [(8, y) for y in range(6, 9)] + [(9, 7)])
        if dot:
            dots(g, [(7, 7), (8, 7)])
        return g

    violet = (140, 100, 255)
    tvOn = [tv(0), tv(1), tv(2), tv(3), tv(4), tv(4, play=True)]
    steps("tv_on", [tv(-1)] + tvOn, violet)
    steps("tv_off", [tv(4), tv(2), tv(0), tv(-1, dot=True), tv(-1)], violet)
    EOF
  '';
}
