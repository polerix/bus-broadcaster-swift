#!/usr/bin/env python3
"""
BusBroadcaster Crew Avatar Generator
Uses Google Gemini Imagen-3 to render portrait art for each character.

Usage:
    pip install google-generativeai
    export GEMINI_API_KEY="your-key-here"
    python3 scripts/generate_avatars.py

Output: BusBroadcaster/Resources/Avatars/*.png
"""

import os, sys, pathlib

try:
    import google.generativeai as genai
except ImportError:
    sys.exit("Run: pip install google-generativeai")

API_KEY = os.environ.get("GEMINI_API_KEY", "")
if not API_KEY:
    sys.exit("Set GEMINI_API_KEY environment variable first.\nexport GEMINI_API_KEY=your_key_here")

genai.configure(api_key=API_KEY)

# ── Character portrait prompts ──────────────────────────────────────────────────
CHARACTERS = [
    {
        "id": "dolores",
        "name": "Dolores",
        "prompt": (
            "Portrait of Dolores, a sharp-eyed woman in her 40s, dispatch operator of a "
            "pirate radio bus crew. She wears a vintage military-surplus headset around her "
            "neck, hair pulled back severely, crow's feet earned not regretted, expression "
            "of controlled urgency. Warm amber lighting from control panel LEDs. "
            "Half-shadow, cinematic. Illustrated in a bold graphic novel style with deep "
            "earth tones — ochre, rust, midnight blue. Bust portrait, square format."
        ),
    },
    {
        "id": "soren",
        "name": "Soren",
        "prompt": (
            "Portrait of Soren, a wiry androgynous DJ in their late 20s, running pirate UHF "
            "radio from a converted bus. They have asymmetric bleached hair, oversized "
            "noise-cancelling headphones around neck, fingers ink-stained from signal logs. "
            "Expression: perpetually agitated brilliance, eyes scanning invisible frequencies. "
            "Cyan and violet neon glow from mixing board. Graphic novel style, electric "
            "palette — electric blue, magenta, static grey. Square bust portrait."
        ),
    },
    {
        "id": "priya",
        "name": "Priya",
        "prompt": (
            "Portrait of Priya, calm South Asian woman mid-30s, technical operator aboard a "
            "pirate broadcast bus. She wears a weathered utility vest covered in cable clips "
            "and signal meters, hair in a practical bun with a pencil through it. "
            "Expression: quiet competence, slightly tired, deeply focused. "
            "Green phosphor glow from oscilloscope screens. Graphic novel style, palette of "
            "forest green, bone white, dark steel. Square bust portrait."
        ),
    },
    {
        "id": "marcus",
        "name": "Marcus",
        "prompt": (
            "Portrait of Marcus, a large deliberate Black man in his 50s, night driver of "
            "a pirate broadcast bus. He wears a worn leather jacket, grey at the temples, "
            "expression of absolute stillness — the calm centre of chaos. "
            "Lit only by dashboard instruments: amber and red dials. Deep shadow. "
            "Graphic novel style, palette of mahogany, amber, coal black. Square bust portrait."
        ),
    },
    {
        "id": "felix",
        "name": "Felix",
        "prompt": (
            "Portrait of Felix, lean anxious white man late 20s, signal analyst and social "
            "media scanner on a pirate radio bus. He has wire-rim glasses, several browser "
            "tabs reflected in the lenses, hoodie with cable management clips on the chest. "
            "Expression: perpetual low-grade alarm, processing too many feeds at once. "
            "Blue-white monitor glow, sharp shadows. Graphic novel style, cold palette: "
            "ice blue, pale yellow, deep navy. Square bust portrait."
        ),
    },
    {
        "id": "yael",
        "name": "Yael",
        "prompt": (
            "Portrait of Yael, a compact mechanically-gifted woman late 20s, bus systems "
            "engineer on a pirate broadcast rig. She has engine grease on her forearm, safety "
            "goggles pushed up on her forehead, expression of pragmatic pride. Wears coveralls "
            "with embroidered bus schematic patch. Warm tungsten work light from below. "
            "Graphic novel style, warm industrial palette: warm grey, burnt orange, oil-stain "
            "purple. Square bust portrait."
        ),
    },
    {
        "id": "nadia",
        "name": "Nadia",
        "prompt": (
            "Portrait of Nadia, mysterious outside correspondent of a pirate radio bus crew. "
            "She appears through a chain-link fence gap, face half-scarf-wrapped, only sharp "
            "dark eyes and a handheld radio visible. Unknown origin, known only by callsign. "
            "Rainy night. Graphic novel style with heavy ink lines, palette of wet asphalt "
            "grey, red signal light, deep shadow. Square bust portrait."
        ),
    },
    {
        "id": "prophet",
        "name": "Prophet",
        "prompt": (
            "Portrait of Prophet, a weathered street philosopher in his 60s who contacts the "
            "pirate radio bus from pay phones and rooftops. Long grey dreadlocks, army surplus "
            "coat covered in hand-written frequency notes, eyes that have seen too much and "
            "somehow remained kind. Expression: serene dangerous wisdom. Pay phone booth light, "
            "rain-wet streets behind. Graphic novel style, palette of sepia, electric green, "
            "deep shadow. Square bust portrait."
        ),
    },
    {
        "id": "kobold",
        "name": "Kobold",
        "prompt": (
            "Portrait of the Kobold — a small mythic trickster creature that haunts the pirate "
            "broadcast bus. Neither fully visible nor fully hidden. A glinting eye in deep shadow, "
            "small clawed hand gripping a transmission dial, suggestion of scales and old leather, "
            "impossible to categorise. Expression: amused omniscience. Signal static ripples around "
            "it. Graphic novel style, palette of void black, signal green, spectral white. "
            "Square portrait, creature emerges from lower-left darkness."
        ),
    },
    {
        "id": "detective",
        "name": "Detective Morrow",
        "prompt": (
            "Portrait of Detective Morrow, a tenacious plainclothes detective who hunts the "
            "pirate bus. Sharp-featured man in his 40s, trench coat, radio scanner in breast "
            "pocket, photo of the bus taped to inside of jacket. Expression: patient obsession, "
            "close but not close enough. Grey overcast daylight, city blurred behind. "
            "Graphic novel style, palette of cold grey, bureaucratic beige, red alert. "
            "Square bust portrait."
        ),
    },
]

