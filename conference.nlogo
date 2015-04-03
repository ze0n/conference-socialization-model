;; 
;;

turtles-own 
[ 
  thirsty?          ;; am i thirsty?
  start-of-thirst   ;; when did i start getting thirsty?
  drinks-had        ;; the number of drinks i've had
  base-pushiness    ;; the pushiness i am born with
  pushiness         ;; how pushy i am at the moment
  vx                ;; x velocity
  vy                ;; y velocity
  desired-direction ;; my desired direction
  driving-forcex    ;; my main motivating force
  driving-forcey    
  obstacle-forcex   ;; force exerted by obstacles
  obstacle-forcey
  territorial-forcex;; force exerted by neighbors
  territorial-forcey
]

globals
[
  total-times       ;; a list containing 10 accumulators for total time spent waiting by agents with the nth decile pushiness value
  total-counts      ;; a list containing 10 accumulators for total times agents with the nth decile of pushiness was served
]

;;----------------------------------------------------------------------------
;; Set up the view
;;----------------------------------------------------------------------------
to setup
  ca
  set-default-shape turtles "circle"

  ;; initialize the globals
  set total-times (list 0 0 0 0 0 0 0 0 0 0)
  set total-counts (list 0 0 0 0 0 0 0 0 0 0)

  ;; create patrons
  create-turtles patrons
  [
    setxy 0 (min-pycor + 3)
    set thirsty? false
    ;; give the turtles an initial nudge towards the goal
    let init-direction -90 + random 180 
    set vx sin init-direction
    set vy cos init-direction
    set drinks-had 0
    set base-pushiness (random-float 1) * (upper-pushiness - lower-pushiness) + lower-pushiness
    set pushiness base-pushiness
    color-turtle
  ]
  
  ;; set boundary patches as walls with blue color
  ask patches with [pxcor = min-pxcor or pxcor = max-pxcor or pycor = min-pycor or pycor = max-pycor]
  [ set pcolor blue ]
  
  ;; create the enterance counter with blue color
  ask patches with [pycor = (min-pycor + 2) and abs pxcor < 3]
  [ set pcolor blue ]
  
  ask patches with [pycor = (min-pycor + 1) and abs pxcor = 2]
  [ set pcolor blue ]
  
  ;; create the entrance
  ask patches with [pycor = (min-pycor + 1) and abs pxcor < 2]
  [ set pcolor yellow ]

  ;; create goal
  ask patches with [pycor = (max-pycor - 2) and pxcor = (10)]
  [ set pcolor green ]

  reset-ticks
  
end

;;----------------------------------------------------------------------------
;; run the simulation
;;----------------------------------------------------------------------------
to go
  ;; run the social forces model on thirsty turtles
  ;; calculate the forces first...
  ask turtles with [ thirsty? = true ]
  [ 
    calc-desired-direction 
    calc-driving-force
    calc-obstacle-force
    if any? other turtles
      [ calc-territorial-forces ] 
  ]
  ;; then move the turtles and have them grow impatient if need be
  ask turtles with [ thirsty? = true ]
  [
    move-turtle
    if get-impatient?
      [ grow-impatient ]
    ;; color the turtle to show how pushy it is
    color-turtle
  ]
  
  ;; control the arrival of new thirsty turtles
  if any? turtles with [thirsty? = false]
  [ wait-around ]
  ;; control the service rate of bartenders. follow an exponential distribution for service times
  let p 1 / mean-service-time
  if random-float 1 < p
  [
    ask one-of patches with [pcolor = green]
    [ service-patron ]
  ]
  tick
end

;;;; Function for waiting around and other functions ;;;;

;;----------------------------------------------------------------------------
;; returns a value from 0-9 which is the decile of pushiness that an agent has
;;----------------------------------------------------------------------------
to-report pushiness-index [pushiness-value]
  let p-index floor (((pushiness-value - lower-pushiness) / (upper-pushiness - lower-pushiness)) * 10)
  ifelse p-index = 10 ;; if it's 10, just treat it as 9
  [ report 9 ]
  [ report p-index ]
end

