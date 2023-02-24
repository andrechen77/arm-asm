import sys
from PIL import Image
from itertools import islice


# color rgb scaling
def scale(x,d):
    return int( x * (((1<<d)-1)/255.0)) & ((1<<d) - 1)

# compute hword color value from rgb
def packColor(rgb):
    (r,g,b) = rgb
    return '0x%x' % ((scale(r,5) << 11) | (scale(g,6) << 5) | scale(b,5))

# why isn't this built in to Python?
def flatten(t):
    return [item for sublist in t for item in sublist]

# chunk list
def chunks(it, size):
    it = iter(it)
    return iter(lambda: tuple(islice(it, size)), ())

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("usage: %s <filename>" % sys.argv[0])
        sys.exit()
    
    fname = sys.argv[1]

    with Image.open(fname) as im:
        px = im.load()

        # build color data
        data = [[packColor(im.getpixel((x,y))) for x in range(im.width)] for y in range(im.height)]

        # basic width, height, transparency
        #   assumes that (0,0) is the color of transparency
        #   this is obviously oversimplified 
        #   pick a different value if it is wrong
        print('\t.hword %d, %d, %s' % (im.width, im.height, data[0][0]))
        for l in list(chunks(flatten(data),10)):
            print("\t.hword " + ", ".join(l))

