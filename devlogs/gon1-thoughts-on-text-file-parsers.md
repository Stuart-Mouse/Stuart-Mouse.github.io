
While I'm certainly not the most qualified person to write about this topic, perhaps my layman's perspective could be useful to a beginner who's never tried to write such a program before.


I am definitely not here to tell you how to implement a parser, but still being relatively close 


Sometimes I feel that with enoug experiance doing something, one tends to forget many of the sneaky little things that tripped them up the first few go-arounds, as those things have just become implicit knowledge.

So, I'll take you on a little journey through my experience writing a GON parser in several different languages.



## straightforward port to C#

The original GON implementation was done by Tyler Glaiel in C++.

Porting this implementation to C# was extremely straightforward, since 


## C implementation

This was one of my first real projects in C, as I was just moving away from C#.

This time, I took some pointers from rapidxml, particularly the idea of parsing 'in-situ'.

'In-situ' parsing basically just means that we don't copy strings form the source file as we create the DOM, rather we just reference the underlying file.
Now in retrospect it's a bit silly that this term even exists, because in a sensible language there's no reason you would naturally think to copy all of these substrings form the source file by default.
One would just use a a string view (or pointer + length), which references the underlying file in a completely non-destructive manner.
But in the C/C++ world we have two competing bad designs that all but force a beginner to do this the slow way in a naive implementation.
In C, strings are null-terminated, so using the source file directly means that we need to destructively modify it by inserting null characters at the end of the tokens we want to reference.
Depending on the syntax of the file format you're parsing, this may be very problematic, but in the case of XML or GON it is fine to do so. 
And assuming that for some reason you don't want to or can't modify the underlying source file, your only option is to copy every single token you want to keep.
In C++, the std::string has its own ownership semantics which means that it may make any allocations it wants outside of the user's control.
In this case, a std::string will always make a copy when we intialize it with a substring from the source file.

So, short of implementing my own string view (and relevant functions) I decided to just go with the destructive null-insertion method.

For this implementation, I didn't really have any separation between the lexing and parsing of the file.
For a file format as simple as GON, there's really not much need to cleanly separate things in this way, but its worth noting.

With formats like JSON and XML, I think people sometimes ignore the fact that a parser is really just more of a lexer anyhow.
Even after the file has been parsed into a DOM representation, it still lacks any semantic meaning, and the program will then need to walk over the DOM and extract the information it needs, which is essentially just another phase of parsing.
Even if your JSON parser is really fast, using SIMD to churn through however many gigabytes of JSON per second, you're still going to need some slow, linear, user-level code to actually interpret the meaning of the DOM and validate its contents.


Although, if I were to go back and improve this implementation, I would probably go ahead and separate out the lexer a bit more so that I could improve the error messages and support utf8 instead of just ascii text.






### A shelved idea

I really wanted to embed some kind of type information in the gon files so that I could automate the process of naviagting the 




## SAX-style implementation in Jai

For my first real program in Jai, I decided I wanted to port and improve my GON parser from C. 
Having already known about Jai's type info system, I anticipated that I could use it to implement the reflection-based parsing that I could not do in C.
At first I began by doing a very strightforward port of the C code, though I quickly changed plans.
This time, I put in a proper separation between the lexing and parsing, basically just factoring out the lexing into a get_next_token() that the parser would call.

Around this time, I had also heard of the idea of a SAX-style parser (probably thanks to tsoding), and that seemed ideal to me, since it would allow me to maintain the single-pass architecture from the C implementation.


The user could create 'data bindings' to fields in the file simply by passing a path string and an `Any` which is just a pointer to some value and a pointer to the type info for that value.
Once the path matched to some field in the file, the data binding would have its value set directly from the string value in the file.


One part of this that I never really liked was the way I was comparing paths as I traversed the file.
It was this sort of weird system where I would pre-split the path into a `[] string` 
Though I'm still not sure how else I would have done it in retrospect.

Other than the path substrings (which were done up-front), there were absolutely no additional allocations that the parser had to make.

Overall, the simplicity of this approach was quite nice.
But ultimately there are a few things that a sax-style parser cannot do that I wanted to be able to handle.


