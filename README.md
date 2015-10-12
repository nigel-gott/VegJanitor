#Tale 7 Vegetable Macro

Veg Janitor works at around 2000 vegetables per hour (in an optimal situation where you do not ever have to move which never happens). It is still a work in progress, feel free to chat me ingame for help, bug reports, suggestions etc. Here is a guide to getting started with it : 

## Setting up the Macro
### Installation
* The macro is now included in automato itself. Just find it in ATITD->veg_janitor.lua

### What to carry and where to be
* Have 72 jugs for a seed that needs 2 waters per cycle and 108 for a seed that needs 3.
* You need at least 20 seeds. Due to lag / macro errors it is common to loose a seed or two every couple of runs, if you fall below number of seeds required for a run bad things happen. 
* Do not stand too close to or on-top of water, the animation screws with the vegetable finding mechanism.
* Zoom in using F8 F8 F8 and then press Alt + L to lock the camera so you don't accidentally zoom out partway through

### In-game options
* Options -> Interface Options as follows:
  * Disable - Menu -> "Right-Click Pins/Unpins a Menu"
  * Enable - Menu -> "Rick-Click opens a Menu as Pinned" 
  * Enable - Menu -> "Use the chat area instead of popups for many messages"
* Options -> One-Click and Related 
  * Disable "Plant all crops where you stand"
* Options -> Video
  * Disable (check the box furthest to the left) - Shadow Quality 
  * Disable (check the box furthest to the left) - Time of Day lighting

###  The macros configuration
* Plants per run - Currently the maximum number of plants per run is 12. If you are having severe problems with it not working fast enough to water plants at the end consider lowering this.
* Click delay - Try raising if you are seeing plant windows not opening in time, waters not happening, general UI bugginess etc. However if you raise this too high plants will start dieing as they are not watered in time.

###  Once it is running
* Do not move. If you do / it moves itself you will have to restart the macro.
* When it is doing the initial planting do not move the mouse, whilst it is watering and harvesting you should be safe to use the mouse.
