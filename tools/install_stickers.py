#!/usr/bin/env python3
"""
Drop PNGs in a folder, run this, done.

Every sticker in Aura is one universal PNG in its own `.imageset`. That is a
three-line `Contents.json` and a file, which is exactly the kind of work nobody
should do by hand forty times. Naming a file after the asset it replaces is the
whole interface.

    python3 tools/install_stickers.py

Replacing an existing asset changes NOTHING in code: the imageset keeps its
name, so every `Image("StreakFireIcon")` already points at the new art. A file
whose name doesn't match an existing asset creates a new imageset, and that is
the only case where code has to be touched.

Processed files move to `done/` so a re-run after adding two more only does the
two.
"""
import json
import shutil
import struct
import sys
from pathlib import Path

DROP = Path(sys.argv[1] if len(sys.argv) > 1 else Path.home() / "Desktop/aura-stickers")
CATALOG = Path(__file__).resolve().parent.parent / "Aura iOS/Aura iOS/Assets.xcassets"
# Nav renders at 40pt, so 120px at 3x. 256 leaves room to grow without
# reshooting art, which is the mistake that costs a whole round trip.
MIN_PX = 256


def png_size(path: Path):
    """Width and height straight from the IHDR chunk — no Pillow, no install."""
    with path.open("rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def main():
    if not DROP.exists():
        print(f"no drop folder at {DROP}")
        return
    if not CATALOG.exists():
        print(f"no asset catalog at {CATALOG}")
        return

    files = sorted(p for p in DROP.glob("*.png") if p.is_file())
    if not files:
        print(f"nothing to install in {DROP}")
        return

    done = DROP / "done"
    done.mkdir(exist_ok=True)
    replaced, created, warned = [], [], []

    for src in files:
        name = src.stem
        imageset = CATALOG / f"{name}.imageset"
        existed = imageset.exists()
        imageset.mkdir(exist_ok=True)

        size = png_size(src)
        if size and min(size) < MIN_PX:
            warned.append(f"{name} is {size[0]}x{size[1]} — under {MIN_PX}px, will soften when scaled up")

        # One file per imageset. Anything left from the old art goes, or a
        # renamed PNG would sit there unreferenced and ship in the bundle.
        for old in imageset.glob("*.png"):
            old.unlink()
        shutil.copy2(src, imageset / f"{name}.png")

        (imageset / "Contents.json").write_text(json.dumps({
            "images": [{"filename": f"{name}.png", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
        }, indent=2) + "\n")

        (replaced if existed else created).append(name)
        shutil.move(str(src), str(done / src.name))

    if replaced:
        print(f"replaced ({len(replaced)}) — no code change needed:")
        for n in replaced:
            print(f"  {n}")
    if created:
        print(f"\nNEW ({len(created)}) — these need wiring up in code:")
        for n in created:
            print(f"  {n}")
    regenerate_picker()

    if warned:
        print("\nwarnings:")
        for w in warned:
            print(f"  {w}")
    print(f"\noriginals moved to {done}")


PICKER = Path(__file__).resolve().parent.parent / "Aura iOS/Aura iOS/Features/AddHabit/StickerPickerSheet.swift"
# Chrome, not stickers: nothing a habit can wear.
CHROME = {
    "AuraNavHome", "AuraNavStats", "AuraNavBlockLock", "AuraNavProfileFox",
    "AuraNavHomeLock", "AuraBlockedAppsLock", "AuraAppIcon", "AuraLogo",
    # A state illustration, not something a habit can wear.
    "FoxEmptyState",
    "FoxPhotoProofHero",
    "FoxCameraRepsHero",
    "FoxLockInHero",
    "FoxPassiveIncomeHero",
    "FoxLockInExtremeFocus",
    "FoxLockInAppsToBlock",
    "FoxLockInFocusLength",
    "FoxFocusLengthPhoto",
    "FoxHowItWorks",
}
GENERIC = ["AuraCoinIcon", "EarnCardIcon", "ScrollCardIcon", "StreakFireIcon"]
METHODS = ["FoxPhotoProof", "FoxCameraReps", "FoxDeepFocus", "FoxAppleHealth"]


def regenerate_picker():
    """Rewrite `StickerCatalog.all` from what is actually in the catalogue.

    Hand-maintained, this list silently fell fourteen stickers behind — every
    exercise, every Health metric, and the three habits added most recently
    were all missing, because adding art and adding it to the picker were two
    separate jobs and only one of them was ever remembered.
    """
    if not PICKER.exists():
        return
    if "Curated active sticker assets" in PICKER.read_text():
        print("Picker is curated: review new assets for usage, duplicates, alpha bounds and category before adding.")
        return
    names = {d.name[: -len(".imageset")] for d in CATALOG.iterdir()
             if d.name.endswith(".imageset")}
    usable = {n for n in names if n.startswith("Fox") and not n.startswith("tired_fox")}
    usable |= {n for n in GENERIC if n in names}
    usable -= CHROME

    habits = sorted(n for n in usable if n.startswith("FoxHabit"))
    rest = sorted(usable - set(habits) - set(GENERIC) - set(METHODS))
    ordered = ([n for n in GENERIC if n in usable]
               + [n for n in METHODS if n in usable] + habits + rest)

    lines = []
    for i in range(0, len(ordered), 4):
        lines.append("        " + " ".join(f'"{n}",' for n in ordered[i:i + 4]))
    body = "\n".join(lines)

    text = PICKER.read_text()
    start = text.index("    static let all: [String] = [")
    end = text.index("    ]", start) + len("    ]")
    generated = ("    /// GENERATED by tools/install_stickers.py — do not hand-edit.\n"
                 "    /// Derived from the asset catalogue so it cannot fall behind the art.\n"
                 "    static let all: [String] = [\n" + body + "\n    ]")
    PICKER.write_text(text[:start] + generated + text[end:])
    print(f"\npicker regenerated: {len(ordered)} stickers")


if __name__ == "__main__":
    main()