;;----------------------------------------------------------------------------
;; "serve" a turtle a drink
;;----------------------------------------------------------------------------
to service-patron 
  if any? turtles in-radius 2.5
  [
    ;; default to "random" service-plan
    let next-served one-of turtles in-radius 2.5
    if service-plan = "waited-longest"
    [ set next-served max-one-of turtles in-radius 2.5 [  ticks - start-of-thirst ] ]
    ask next-served
    [
      ;; reset the turtle
      setxy 0 0
      set thirsty? false
      let init-direction -90 + random 180
      set vx sin init-direction
      set vy cos init-direction
      set drinks-had drinks-had + 1
      set pushiness base-pushiness
      let p-index pushiness-index pushiness
      ;; increment the corresponding elements in the global arrays to keep track of wait times and service counts
      set total-counts replace-item p-index total-counts ((item p-index total-counts) + 1)
      set total-times replace-item p-index total-times ((item p-index total-times) + (ticks - start-of-thirst))
      if get-belligerent?
      [ set pushiness min (list upper-pushiness (base-pushiness + belligerence-rate * drinks-had)) ]
      color-turtle
    ]
  ]
end

;;----------------------------------------------------------------------------
;; get more pushy over time
;;----------------------------------------------------------------------------
to grow-impatient
  set pushiness pushiness + impatience-rate
  ;; make sure i'm not too pushy
  set pushiness min list pushiness upper-pushiness
end

;;----------------------------------------------------------------------------
;; color a turtle according to its pushiness
;;----------------------------------------------------------------------------
to color-turtle
  set color 19 - ((pushiness - lower-pushiness) / (upper-pushiness - lower-pushiness)) * 4
end

;;----------------------------------------------------------------------------
;; control when newly thirsty turtles arrive. follow an exponential distribution of inter-arrival times
;;----------------------------------------------------------------------------
to wait-around
  let p 1 / mean-time-between-arrivals
  if random-float 1 < p 
  [
    ask one-of turtles with [thirsty? = false] 
    [ 
      set thirsty? true
      set start-of-thirst ticks 
    ]
  ]
end   

;;----------------------------------------------------------------------------
;; helper function to find the magnitude of a vector
;;----------------------------------------------------------------------------
to-report magnitude [x y]
  report sqrt ((x ^ 2) + (y ^ 2))
end

;;----------------------------------------------------------------------------
;; returns 1 if the angle between the desired vector and the force vector is within a threshold, else return c
;;----------------------------------------------------------------------------
to-report field-of-view-modifier [desiredx desiredy forcex forcey]
  ifelse (desiredx * (- forcex) + desiredy * (- forcey)) >= (magnitude forcex forcey) * cos (field-of-view / 2)
  [ report 1 ] 
  [ report c]
end

;;----------------------------------------------------------------------------
;;;; Functions for calculating the social forces ;;;;
;; move the turtle according to the rules of the social forces model
;;----------------------------------------------------------------------------
to move-turtle
  let ax driving-forcex + obstacle-forcex + territorial-forcex
  let ay driving-forcey + obstacle-forcey + territorial-forcey
  
  set vx vx + ax
  set vy vy + ay
  
  ;; scale down the velocity if it is too high
  let vmag magnitude vx vy
  let multiplier 1
  if vmag > max-speed
  [set multiplier max-speed / vmag]
  
  set vx vx * multiplier
  set vy vy * multiplier
  
  set xcor xcor + vx
  set ycor ycor + vy
end

;;-----------------------------------------------------------------
;; find the territorial force according to the social forces model
;;-----------------------------------------------------------------
to calc-territorial-forces
  set territorial-forcex 0
  set territorial-forcey 0
  ask other turtles with [distance myself > 0]
  [
    let to-agent (towards myself) - 180
    let rabx [xcor] of myself - xcor
    let raby [ycor] of myself - ycor
    let speed magnitude vx vy
    let to-root ((magnitude rabx raby) + (magnitude (rabx - (speed * sin desired-direction)) (raby - (speed * cos desired-direction)))) ^ 2 - speed ^ 2
    if to-root < 0
    [set to-root 0]
    let b 0.5 * sqrt to-root
    
    let agent-force (- v0) * exp (- b / sigma)
    
    ask myself
    [
      let agent-forcex agent-force * (sin to-agent)
      let agent-forcey agent-force * (cos to-agent)
      ;; modify the effect this force has based on whether or not it is in the field of view
      let vision field-of-view-modifier driving-forcex driving-forcey agent-forcex agent-forcey
      set territorial-forcex territorial-forcex + agent-forcex * vision
      set territorial-forcey territorial-forcey + agent-forcey * vision
    ]
  ]
