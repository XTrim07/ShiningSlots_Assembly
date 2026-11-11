# gen_simboluri.py - generates 9 BMPs 128x128 similar to Shining Crown
# + 3 buttons with text (SPIN / DOUBLE / TAKE WIN) like the real machine
# original images, no copyright, classic fruit style + playing cards
# run: python3 gen_simboluri.py (creates assets/*.bmp)
from PIL import Image, ImageDraw, ImageFont
import os

MARIME = 128
DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets")

FUNDAL = (42, 12, 74)        # dark purple like the machine
CHENAR = (255, 215, 0)       # gold

def baza():
    # background + golden border, like a slot cell
    img = Image.new("RGB", (MARIME, MARIME), FUNDAL)
    d = ImageDraw.Draw(img)
    d.rectangle([2, 2, MARIME-3, MARIME-3], outline=CHENAR, width=4)
    d.rectangle([8, 8, MARIME-9, MARIME-9], fill=(58, 20, 95))
    return img, d

def salveaza(nume, img):
    os.makedirs(DIR, exist_ok=True)
    cale = os.path.join(DIR, nume)
    img.save(cale, "BMP")
    print("scris: " + cale)

def coroana():
    img, d = baza()
    # golden crown body
    d.polygon([(24,88),(24,52),(38,64),(52,40),(64,62),(76,40),(90,64),(104,52),(104,88)], fill=(255,200,20), outline=(150,100,0))
    d.rectangle([24,88,104,98], fill=(255,200,20), outline=(150,100,0))
    # red jewels
    for x in (38,52,64,76,90):
        d.ellipse([x-5,72,x+5,82], fill=(220,20,60), outline=(120,0,20))
    # little cross on top
    d.rectangle([60,22,68,44], fill=(255,220,60), outline=(150,100,0))
    d.rectangle([52,30,76,38], fill=(255,220,60), outline=(150,100,0))
    # circles on the tips
    for x in (24,52,76,104):
        d.ellipse([x-5,45,x+5,55], fill=(255,230,100), outline=(150,100,0))
    salveaza("coroana.bmp", img)

def pepene():
    img, d = baza()
    # watermelon slice: green rind, white middle, red flesh
    d.pieslice([14,30,114,120], 10, 170, fill=(30,160,50))   # rind
    d.pieslice([20,36,108,114], 10, 170, fill=(240,240,230)) # white
    d.pieslice([26,42,102,108], 10, 170, fill=(230,30,50))   # flesh
    # seeds
    for x,y in ((50,70),(64,78),(78,70),(57,88),(71,92)):
        d.ellipse([x-3,y-4,x+3,y+4], fill=(20,20,20))
    salveaza("pepene.bmp", img)

def pruna():
    img, d = baza()
    # purple plum body
    d.ellipse([34,44,94,104], fill=(110,40,160), outline=(60,10,90))
    d.ellipse([44,52,72,80], fill=(160,100,220))  # highlight
    # stem + leaf
    d.line([64,44,70,30], fill=(90,60,20), width=5)
    d.ellipse([70,24,96,42], fill=(40,170,60), outline=(20,100,30))
    salveaza("pruna.bmp", img)

def portocala():
    img, d = baza()
    d.ellipse([30,42,98,108], fill=(255,140,0), outline=(180,80,0))
    d.ellipse([40,50,62,72], fill=(255,200,120))  # highlight
    d.line([64,42,64,30], fill=(90,60,20), width=5)
    d.ellipse([64,22,90,40], fill=(50,180,60), outline=(20,100,30))
    salveaza("portocala.bmp", img)

def banana():
    img, d = baza()
    # banana: thick yellow crescent
    d.arc([20,30,108,100], 20, 160, fill=(255,220,30), width=22)
    d.arc([20,30,108,100], 20, 160, fill=(200,150,0), width=2)
    # brown tips
    d.ellipse([22,62,34,74], fill=(110,70,20))
    d.ellipse([94,62,106,74], fill=(110,70,20))
    salveaza("banana.bmp", img)

def cirese():
    img, d = baza()
    # stems
    d.line([64,30,48,70], fill=(110,70,30), width=5)
    d.line([64,30,80,68], fill=(110,70,30), width=5)
    d.ellipse([64,22,92,40], fill=(50,180,60), outline=(20,100,30))
    # 2 red cherries with highlight
    d.ellipse([30,68,62,100], fill=(220,20,50), outline=(130,0,20))
    d.ellipse([66,66,98,98], fill=(220,20,50), outline=(130,0,20))
    d.ellipse([36,74,46,84], fill=(255,150,170))
    d.ellipse([72,72,82,82], fill=(255,150,170))
    salveaza("cirese.bmp", img)

def stea():
    img, d = baza()
    # golden scatter-style star
    cx, cy, r1, r2 = 64, 66, 40, 16
    import math
    pct = []
    for i in range(10):
        r = r1 if i % 2 == 0 else r2
        a = -math.pi/2 + i * math.pi/5
        pct.append((cx + r*math.cos(a), cy + r*math.sin(a)))
    d.polygon(pct, fill=(255,210,30), outline=(170,110,0))
    d.ellipse([56,58,72,74], fill=(255,240,160))
    salveaza("stea.bmp", img)

