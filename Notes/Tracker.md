---

kanban-plugin: board

---

## Project
- [ ] Split project into more logical chunks so that cloning the addon can be done directly into the addons folder

## gdextension

- [ ] Cleanup source generation so that it is just a copy paste of the addons folder
- [ ] CMake: Change FetchContent to ExternalProject
- [ ] Migrate to godot4.6 / godot-cpp ~10
- [ ] Verify the memory allocation strategy
- [ ] Implement var_to_flexbuffer flexbuffer_to_var

## flatc Generator

- [ ] Check in Get* functions to check buffer size for at least minimum
- [ ] When the root_type is missing we get a generation failure, but no easily understood error message.
- [ ] Implement namespaces as either const import from an additional file, or class name prefix? Figure it out to make better sense.
- [ ] Required attribute does not work properly

## Generated Code

- [ ] When accessing nested objects from a deserialised buffer, a new object is created each time.
- [ ] Create* functions need to be able to take the object, not the offset, ie string instead of int
- [ ] Builder add_* function arguments need to be named with \_offset if they expect an offset instead of a value.
- [ ] Work on feature parity

## Addon/Plugin

- [ ] Reload script in editor after re-generation
- [ ] Make failed compile popup
- [ ] Move editor settings to project settings
- [ ] Add filename to debug print
- [ ] Notify user if creation date of fbs file is different to generated file and could use a re-gen
- [ ] I saw someone using a struct visualiser, makes me want to build one for this.
- [ ] Add an option to the settings to auto generate after a fbs file is changed.

## Syntax Highlighting

- [ ] Check names for collision
- [ ] Parse includes for names
- [ ] Keep track of field names and highlight duplicates
- [ ] ANNOYING: Parsing runs on every keypress, printing errors each time until correctness is achieved
- [ ] To get file extension recognition working I need to create a ResourceFormatLoader https://docs.godotengine.org/en/stable/classes/class_resourceformatloader.html

## Testing

- [ ] Perform testing in CI/CD
- [ ] Test FlexBuffer Code

## Benchmarking

- [ ] Copy strategy from flatbuffers project
- [ ] Compare against built-in solution.

## Documentation
- [ ] Explain Object API

## Brainstorming

- [ ] Due to the nature of how properties work, I wonder if I can create a class like object from a flatbuffer

***

## Archive

- [ ] hide debug print
- [ ] FlatBuffersBuilder.new() crashes godot
- [ ] flatbuffers namespace == class name prefix
- [ ] new GetRoot function in gdscript to get root flatbuffer
- [ ] GetRoot needs to be a static function

%% kanban:settings
```
{"kanban-plugin":"board","list-collapse":[false,false,false,false]}
```
%%
