#!MC 1000

### set useful constants
$!Varset |PI| = (2.*asin(1.))
$!Varset |d2r| = (|PI|/180.)
$!Varset |r2d| = (180./|PI|)

### z3 = z2/z1
$!Varset |z1| = 1
$!Varset |z2| = 2
$!Varset |z3| = 3
$!DUPLICATEZONE 
  SOURCEZONE = |z1|
$!LINEARINTERPOLATE 
  SOURCEZONES =  [|z2|]
  DESTINATIONZONE = |z3|
  VARLIST =  [3-|NUMVARS|]
  LINEARINTERPCONST = 0
  LINEARINTERPMODE = SETTOCONST
$!VarSet |varsloop| = |NUMVARS|
$!VarSet |varsloop| -= 2
$!LOOP |varsloop|
  $!VarSet |var| = |Loop|
  $!VarSet |var| += 2
  $!ALTERDATA  [|z3|]
    EQUATION = 'V|var|=(V|var|[|z1|])'
#  $!ALTERDATA  [|z3|]
#    EQUATION = 'V|var|=(V|var|[|z3|]-V|var|[|z1|])'
#  $!ALTERDATA  [|z3|]
#    EQUATION = 'V|var|=(V|var|[|z3|])/(V|var|[|z1|]+1.e-10)'
$!ENDLOOP
$!ActiveFieldZones = [|z3|]

### apply style
$!READSTYLESHEET  "style.sty" 
  INCLUDEPLOTSTYLE = YES
  INCLUDETEXT = YES
  INCLUDEGEOM = YES
  INCLUDEAUXDATA = YES
  INCLUDESTREAMPOSITIONS = YES
  INCLUDECONTOURLEVELS = YES
  MERGE = NO
  INCLUDEFRAMESIZEANDPOSITION = YES

$!ActiveFieldZones = [3]

$!RUNMACROFUNCTION  "Set 0,0,0 Rotate Origin" 

### circles at origin
$!ATTACHGEOM 
  GEOMTYPE = CIRCLE
  COLOR = WHITE
  ISFILLED = YES
  RAWDATA
1.5 
$!ATTACHGEOM 
  GEOMTYPE = CIRCLE
  RAWDATA
1 
#$!ATTACHGEOM 
#  GEOMTYPE = CIRCLE
#  COLOR = WHITE
#  ISFILLED = YES
#  RAWDATA
#3.5 
#$!ATTACHGEOM 
#  GEOMTYPE = CIRCLE
#  RAWDATA
#1 

### turn on grid on slices
#$!FIELD [1-3]  MESH{COLOR = BLACK}
#$!FIELD [1-3]  MESH{SHOW = YES}
#$!FIELD [1-3]  MESH{LINETHICKNESS = 0.1}

### variable to plot
$!GLOBALCONTOUR 1  VAR = 4

### reset contours
$!RUNMACROFUNCTION  "Reset Contours (MIN/MAX)" 

### set manual contour range
$!CONTOURLEVELS NEW
  RAWDATA
1
0
$!LOOP 200
  $!VarSet |ContToAdd| = (0 + (|LOOP| * ((.0001-0)/200.) ) )
  $!CONTOURLEVELS ADD
    RAWDATA
  1
  |ContToAdd|
$!ENDLOOP

### reposition contour legend
$!GLOBALCONTOUR 1  LEGEND{XYPOS{X = 84.5}}
$!GLOBALCONTOUR 1  LEGEND{XYPOS{Y = 89.5}}

#$!ATTACHTEXT 
#  XYPOS
#    {
#    X = 10.
#    Y = 88.
#    }
#  TEXTSHAPE
#    {
#    HEIGHT = 24
#    }
#  ATTACHTOZONE = NO
#  ANCHOR = LEFT
#  TEXT = ''

### set view area
$!TWODAXIS XDETAIL{RANGEMIN = -6.0}
$!TWODAXIS XDETAIL{RANGEMAX =  6.0}
$!TWODAXIS YDETAIL{RANGEMIN = -6.0}
$!TWODAXIS YDETAIL{RANGEMAX =  6.0}
$!TWODAXIS XDETAIL{AUTOGRID = NO}
$!TWODAXIS YDETAIL{GRSPACING = 2}
$!TWODAXIS YDETAIL{AUTOGRID = NO}
$!TWODAXIS YDETAIL{GRSPACING = 2}
#$!TWODAXIS XDETAIL{RANGEMIN = -30.0}
#$!TWODAXIS XDETAIL{RANGEMAX =  30.0}
#$!TWODAXIS YDETAIL{RANGEMIN = -30.0}
#$!TWODAXIS YDETAIL{RANGEMAX =  30.0}
#$!TWODAXIS XDETAIL{AUTOGRID = NO}
#$!TWODAXIS YDETAIL{GRSPACING = 10}
#$!TWODAXIS YDETAIL{AUTOGRID = NO}
#$!TWODAXIS YDETAIL{GRSPACING = 10}

### change colorscale
$!COLORMAP CONTOURCOLORMAP = TWOCOLOR
$!COLORMAP TWOCOLOR{CONTROLPOINT 3 {TRAILRGB{R = 0}}}
$!COLORMAP TWOCOLOR{CONTROLPOINT 3 {LEADRGB{R = 0}}}
$!COLORMAP TWOCOLOR{CONTROLPOINT 3 {TRAILRGB{G = 0}}}
$!COLORMAP TWOCOLOR{CONTROLPOINT 3 {LEADRGB{G = 0}}}
$!COLORMAP TWOCOLOR{CONTROLPOINT 3 {TRAILRGB{B = 0}}}
$!COLORMAP TWOCOLOR{CONTROLPOINT 3 {LEADRGB{B = 0}}}
$!COLORMAP TWOCOLOR{CONTROLPOINT 1 {LEADRGB{R = 255}}}
$!COLORMAP TWOCOLOR{CONTROLPOINT 1 {LEADRGB{G = 255}}}
$!COLORMAP TWOCOLOR{CONTROLPOINT 1 {LEADRGB{B = 255}}}

$!REDRAWALL

### save file
$!PAPER ORIENTPORTRAIT = YES
$!PRINTSETUP PALETTE = COLOR
$!PRINTSETUP SENDPRINTTOFILE = YES
$!PRINTSETUP PRINTFNAME = 'print.cps'
$!PRINT 
