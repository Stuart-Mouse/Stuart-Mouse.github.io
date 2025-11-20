
# Site Generator

## Starting Over Again

This time, I want to approach things a bit differently.
Firstly, we will build a site directory, scanning all the included folders and putting them into some tree structure.
This will help in all subsequent steps since this gives us the structure for the site struct to generate, and we will have an index of all the files of a given type.

For each file type, we will define some kind of workflow.
We will have to process the templates into some raw structure from which we can then generate a header.
We will still have to solve the problem that we want to preserve the template headers and not the raw templates.
The solution will probaby be to just use the data packer at compile-time and add data to some constant data segment manually.
That way we don't have to do some ridiculous string operations just to re-insert the headers into the final templates.


## High-Level Structure

It will probably be easier to implement the site generator as a module than as a polymorphic struct.
As long as the generated module/library has a common interface for the site directory and for calling essential functions, there's no reason one couldn't instance the site in a more manual way.
Now, to be fair, if we could wrap all of the site's stateful components into a single struct, that would make instancing the site much easier. But the problem is that doing so creates a choke point for the inter-dependencies of our site's content.

Also, I should probably do some research to figure out what the actual common use cases are/would be for multi-threading/async in the context of a website generator.
This will determine a lot about what infrastructure we need for handling and scoping data on the site.
(Do we want static variables on a per-site instance/per-thread basis, or do we want context values, or do we want per-user data, or all of the above or soemthing else?)


## Building a Site Directory

We will use a flat pool for allocating all nodes for this at compile-time. 
Then we can use the data packer at the end to package up the nodes in a sorted/compressed format.

In addition to storing the path for each file node, we will want to eventually store a offset to the file content on the directory node.
That way we can just use the same constant directory for each site instance, but we can use the offset to get the runtime content for the page/file/template etc.

### Looking Ahead

In the future, I am pretty sure I will want to index files other than just templates and incorporate those into the build process somehow.
This will probably include things like WASM content that will need to undergo their own separate compilation process and then be linked in,

With this in mind, I think we may need some common header info that describes the content of a file and how it links into the overall build process.
That way we can potentially multi-thread or async-ify the build process for individual elements of the site.
And then when those things are done, we can properly update the directory node to reflect its state.


## Changes to Template Processing

Instead of embedding the original file contents into the rendering procedure as string literals, 
I will probably just store the original file contents as a string into which we index for the individual substrings that need to get appended.
This way, the generated code will be much smaller, and we may be able to generate the rendering proc body as code rather than as a string.


## Raw Templates






