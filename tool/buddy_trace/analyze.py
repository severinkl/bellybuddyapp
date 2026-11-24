import sys, numpy as np, cv2
from PIL import Image
im = np.array(Image.open(sys.argv[1]).convert('RGBA')).astype(int)
H,W = im.shape[:2]
r,g,b,a = im[...,0],im[...,1],im[...,2],im[...,3]
alpha = a>128
black = alpha & (r<80)&(g<80)&(b<80)
white = (~alpha) | ((r>235)&(g>235)&(b>235))
pink = alpha & ~black & ~white
print('size',W,H,'black',black.sum(),'pink',pink.sum(),'white',white.sum(), 'transparent', (~alpha).sum())
print('pink sample', np.median(r[pink]),np.median(g[pink]),np.median(b[pink]))
# background = white connected to border
wm = white.astype(np.uint8)
n,lab = cv2.connectedComponents(wm,connectivity=4)
border = set(lab[0,:])|set(lab[-1,:])|set(lab[:,0])|set(lab[:,-1])
bg = np.isin(lab, [l for l in border if l!=0]) & white
inner_white = white & ~bg
n2,lab2,st,cen = cv2.connectedComponentsWithStats(inner_white.astype(np.uint8),connectivity=4)
for i in range(1,n2):
  if st[i,4]>3000:
    ys,xs = np.nonzero(lab2==i)
    pts = np.stack([xs,ys],1).astype(np.float32)
    cnts,_ = cv2.findContours((lab2==i).astype(np.uint8),cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_NONE)
    el = cv2.fitEllipse(cnts[0])
    print('white comp', st[i], 'ellipse(center,axes,angle)', [tuple(round(v,1) for v in el[0]), tuple(round(v,1) for v in el[1]), round(el[2],1)])
n3,lab3,st3,_ = cv2.connectedComponentsWithStats(black.astype(np.uint8),connectivity=8)
for i in range(1,n3):
  if st3[i,4]>500: print('black comp', st3[i])
