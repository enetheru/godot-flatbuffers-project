Incase you happen to have loaded this project looking for inforamtion.

The only thing worth interacting with is the res://editor_scripts/run_tests.gd and res://editor_scripts/enable_bpanel.gd

If you open either one you will be able to run it through the file menu ,or by right clicking on it in the scripts editor scripts panel.

It is the start of a testing regime, sadly a lot of things fail due to being a WIP

The testing here is incoherant.

I want to categorise things:

* you get out what you put in.
* API equivalence with upstream
	- scalars
	- vectors
	- structs
	- arrays
	- tables
* Convenience
	- using properties to fill a flatbuffer object
	- generating a schema from exported properties