def inima(culoare, contur, nume):
    # heart like on playing cards: 2 circles on top + triangle below
    img, d = baza()
    d.ellipse([32,38,66,72], fill=culoare, outline=contur)
    d.ellipse([62,38,96,72], fill=culoare, outline=contur)
    d.polygon([(32,56),(96,56),(64,104)], fill=culoare, outline=contur)
    # small highlight at the top-left
    d.ellipse([42,46,52,56], fill=(255,255,255))
    salveaza(nume, img)

def rosu():
    # red heart (red suit) for the RED gamble
    inima((220,20,50), (130,0,20), "rosu.bmp")

def negru():
    # black heart (black suit) for the BLACK gamble
    inima((25,25,32), (0,0,0), "negru.bmp")

def buton(lung, inalt, fundal, text, culoare_text, nume, marime_font):
    # rectangular button with text, like Shining Crown (SPIN/DOUBLE/TAKE WIN)
    # solid background + thick golden border + text centered with DejaVu Bold
    img = Image.new("RGB", (lung, inalt), fundal)
    d = ImageDraw.Draw(img)
    # double golden border, like slot cells
    d.rectangle([2, 2, lung-3, inalt-3], outline=(255, 215, 0), width=4)
    d.rectangle([8, 8, lung-9, inalt-9], outline=(255, 235, 150), width=1)
    # bold font, with fallback to default if DejaVu is missing
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", marime_font)
    except Exception:
        font = ImageFont.load_default()
    # centered text (textbbox so it lands in the middle)
    cutie = d.textbbox((0, 0), text, font=font)
    lat = cutie[2] - cutie[0]
    ina = cutie[3] - cutie[1]
    d.text(((lung-lat)//2, (inalt-ina)//2 - 2), text, fill=culoare_text, font=font)
    salveaza(nume, img)

def spin():
    # green SPIN button, always at the bottom at 412,520,200x60
    buton(200, 60, (40, 180, 60), "SPIN", (255, 255, 255), "spin.bmp", 28)

def double():
    # purple DOUBLE button, appears to the right of SPIN only on the win offer
    buton(200, 60, (120, 40, 180), "DOUBLE", (255, 215, 0), "double.bmp", 24)

def collect():
    # golden TAKE WIN button, on the gamble screen (collect when you have had enough)
    buton(300, 40, (200, 150, 10), "TAKE WIN", (20, 10, 0), "collect.bmp", 22)

def beturi():
    # 7 bet buttons under SPIN, horizontal one by one (84x32 purple + white text)
    # the selection is marked in-game with a thick golden border (no need for 2 BMP sets)
    for v in (10, 20, 40, 80, 100, 150, 250):
        buton(84, 32, (58, 20, 95), str(v), (255, 255, 255), "bet%d.bmp" % v, 20)

def text_simplu(lung, inalt, text, culoare_text, nume, marime_font):
    # plain text on the game background, without a button border (for CREDITS/BET/digits)
    # the background is exactly the game purple (30, 8, 50) so the BMP blends into the background
    img = Image.new("RGB", (lung, inalt), (30, 8, 50))
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", marime_font)
    except Exception:
        font = ImageFont.load_default()
    cutie = d.textbbox((0, 0), text, font=font)
    lat = cutie[2] - cutie[0]
    ina = cutie[3] - cutie[1]
    d.text(((lung-lat)//2, (inalt-ina)//2 - 2), text, fill=culoare_text, font=font)
    salveaza(nume, img)

def etichete():
    # 3 plain texts to the left of SPIN (not buttons): CREDITS + BET + WIN gold, small
    # below each one sits the live number drawn digit by digit in-game
    text_simplu(90, 20, "CREDITS", (255, 215, 0), "credit.bmp", 13)
    text_simplu(90, 20, "BET", (255, 215, 0), "bet_lbl.bmp", 13)
    text_simplu(90, 20, "WIN", (255, 215, 0), "win_lbl.bmp", 13)

def cifre():
    # white digits 0-9 on the game background (16x22, small), for the live credits/bet/win numbers
    for c in "0123456789":
        text_simplu(16, 22, c, (255, 255, 255), "digit%s.bmp" % c, 16)

def nocash():
    # red message at the top of the screen when you run out of credits (plain text on the background, no border)
    text_simplu(460, 36, "NOT ENOUGH CREDITS", (255, 60, 60), "nocash.bmp", 22)

coroana()
pepene()
pruna()
portocala()
banana()
cirese()
stea()
rosu()
negru()
spin()
double()
collect()
beturi()
etichete()
cifre()
nocash()
print("gata: 33 BMP-uri in assets/ (9 simboluri + SPIN/DOUBLE/TAKE WIN + 7 beturi + CREDITS/BET/WIN + 10 cifre + NOT ENOUGH)")
