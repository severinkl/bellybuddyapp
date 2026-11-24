import sys, numpy as np, cv2
from PIL import Image
im = np.array(Image.open(sys.argv[1]).convert('RGBA')).astype(int)
r,g,b,a = im[...,0],im[...,1],im[...,2],im[...,3]
black = (a>128)&(r<80)&(g<80)&(b<80)
for (c,ax,ang) in [((237.3,558.3),(178.0,284.8),14.5),((697.2,541.6),(180.5,282.9),167.1)]:
  m = np.zeros(black.shape,np.uint8)
  cv2.ellipse(m,(int(c[0]),int(c[1])),(int(ax[0]/2-4),int(ax[1]/2-4)),ang,0,360,1,-1)
  pb = (black & (m>0)).astype(np.uint8)
  cnts,_ = cv2.findContours(pb,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_NONE)
  cnt = max(cnts,key=cv2.contourArea)
  print('pupil in eye',c,'area',cv2.contourArea(cnt),'bbox',cv2.boundingRect(cnt))
  # ring thickness: measure along major axis direction outward from white edge
  ys,xs=np.nonzero(black)
# mouth skeleton points
n,lab,st,cen = cv2.connectedComponentsWithStats(black.astype(np.uint8),connectivity=8)
i = [k for k in range(1,n) if st[k,0]==362][0]
mm=(lab==i)
cols=[x for x in range(362,570,15)]
for x in cols:
  ys=np.nonzero(mm[:,x])[0]
  if len(ys): print('mouth x',x,'y',ys.min(),ys.max())
# ring thickness of right eye: horizontal scan at y=541
row = black[541]; xs=np.nonzero(row[550:850])[0]+550; print('right eye row blacks', xs.min(), xs.max())
w=np.nonzero(~black[541,600:800])[0]; print()