end

;;----------------------------------------------------------------------------
;; find the obstacle force of the turtle according to the social forces model
;;----------------------------------------------------------------------------
to calc-obstacle-force
  set obstacle-forcex 0
  set obstacle-forcey 0
  ask patches with [pcolor = white]
  [
    let to-obstacle (towards myself) - 180
    let obstacle-force (- u0) * exp (- (distance myself) / r)
    ask myself
    [
     set obstacle-forcex obstacle-forcex + obstacle-force * (sin to-obstacle)
     set obstacle-forcey obstacle-forcey + obstacle-force * (cos to-obstacle)
    ]
  ]
end

;;----------------------------------------------------------------------------
;; find the driving force of the turtle
;;----------------------------------------------------------------------------
to calc-driving-force
  set driving-forcex (1 / tau) * (max-speed * (sin desired-direction) - vx) * pushiness
  set driving-forcey (1 / tau) * (max-speed * (cos desired-direction) - vy) * pushiness
end

;;----------------------------------------------------------------------------
;; find the heading towards the nearest goal
;;----------------------------------------------------------------------------
to calc-desired-direction
  let goal min-one-of (patches with [pcolor = green]) [ distance myself ]
  set desired-direction towards goal
end
@#$#@#$#@
GRAPHICS-WINDOW
404
10
1077
704
25
25
13.0
1
10
1
1
1
0
0
0
1
-25
25
-25
25
1
1
1
ticks
30.0

BUTTON
9
114
72
147
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
114
114
177
147
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
196
272
396
422
Average Wait Time Distribution
pushiness (in deciles)
average wait
0.0
9.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "clear-plot\nforeach [0 1 2 3 4 5 6 7 8 9]\n[\n  ifelse item ? total-counts = 0\n  [ plotxy ? 0]\n  [ plotxy ? (item ? total-times) / (item ? total-counts) ]\n]"

SLIDER
7
10
179
43
patrons
patrons
1
200
132
1
1
NIL
HORIZONTAL

SLIDER
6
45
178
78
lower-pushiness
lower-pushiness
0
10
1.5
.1
1
NIL
HORIZONTAL

SLIDER
8
80
180
113
upper-pushiness
upper-pushiness
lower-pushiness
10
1.6
.1
1
NIL
HORIZONTAL

SLIDER
0
149
191
182
mean-time-between-arrivals
mean-time-between-arrivals
1
100
3
1
1
ticks
HORIZONTAL

SLIDER
9
183
181
216
field-of-view
field-of-view
0
360
200
1
1
NIL
HORIZONTAL

SLIDER
10
219
182
252
c
c
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
188
28
360
61
v0
v0
0
10
2.1
0.1
1
NIL
HORIZONTAL

SLIDER
189
71
361
104
sigma
sigma
0.1
10
0.3
0.1
1
NIL
HORIZONTAL

TEXTBOX
193
10
343
28
Force Constants
11
0.0
1

SLIDER
191
115
363
148
u0
u0
0
20
10
.1
1
NIL
HORIZONTAL

SLIDER
193
157
365
190
r
r
0.1
10
0.2
.1
1
NIL
HORIZONTAL

SLIDER
196
201
368
234
tau
tau
1
30
10
1
1
NIL
HORIZONTAL

SLIDER
9
254
181
287
max-speed
max-speed
0
1
0.2
.1
1
NIL
HORIZONTAL

SWITCH
9
290
172
323
get-impatient?
get-impatient?
0
1
-1000

SWITCH
10
360
171
393
get-belligerent?
get-belligerent?
1
1
-1000

