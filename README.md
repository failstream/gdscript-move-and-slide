This is my best approximation of the move_and_slide function for CharacterBody2D translated into gdscript. I created a new CharacterBody2D class and did my best to translate the C++ code from https://github.com/godotengine/godot/blob/6fea273ed3df7d4be9674d35aae698731fa823ea/scene/2d/physics_body_2d.cpp#L1109 to gdscript code.


I mainly did this to teach myself exactly how the function worked because I thought I might want to introduce some changes to the functionality. The one change I did introduce is used to differentiate left and right walls.

Let me know if you find any inconsistencies or bugs or if this was helpful at all!
