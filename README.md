# MOD MATRIX FOR THE MATRIX MOD!

This is a Norns mod providing a mod matrix, and an API to define modulation sources that can participate.

To use, make sure you have turned on the `matrix` mod in Norns, and then from your code you can `local matrix = require 'matrix/lib/matrix'`.

## Using modulation sources

Go to the SYSTEM > MODS > matrix menu. This is the MATRIX menu, and it will look like the parameters menu. When you press K3 with a parameter selected, you will enter the sources menu for that parameter. You can select the source you desire with E2, then use E3 to adjust the depth of modulation. If you would like to zero out the modulation for the selected source, press K3.

## Defining modulation sources in your code

* `matrix:add_binary(id, name)` Adds a binary modulation source. Can modulate binary and trigger parameters; triggers will trigger on every modulation that is greater than zero. Can also modulate numeric parameters, like a pulse wave.
* `matrix:add_unipolar(id, name)` Adds a unipolar modulation source. Can modulate numeric parameters.
* `matrix:add_bipolar(id, name)` Adds a bipolar modulation source. Very much like unipolar, but can go negative. The difference is mostly interesting in calculating the total possible range of a parameter to show you.

## Providing and reading modulation

* `matrix:set(id, value)` sets the modulation for the given source id. Value should be 0 or 1 for binary parameters, between 0 and 1 for unipolar parameters, and between -1 and 1 for bipolar parameters.
* `matrix:get(id)` gets the modulation value for the given source id.

## Managing modulation depth

* `matrix:get_depth(param_id, source_id)` returns the modulation depth of the given param by the given source. Returns nil if not modulated by this source.
* `matrix:set_depth(param_id, source_id)` sets the modulation depth of the given param by the given source. I was thinking you'd use -1 to 1 but I guess you could use bigger numbers if the spirit moved you to do so.

## For mod authors: Runninng code after init()

* `matrix:add_post_init_hook(function() ... end)` adds a hook that will be evaluated post init. Use it to add parameters from your mod, or what-have-you.

## Managing bangs

* `matrix:defer_bang(param_id, priority)` will bang the given param once the current thread yields. If it is called more than once for the same param, it'll only be banged once. This is useful in post_init functions to only bang the parameters we've added since the main init finished, and it's also useful in internal code to allow a lot of modulation sources to change from a lattice, but only re-evaluate the parameter itself once they've all been changed.
* You can use `params:lookup_param(param_id).priority = x` to set the priority of any param. The `matrix` framework will obey this priority. Useful, for example, to ensure that a sequencer first advances, and then resets, and then triggers a voice, if all three things recieve a trigger at the same time. 