SLIDER
11
325
182
358
impatience-rate
impatience-rate
0
.01
0.0010
.0005
1
NIL
HORIZONTAL

SLIDER
11
395
183
428
belligerence-rate
belligerence-rate
0
.1
0.01
.01
1
NIL
HORIZONTAL

SLIDER
6
432
185
465
mean-service-time
mean-service-time
0
100
3
1
1
ticks
HORIZONTAL

CHOOSER
8
469
146
514
service-plan
service-plan
"random" "waited-longest"
1

PLOT
197
426
397
576
average wait time
ticks
average wait time
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "ifelse sum total-counts = 0\n[plot 0]\n[plot (sum total-times) / (sum total-counts)]"

@#$#@#$#@
## WHAT IS IT?



## HOW IT WORKS



## HOW TO USE IT

Unless you have read Helbing and Molnar's paper on the social forces model and want to try playing with the variables under "Force Constants", I suggest that you just play with the variables on the left column first.

Just set the variables to what you want them to be, hit setup, then go.

Explanation of variables:

- patrons, number of turtles to create
- lower-pushiness, the smallest base-pushiness value a turtle can have
- upper-pushiness, the biggest base-pushiness value a turtle can have
- mean-time-between-arrivals, the average number of ticks between turtles getting thirsty
- field-of-view, the field of view of the turtles
- c, if something is not in the field of view, the percentage that its corresponding force is reduced to
- max-speed, the highest step size of the turtles
- get-impatient?, whether turtles get impatient
- impatience-rate, how fast turtles get impatiend
- get-belligerent?, whether turtles get pushier with the number of drinks they've had
- belligerence-rate, how much each drink contributes to the pushiness of a turtle
- mean-service-time, the average time it takes for the bartender to serve a turtle
- service-plan, whether the bartender randomly chooses a turtle or chooses the one thats been waiting the longest to serve
- v0, corresponds to the V^0 constant in the equation in the report on the model's page
- sigma, corresponds to the sigma constant in the equation in the report on the model's page
- u0, corresponds to the U^0 constant in the equation in the report on the model's page
- r, corresponds to the R constant in the equation in the report on the model's page
- tau, corresponds to the tau constant in the equation in the report on the model's page

## THINGS TO NOTICE

- Keep a look out for how the turtles move towards the bartender and how they crowd around the counter 
- Watch out for turtles that are deep red and see if they push their way to the counter more easily than other turtles

## THINGS TO TRY

- Try playing with the mean-time-between-arrivals and mean-service-time. What would happen if one is greater than the other? If they are equal?
- See what playing with the field-of-view would do
- When you're more comfortable with the model, play around with the variables under "Force Constraints"

## EXTENDING THE MODEL

It would be interesting to see how agents who tip well will do when they try to get the bartender's attention in the future. I've also thought of implementing a behavior where turtles "wave" cash to get the bartender's attention. After interviewing some bartenders though, it turns out they don't necessarily get any preferential treatment.

## NETLOGO FEATURES

This model keeps track of the different waiting times for agents at each decile by maintaining a list of accumulated values where each item corresponds with a decile. It also has a plot that doesn't plot as a function of time so you should check that out.

## CREDITS AND REFERENCES

[Modeling Commons URL](http://modelingcommons.org/browse/one_model/3645) 
This model is based on the [social forces model](http://pre.aps.org/abstract/PRE/v51/i5/p4282_1)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <metric>total-times</metric>
    <metric>total-counts</metric>
    <enumeratedValueSet variable="mean-time-between-service">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lower-pushiness">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-time-between-arrivals">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-of-sight">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="u0">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="get-impatient">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="service-plan">
      <value value="&quot;random&quot;"/>
      <value value="&quot;waited-longest&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="belligerence-rate">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-speed">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="r">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patrons">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tau">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="v0">
      <value value="2.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sigma">
      <value value="0.3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="upper-pushiness" first="0.6" step="0.2" last="1.6"/>
    <enumeratedValueSet variable="get-belligerent">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="c">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="impatience-rate">
      <value value="0.0010"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@