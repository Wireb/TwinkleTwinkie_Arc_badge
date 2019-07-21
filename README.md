# Twinkle Twinkie Arc Badge
This firmware is for Mr TwinkleTwinkie's 2019 Arc Badge .
 
License is MIT so do what you want with it just don't litigate me. 

Animation is choses via the button on the back of the badge and is stored in flash so persistent over power cycles.

Current animations:

|Mode|What|
| ------------- | ------------- |
|0|Pulsing Blue with it going slightly lighter and back to full blue.|
|1|M0 - Green|
|2|M0 - Red|
|3|M0 - Yellow|
|4|M0 - Purple|
|5|M0 - Orange|
|6|M0 - Pink|
|7|Rotating Infinity Stone Colors around the edge with "Pulsing" yellow" in the center.|
|8|Chasing Infinity Stone Colors (Red, Orange, blue, purple, green) with twinkle yellow in the middle|
|9|Random fast color changing mode|
|A|C.A. - white inner, 2 blue 2 red chase|
|B|I.M. - Yellow & Red, Blue Center|
|C|H - Green & Purple, White Center|
|D|T - Blue & White, Red Center|
|E|H - Blue & Purple, White Center|
|F|B.W. - Red & White, Green Center|
|10|cool mistake on above red outer. Blue inner. White led chasing|
|11|yellow inner, red outer, blue chase|
|12|green inner, purple outer, white chase|
|13|blue inner, white outer, red chase|
|14|blue inner, purple outer, white chase|
|15|red inner, white outer, green chase|
|16|Solid Blue|
|17|Solid Green|
|18|Solid Red|
|19|Solid Yellow|
|1A|Solid Purple|
|1B|Solid Orange|
|1C|Solid Pink|
|1D|Rainbow!|


Total code space use is ~39% so plenty of space for more animations if wanted. 


## MplabX
This is a mplabX 5.20 project. All programming / debug was done with a PicKit4.

Source can be found in the base directory in:
.\TwinkleTwinkie_iron_badge.asm

If you just want to program a badge the compiled hex image can be found in:
.\TwinkleTwinkie_iron_badge.X\dist\default\production\TwinkleTwinkie_iron_badge.X.production.hex

## Documentation
There is not much for documentation on this one. Just get a badge and load the firmware :)

Arc Badge from Mr TwinkleTwinkie:
- https://www.tindie.com/products/twinkletwinkie/arc-badge-dc27-indie-badge/

I used a PicKit 4 for programming and debug. The programming pads are inside the badge and the square pad is pin 1. 
 


Copyright (c) 2019 Peter Shabino

Permission is hereby granted, free of charge, to any person obtaining a copy of this hardware, software, and associated documentation files 
(the "Product"), to deal in the Product without restriction, including without limitation the rights to use, copy, modify, merge, publish, 
distribute, sublicense, and/or sell copies of the Product, and to permit persons to whom the Product is furnished to do so, subject to the 
following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Product.

THE PRODUCT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
WITH THE PRODUCT OR THE USE OR OTHER DEALINGS IN THE PRODUCT.
