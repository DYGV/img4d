import numpy as np
from PIL import Image

i = 0
f = open("edge_lena.txt")

lst =[]
for line in f:
    i+=1
    lst.insert(i,eval(line))

img = Image.fromarray(np.array(lst).astype("uint8")).save("edge_lena.png")