While I have not actually had the time to test this out, my hunch is that parsing into a very lean DOM and then evaluating data bindings on the dom may be a bit faster than parsing in the SAX mode.
The extra cost of allocating space for the nodes can be almost completely mitigated by just using an arena or pool allocator, and being able to navigate directly to a node when evaluating a data binding means we don't need to be constantly checking the paths of all the data bindings that are on a particular branch.
(I would really like to do the comparision some time after I clean up both implementations, but alas I have more important things to work on.)
Not to mention, it's much easier to extend the parser if it operates on a DOM, since the user code has much more context about where it is in the file.
And in a SAX-style parser, the only real method of extending the parser is through user callbacks, which may then need to influence control flow or report their own errors.


## Porting my Sax-style parser to Odin

Since Odin is all the rage amongst Jai users who can't use Jai for thier more public projects yet, I decided to give it a try about a year ago, and of course I needed to port favorite parser yet again.
I don't have a ton to say about the  


## Going back to DOM-style parsing

My main reason for doing this ended up being the need to define references between fields in a file.
For example, I was using gon to define the tile types for a Mario clone, and I wanted to be able to specify the tiles 
But of course, the parser is designed to translate directly from source text to the final, typed values (and without any intermediate representation).
So the only way to do this woul dbe to place a callback in the parser that runs for every single node, checking if it is a certain member of a certain struct and then interpreting the value accordingly, searching back through the array of previously loaded tiles to find the index of the one named in the file.
But wait, what if we want to reference a tile that is defined later in the file? Well we really just can't do that without needing to store some additional external infomration that lets us resolve the reference later

Anyways, I don't want to belabor the point any further, but as you can see none of the options are ideal.

This time I basically did both the Jai and Odin implementations at more or less that same time. 
As I fixed things in one version or added new features I would port that fix/functionality to the other version.

In doing so I've just solidified my preference for Jai's type info system over Odin's.
Don't get me wrong, Odin's type info system is still very powerful, but it's just not quite as easy to work with and it lacks a few specific features that make implementing certain things much more hacky.
(
    In particular, Odin's type info does not store any information about the abstract base type of a polymorphic struct.
    So if we have for example, the following polymorphic struct:
    ```
    Fixed_String :: struct(N: int) {
        count:  int,
        data:   [N]u8,
    }
    ```
    And we want to dynamically identify an instance of this struct using a typeid, our only option is to parse the name to see if it starts with 'Fixed_String'.
    
    Whereas in Jai, there's an additional member in the Type_Info_Struct that points to the polymorph_source_struct.
    
)

### Implementing field references

While it would already be much easier to implement some means for evaluating references between nodes on a DOM than it woul dbe in the SAX parser, I felt like this was a common enough use case that I wanted to support these field references in the very syntax of the gon file rather than requiring user callbacks

There are 3 types of field references that I wanted to implement:
    index references, pointer references, and value references

index and pointer references were very straightforward
for index refs, we just grab the index of the specified node within its parent

for pointer refs, theres just a bit more checking to do, since we must make sure that there's a data binding to the field (otherwise what would we take the address of?)

but value references are where things get a bit more complicated
if the reference points to a simple field, we can just copy the string value of the field and replace the value ref node with a string node
But, if the reference points to a GON object or array, we need to copy that entire subtree of the DOM and paste those nodes in place of the reference
(We can't just point the reference at the existing subtree, since data bindings are stored on the nodes and we don't want to overwrite those.)
And best of all, what happens when we have a reference that points to another reference? 
well now we have the potential for dependency chains to form and circular references to rear their ugly heads

My original plan was to just jump through references and first evaluate their dependencies, keeping track of what nodes we've jumped thorugh in order to detect cycles
but, this is not really feasible due to the way that we are copying and pasting entire subtrees when certain nodes are evaluated, so I decided to take an iterative approach instead

So we just walk over the DOM and flag nodes as we resolve them, and we report an error if we ever fail to make progress on a given traversal.




## Augmenting the parser with expression parsing

This is still a work in progress, so I'll have to write more about this once It's properly complete, but to give you a sneak peak...

This basically has involved my ripping out the majority of the lexer and simply defering to the lead sheets parser for all but the major structural tokens
And this is really odd, because now entire expressions are essentially just treated as a type of token by the gon parser.
And because the lexer doesn't know the state of the parser, it doesn't know whether we expect only a simple string or an expression, which are the same thing to the LS parser
we *could* just hint to the gon lexer that we are expecting a simple string next rather than an expression, but the problem 

Another tricky bit is that boththe gon and LS lexers sort of run ahead by one token so that the user can peek a token without consuming it.

I think I will probably just end up entirely removing the lexer as a piece of state, and instead just call the lex_next_token proc directly, that way I can hint when I expect a name or a full expression


The tricky bit is that both of these parsers are structured in such a way that they parse 





