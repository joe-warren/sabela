# What is Constructive Solid Geometry?

Constructive Solid Geometry or CSG, is a class of 3d modelling techniques.

CSG involves taking primitive shapes, like spheres, cylinders and cubes, transforming them into a position, and then combining them with "boolean operators", like intersection, union, and difference (or subtraction).

The [Wikipedia article on Constructive Solid Geometry](https://en.wikipedia.org/wiki/Constructive_solid_geometry) uses this diagram to explain it. 

![](/api/asset?path=waterfall/csg_tree.png)

This notebook is going to break this down, using a Haskell library called [Waterfall-CAD](https://hackage.haskell.org/package/waterfall-cad)

<!-- sabela:cell -->

First we're going to write a little bit of code to let us view Waterfall-CAD solids in a Sabela notebook; this uses the [`modelviewer.dev`](http://modelviewer.dev) JavaScript library.
```haskell
-- cabal: build-depends: waterfall-cad, linear, random
import qualified Waterfall as W
import Linear
import System.Random (randomRIO)

displayWaterfall s = do
  i <- randomRIO (0, 1000000 :: Int)
  let filename = "waterfall/models/" <> show i <> ".glb"
  W.writeGLB 0.01 filename (W.rotate (unit _x) (pi/2) s)
  displayHtml $ unlines
    ["<script type=\"module\" src=\"https://ajax.googleapis.com/ajax/libs/model-viewer/4.3.1/model-viewer.min.js\"></script>"
    , "<model-viewer src=\"/api/asset?path=" <> filename <> "\" ar shadow-intensity=\"1\" environment-image=\"/api/asset?path=waterfall/lighting.hdr\" camera-controls touch-action=\"pan-y\" style=\"width:100%;height:400px\"></model-viewer>"
    ]
```

In CSG modeling, you start with simple "primitive" shapes, such as a sphere.

```haskell
-- cabal: build-depends: waterfall-cad

displayWaterfall W.unitCylinder
```

> <!-- scripths:mime text/html -->
> <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/4.3.1/model-viewer.min.js"></script>
> <model-viewer src="/api/asset?path=waterfall/models/745760.glb" ar shadow-intensity="1" environment-image="/api/asset?path=waterfall/lighting.hdr" camera-controls touch-action="pan-y" style="width:100%;height:400px"></model-viewer>

Primitives can be transformed, for instance by scaling them.

```haskell
scaleFactor = V3 1 1 3.5

scaledCylinder = W.scale scaleFactor W.centeredCylinder
displayWaterfall scaledCylinder
```

> <!-- scripths:mime text/html -->
> <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/4.3.1/model-viewer.min.js"></script>
> <model-viewer src="/api/asset?path=waterfall/models/343023.glb" ar shadow-intensity="1" environment-image="/api/asset?path=waterfall/lighting.hdr" camera-controls touch-action="pan-y" style="width:100%;height:400px"></model-viewer>

Or by rotating them.

In Waterfall CAD, rotations are specified in [radians](https://en.wikipedia.org/wiki/Radian), so a quarter turn is a rotation of π/2.

```haskell
rotatedCylinder = W.rotate (unit _y) (pi/2) scaledCylinder
displayWaterfall rotatedCylinder
```

> <!-- scripths:mime text/html -->
> <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/4.3.1/model-viewer.min.js"></script>
> <model-viewer src="/api/asset?path=waterfall/models/812085.glb" ar shadow-intensity="1" environment-image="/api/asset?path=waterfall/lighting.hdr" camera-controls touch-action="pan-y" style="width:100%;height:400px"></model-viewer>

CSG modeling is all about using "Boolean operators" to combine pairs of solids. 

One of the most common Boolean operators is "union", which merges the volumes of the two shapes.

In the Wikipedia diagram, "union" was represented with the "∪" character. 

Merging our cylinder with the rotated cylinder gives us a cross shape. 

```haskell
cross = scaledCylinder <> rotatedCylinder
displayWaterfall cross
```

> <!-- scripths:mime text/html -->
> <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/4.3.1/model-viewer.min.js"></script>
> <model-viewer src="/api/asset?path=waterfall/models/750659.glb" ar shadow-intensity="1" environment-image="/api/asset?path=waterfall/lighting.hdr" camera-controls touch-action="pan-y" style="width:100%;height:400px"></model-viewer>

Because "union" is such a useful operator, Waterfall-CAD uses it in the `monoid` instance for Solids, which means we can union two solids together using the Monoid `<>` operator.

```haskell
threeDCross = cross <> W.rotate (unit _x) (pi/2) scaledCylinder
displayWaterfall threeDCross
```

> <!-- scripths:mime text/html -->
> <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/4.3.1/model-viewer.min.js"></script>
> <model-viewer src="/api/asset?path=waterfall/models/816198.glb" ar shadow-intensity="1" environment-image="/api/asset?path=waterfall/lighting.hdr" camera-controls touch-action="pan-y" style="width:100%;height:400px"></model-viewer>

Waterfall CAD has other primitive solids; such as cubes.

```haskell
cube = W.scale 3 W.centeredCube 
displayWaterfall cube
```

> <!-- scripths:mime text/html -->
> <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/4.3.1/model-viewer.min.js"></script>
> <model-viewer src="/api/asset?path=waterfall/models/89980.glb" ar shadow-intensity="1" environment-image="/api/asset?path=waterfall/lighting.hdr" camera-controls touch-action="pan-y" style="width:100%;height:400px"></model-viewer>

And Spheres

```haskell
sphere = W.scale 2 W.unitSphere
displayWaterfall sphere
```

> <!-- scripths:mime text/html -->
> <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/4.3.1/model-viewer.min.js"></script>
> <model-viewer src="/api/asset?path=waterfall/models/4903.glb" ar shadow-intensity="1" environment-image="/api/asset?path=waterfall/lighting.hdr" camera-controls touch-action="pan-y" style="width:100%;height:400px"></model-viewer>

Another Boolean operator used in CSG modeling is "intersection", which takes the region common to two solids.  

```haskell
roundedCube = cube `W.intersection` sphere
displayWaterfall roundedCube
```

> <!-- scripths:mime text/html -->
> <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/4.3.1/model-viewer.min.js"></script>
> <model-viewer src="/api/asset?path=waterfall/models/569164.glb" ar shadow-intensity="1" environment-image="/api/asset?path=waterfall/lighting.hdr" camera-controls touch-action="pan-y" style="width:100%;height:400px"></model-viewer>

The last CSG modeling operator we're going do use is "difference" (sometimes called subtraction).

This is used to remove one solid from another.

```haskell
shape = roundedCube `W.difference` threeDCross
displayWaterfall shape
```

> <!-- scripths:mime text/html -->
> <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/4.3.1/model-viewer.min.js"></script>
> <model-viewer src="/api/asset?path=waterfall/models/969630.glb" ar shadow-intensity="1" environment-image="/api/asset?path=waterfall/lighting.hdr" camera-controls touch-action="pan-y" style="width:100%;height:400px"></model-viewer>

And with that, we've built the solid from the diagram.
