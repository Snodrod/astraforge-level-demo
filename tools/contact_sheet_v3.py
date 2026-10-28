"""contact_sheet_v3.png: по кадру из середины каждого клипа shots/v3/*.mp4 с подписью имени и длительности."""
import glob, os, subprocess, json
from PIL import Image, ImageDraw, ImageFont
D = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "shots", "v3")
clips = sorted(glob.glob(os.path.join(D, "*.mp4")))
tw, th = 480, 270
cols = 4
rows = (len(clips) + cols - 1) // cols
sheet = Image.new("RGB", (cols * tw, rows * (th + 28)), (24, 26, 30))
dr = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("arial.ttf", 18)
except Exception:
    font = ImageFont.load_default()
for i, c in enumerate(clips):
    dur = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", c]).decode().strip())
    tmp = os.path.join(D, "check", "_cs.png")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", str(dur * 0.5), "-i", c, "-frames:v", "1", tmp], check=True)
    im = Image.open(tmp).convert("RGB").resize((tw, th))
    x, y = (i % cols) * tw, (i // cols) * (th + 28)
    sheet.paste(im, (x, y + 28))
    dr.text((x + 6, y + 4), "%s  %.1f с" % (os.path.basename(c)[:-4], dur), fill=(235, 235, 235), font=font)
sheet.save(os.path.join(D, "contact_sheet_v3.png"))
print("contact_sheet_v3.png", len(clips), "клипов")
