import sys,re,numpy as np,cv2
txt=open(sys.argv[1]).read()
def layer(name):
  body=re.search(name+r' = <double>\[(.*?)\];',txt,re.S).group(1)
  return [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?',body)]
def polys(d):
  out=[];cur=[];i=0;p=(0,0)
  while i<len(d):
    op=int(d[i]);i+=1
    if op==0: cur=[(d[i],d[i+1])];p=cur[0];i+=2
    elif op==1: p=(d[i],d[i+1]);cur.append(p);i+=2
    elif op==2:
      c1=(d[i],d[i+1]);c2=(d[i+2],d[i+3]);e=(d[i+4],d[i+5]);i+=6
      for t in np.linspace(0,1,12)[1:]:
        u=1-t;cur.append((u**3*p[0]+3*u*u*t*c1[0]+3*u*t*t*c2[0]+t**3*e[0],u**3*p[1]+3*u*u*t*c1[1]+3*u*t*t*c2[1]+t**3*e[1]))
      p=e
    else: out.append(np.array(cur,np.int32))
  return out
img=np.full((1920,1434,3),(221,217,242),np.uint8)
for name,col in [('kBuddySilhouette',(255,255,255)),('kBuddyFill',(182,171,255)),('kBuddyOutline',(15,13,13))]:
  m=np.zeros((1920,1434),np.uint8)
  for pl in polys(layer(name)):
    t=np.zeros_like(m);cv2.fillPoly(t,[pl],1);m^=t
  img[m>0]=col
cv2.imwrite(sys.argv[2],cv2.resize(img,(717,960)))
