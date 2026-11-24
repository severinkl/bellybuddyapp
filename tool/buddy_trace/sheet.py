import sys
from PIL import Image, ImageDraw
files=sys.argv[2:]; out=sys.argv[1]
ims=[Image.open(f).convert('RGB').resize((300,390)) for f in files]
cols=4; rows=(len(ims)+cols-1)//cols
sheet=Image.new('RGB',(cols*300,rows*410),'white')
d=ImageDraw.Draw(sheet)
for i,(im,f) in enumerate(zip(ims,files)):
  x,y=(i%cols)*300,(i//cols)*410
  sheet.paste(im,(x,y+20)); d.text((x+6,y+4),f.split('/')[-1],fill='black')
sheet.save(out)