# ── Output ──────────────────────────────────────────────────────────────────────
BASE = pathlib.Path(__file__).parent.parent
OUT_DIR = BASE / "BusBroadcaster" / "Resources" / "Avatars"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def generate_avatar(char: dict) -> bool:
    name = char["name"]
    out_path = OUT_DIR / f"{char['id']}.png"
    print(f"  {name}...", end=" ", flush=True)
    try:
        response = genai.generate_images(
            model="imagen-3.0-generate-002",
            prompt=char["prompt"],
            number_of_images=1,
            aspect_ratio="1:1",
            safety_filter_level="block_only_high",
            person_generation="allow_adult",
        )
        img = response.images[0]
        with open(out_path, "wb") as f:
            f.write(img._image_bytes)
        print(f"✓  → {out_path.name}")
        return True
    except Exception as e:
        print(f"✗  {e}")
        return False


if __name__ == "__main__":
    print(f"\n🎨  BusBroadcaster Avatar Generator  (Gemini Imagen-3)")
    print(f"    Output → {OUT_DIR}\n")
    ok = sum(generate_avatar(c) for c in CHARACTERS)
    print(f"\n{'✅' if ok == len(CHARACTERS) else '⚠️ '} {ok}/{len(CHARACTERS)} avatars generated.")
    if ok > 0:
        print(f"\n   Next steps:")
        print(f"   1. Open BusBroadcaster.xcodeproj")
        print(f"   2. Drag Avatars/ folder into Xcode → Resources group")
        print(f"   3. Reference in CharacterSprite.swift as Image(character.name.lowercased())")
