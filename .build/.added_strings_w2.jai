// Workspace: Target Program

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/source/main.jai:147.
//
#insert #run generate_page_renderer("index", "index.jhtml");
#insert #run generate_page_renderer("gon-parsers", "gon-parsers.jhtml");
#insert #run generate_page_renderer("game-dev", "game-dev.jhtml");
#insert #run generate_page_renderer("tein", "tein.jhtml");
#insert #run generate_page_renderer("open-ended", "open-ended.jhtml");
#insert #run generate_page_renderer("oe-videos", "oe-videos.jhtml");
#insert #run generate_page_renderer("randomizer", "randomizer.jhtml");
#insert #run generate_page_renderer("randomizer-dev", "randomizer-dev.jhtml");
#insert #run generate_page_renderer("devlogs", "devlogs/devlogs.jhtml");
#insert #run generate_page_renderer("devlogs-oe1_movement_101", "devlogs/oe1_movement_101.jhtml");
#insert #run generate_page_renderer("devlogs-oe2_movement_102", "devlogs/oe2_movement_102.jhtml");
#insert #run generate_page_renderer("navbar", "navbar.jhtml");

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:6.
//
table_add(*templates, "index", () {
write_html(#string _inserted_html_
<!DOCTYPE html>
<html>
    <head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>My Projects</title>
		<meta name="description" content="">
		<meta name="keywords"    content="">
		<meta name="author"      content="Stuart Mouse">
		<meta name="viewport"    content="width=device-width, initial-scale=1.0">
		<link rel="shortcut icon" type="image/x-icon" href="images/randomizer/icon.ico">
		<link rel="stylesheet" type="text/css" href="style.css">
	</head>
    <body>
        
_inserted_html_);
 call_template("navbar"); write_html(#string _inserted_html_

        <div class="content">
            <h1>My Projects</h1>
            <p>
                This page is meant as a listing for some general projects, mostly programming related, which I've been working on.
                As some of these things become more complete they'll likely make their way to dedicated pages, and maybe even to the navigation bar!
            </p>
            
            <hr/>
            <h2>Music Collage</h2>
            <p>
                This is a sort of experimental project I've been working on with my brother, focused on using unique collages of icons as a way of exploring new music.
                I'm quite happy with how it turned out aesthetically, and though I would like to spend some time refactoring the code, it certainly gets the job done as is. 
                <a href="https://joshuathomaswilson.com">Click here</a> to try it out, and please let us know what you think!
            </p>
			<table class="columns">
				<tbody>
					<tr>
						<td>
							<img src="
_inserted_html_);
write_var(make_path_absolute("images/autumn-collage-1.png"));
write_html(#string _inserted_html_
" alt="Screenshot" class="tilescrn">
						</td>
						<td>
							<img src="
_inserted_html_);
write_var(make_path_absolute("images/autumn-collage-2.png"));
write_html(#string _inserted_html_
" alt="Screenshot" class="tilescrn">
						</td>
					</tr>
				</tbody>
			</table>
            <p>
                On the technical side, this was my first real foray in Web Assembly, and frankly it was still much easier to write the required C code for this project than it was to write the Javascript (what a wreck of a language...).
                I definitely plan to make more use of WASM in the future, but hopefuly not using Emcripten or C++. 
                With the Memory64 feature soon making its way into browsers, I hope to write my future WASM projects in Jai or Odin.
            </p>
            
            <!-- TODO: Blog Posts? -->
            
            <!-- TODO: Lead Sheets -->
            
            <!-- TODO: Jai Data Packer -->
            
            <!-- TODO: Mooviz? -->
            
            <!-- TODO: Jai HTML Templater -->
            
            <hr/>
            <h2>GON Parsers</h2>
            <p>
                Throw out that JSON and get yourself an upgrade!
                GON is the new kid on the textual data file format block and he's bringing the heat!
                Go read about it <a href="
_inserted_html_);
write_var(make_path_absolute("gon-parsers.html"));
write_html(#string _inserted_html_
">here</a>.
            </p>
<pre><code class="code"><span style="color: var(--main-color-medium);">sample_object</span> <span style="color: var(--main-color-accent)">{</span>
    <span style="color: var(--main-color-medium);">file_name</span> test.gon
    <span style="color: var(--main-color-medium);">number</span>    35.35
    <span style="color: var(--main-color-medium);">string</span>    "this is a string"
    <span style="color: var(--main-color-medium);">array</span>     <span style="color: var(--main-color-accent)">[</span> 1 <span style="color: var(--main-color-accent)">[</span> 2.1 2.2 <span style="color: var(--main-color-accent)">]</span> 3 <span style="color: var(--main-color-accent)">]</span>
    <span style="color: var(--main-color-medium);">nested_object</span> <span style="color: var(--main-color-accent)">{</span>
        <span style="color: var(--main-color-medium);">number</span> 53.53
        <span style="color: var(--main-color-medium);">string</span> "this is a string"
        <span style="color: var(--main-color-medium);">array</span>  <span style="color: var(--main-color-accent)">[</span> 1 2 " three " 4 five 6 7 8 <span style="color: var(--main-color-accent)">]</span>
    <span style="color: var(--main-color-accent)">}</span>
<span style="color: var(--main-color-accent)">}</span></code></pre>
            
            <hr/>
            <h2>Game Development</h2>
            <p>
                I occasionally find the time to work on game development.
                If you want to see my current and previous projects, click <a href="
_inserted_html_);
write_var(make_path_absolute("game-dev.html"));
write_html(#string _inserted_html_
">here</a>. 
            </p>
            <img src="
_inserted_html_);
write_var(make_path_absolute("images/odin-games/pong-1.png"));
write_html(#string _inserted_html_
"  alt="Screenshot" class="fitimg" style="width:32%;">
			<img src="
_inserted_html_);
write_var(make_path_absolute("images/odin-games/mario-1.png"));
write_html(#string _inserted_html_
" alt="Screenshot" class="fitimg" style="width:32%;">
			<img src="
_inserted_html_);
write_var(make_path_absolute("images/odin-games/zelda-1.png"));
write_html(#string _inserted_html_
" alt="Screenshot" class="fitimg" style="width:32%;">
			
            <hr/>
        </div>
    </body>
</html>

_inserted_html_);
});

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:7.
//
table_add(*templates, "gon-parsers", () {
write_html(#string _inserted_html_
<!DOCTYPE html>
<html>
    <head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>GON Parser</title>
		<meta name="description" content="">
		<meta name="keywords"    content="">
		<meta name="author"      content="Stuart Mouse">
		<meta name="viewport"    content="width=device-width, initial-scale=1.0">
		<link rel="shortcut icon" type="image/x-icon" href="images/randomizer/icon.ico">
		<link rel="stylesheet" type="text/css" href="style.css">
	</head>
    <body>
        
_inserted_html_);
 call_template("navbar"); write_html(#string _inserted_html_

        <div class="content">
            
            <h1>GON Parsers</h1>
            <p>
                GON is a plain-text file format similar to JSON which can be used to store structured data in fields, objects, and arrays.
                Compared to JSON the syntax is extremely minimal and, in my opinion, much easier to read and edit.
                The original C++ implementation was created by Tyler Glaiel, and can be accessed <a href="https://github.com/TylerGlaiel/GON">here</a>.
            </p>
            
            <hr/>
            <h2>An Introduction to the Format</h2>
			<p>
				Every field in a gon file consists of a name and value pair (unless the object is in an array, in which case it has no name).
				Each token (a name or value) is separated by whitespace, unless encased in quotation marks, in which case the content of the quotation marks is treated as a single token.
				There are three types of gon field: 
				<ul>
					<li>field - contains a single value</li>
					<li>object - contains multple named fields enclosed in curly braces</li>
					<li>array - contains multple values enclosed in square brackets</li>
				</ul>
				Below is a brief example of what the format looks like:
			</p>
<pre><code class="code"><span style="color: var(--main-color-medium);">sample_object</span> <span style="color: var(--main-color-accent)">{</span>
    <span style="color: var(--main-color-medium);">file_name</span> test.gon
    <span style="color: var(--main-color-medium);">number</span>    35.35
    <span style="color: var(--main-color-medium);">string</span>    "this is a string"
    <span style="color: var(--main-color-medium);">array</span>     <span style="color: var(--main-color-accent)">[</span> 1 <span style="color: var(--main-color-accent)">[</span> 2.1 2.2 <span style="color: var(--main-color-accent)">]</span> 3 <span style="color: var(--main-color-accent)">]</span>
    <span style="color: var(--main-color-medium);">nested_object</span> <span style="color: var(--main-color-accent)">{</span>
        <span style="color: var(--main-color-medium);">number</span> 53.53
        <span style="color: var(--main-color-medium);">string</span> "this is a string"
        <span style="color: var(--main-color-medium);">array</span>  <span style="color: var(--main-color-accent)">[</span> 1 2 " three " 4 five 6 7 8 <span style="color: var(--main-color-accent)">]</span>
    <span style="color: var(--main-color-accent)">}</span>
<span style="color: var(--main-color-accent)">}</span></code></pre>
			<p>
				In this example, we have a root object called "sample_object" which contains several fields, including an array and another nest object.
				Objects and arrays can be nested as deeply as you wish without issue.
				Because all of the data in a gon file is plain text, there is no inherent issue with mixing data/fields/objects of different types.
				You can also placed comments in a file with '#'. Everything after this token will be ignored until the end of the line.
			</p>

			<p>
				I find that the extremely minimal syntax of the format makes it ideal for situations requiring manual data entry. 
				I currently use the format for entering variable values in my upcoming game's level editor in leiu of a gui interface, since it is extremely easy to edit the text and reload the file whenever I need to update the data.
				I also use the format for all of my configuration files as it is extremely easy for users to edit and requires very little explanation.
			</p>
            
            <hr/>
            <h2>Links to Implementations</h2>
            <p>
                At this point I have written five different implementations across four different languages, and have augmented the format with some additional features.
                The original implementation is linked above, and the three implementations below are the one I've written that are currently public.
            </p>
            <ul>
                <li><a href="https://github.com/Stuart-Mouse/uGON">C/C++</a></li>
                <li><a href="https://github.com/Stuart-Mouse/jai-gon">Jai</a></li>
                <li><a href="https://github.com/Stuart-Mouse/odin-gon">Odin</a></li>
            </ul>
            
            <hr/>
            <h2>Evolution of the Parser</h2>
            <p>
                My first implementation was in C#, and it was more or less a straightforward port of the original C++ implementation.
                This was done solely for the purpose of not having to use cross-language bindings in my TEiN Randomizer, which was written in C#.
                The original C++ implementation is already pretty object-oriented in its design, 
            </p>
            <p>
                Later, I wrote an entirely new <a href="
_inserted_html_);
write_var(make_path_absolute("ugon.html"));
write_html(#string _inserted_html_
">implementation in C</a> and, taking some inspiration from RapidXml's in-situ parsing, saw a major performance increase.
                Compared to the original C++ implementation, my C implementation is 150x faster. 
                According to my benchmarks, it is also marginally faster than RapidXml for a structurally identical input, but of course as XML is inherently a more verbose format, that can proabbly be chocked up to the shorter input stream.
                One thing I wanted to try to do with this C implementation was to somehow embed type information into the file format so that the parser could extract data directly into internal data structures without the need to generate and intermediate representation (e.g. a DOM).
                However, at the time I was unsure how to do this without either using reflection or making the syntax much more verbose.
                So, this implementation does make use of an intermediate DOM-like representation, but it is a very compact flat array and is still quite fast.
            </p>
            <p>
                My next implementation was written in Jai, and this was a major improvement.
                Thanks to Jai's runtime type information, it was quite trivial to implement a <a href="https://en.wikipedia.org/wiki/Simple_API_for_XML">SAX-style</a> parser which would store data directly into strongly-typed structures, without constructing any intermediate representation of the file.
                The association of a particular field in a GON file to a piece of internal data is handled through "data bindings", which the user can very simply define in the parser context.
                For structs, the parser will automatically create 'indirect' bindings to member fields recursively.
            </p>
            <p>
                This parser was relatively flexible and extensible through the use of callback procedures, but because it is relatively stateless, the SAX-style parsing paradigm ultimately has some limitations.
                The biggest limitation is the linearity of the parser. 
                Unless we know ahead of time that we will need to hold on to some GON object (and handle that in a callback), we cannot later refer back to the object or set a data binding on that object. 
                For many use cases, this limitation is no issue. But if you want a file to define references between the data it contains, you now need to do some very messy workarounds.
            </p>
            <p>
                So for my next implementation, I restructured the parser completely to use a DOM.
                (For all my attempts to avoid such an intermediate representation, I have to admit that it does afford some additional niceities.)
                I also added some additional syntax that allows the user to reference other fields in a file by pointer, index, or value.
                The current implementation uses an iterative approach to resolve all references between nodes, and will return an error if there is some cyclic reference(s).
                (This new DOM-based version of the parser has also been ported to Odin.)
            </p>
            
            <hr/>
            <h2>Future Plans</h2>
            <p>
                I plan to clean up and rewrite the SAX-based version in both Odin and Jai, and host those on a separate repository.
                The tokenizer and error reporting were not very good and there are certainly some other aspects which could be refactored.
            </p>
            <p>
                I would like to extend the capabilities of new DOM-based parser with some basic expression evaluation so one can do things like defining values based on mathematical formulas or computing one field's value based on another field's value.
                I plan to add this capability once my <a href="
_inserted_html_);
write_var(make_path_absolute("lead-sheets.jhtml"));
write_html(#string _inserted_html_
">Lead Sheets</a> module is more complete.
            </p>
            <p>
                If I ever get back around to improving the C implementation, I think it would be fun to try implementing some of the reflection-based automatic parsing of the Jai and Odin versions in C.
                This could probably be done in a relatively simple manner using something like Dyncall's dcAggr definitions.
                And of course I would want to design the parsing primitives to be simple enough that users could make it work with their own reflection systems.
            </p>
            
            
            <hr/>
        </div>
    </body>
</html>

_inserted_html_);
});

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:8.
//
table_add(*templates, "game-dev", () {
write_html(#string _inserted_html_
<!DOCTYPE html>
<html>
    <head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>Game Dev</title>
		<meta name="description" content="">
		<meta name="keywords"    content="">
		<meta name="author"      content="Stuart Mouse">
		<meta name="viewport"    content="width=device-width, initial-scale=1.0">
		<link rel="shortcut icon" type="image/x-icon" href="images/randomizer/icon.ico">
		<link rel="stylesheet" type="text/css" href="style.css">
	</head>
    <body>
        
_inserted_html_);
 call_template("navbar"); write_html(#string _inserted_html_

        <div class="content">
            
            <h1>Game Development</h1>
            <p>
                In my scant free time I do a little bit of casual game development. 
                I hope to make this more of a priority going forward, but I'm mostly caught up in work and programming projects at the moment.
                Fortunately my scripting language is almost done and I should be able to start on my first major project soon.
            </p>
            
            <hr/>
            <h2>Games in Odin</h2>
            <p>
                Here are some simple engines I wrote last year for a entry to game programming class I taught. 
                There's PONG, Zelda, and Super Mario Bros. engines with some basic level editors and dear imgui integration.
                Compiling these engines will require having <a href="https://github.com/ThisDevDane/odin-imgui">odin-imgui</a> and my <a href="https://github.com/Stuart-Mouse/odin-imgui-extras">odin-imgui-extras</a> (used for some wrapper functions and data reflection).
            </p>
			<img src="
_inserted_html_);
write_var(make_path_absolute("images/odin-games/pong-1.png"));
write_html(#string _inserted_html_
"  alt="Screenshot" class="fitimg" style="width:32%;">
			<img src="
_inserted_html_);
write_var(make_path_absolute("images/odin-games/mario-1.png"));
write_html(#string _inserted_html_
" alt="Screenshot" class="fitimg" style="width:32%;">
			<img src="
_inserted_html_);
write_var(make_path_absolute("images/odin-games/zelda-1.png"));
write_html(#string _inserted_html_
" alt="Screenshot" class="fitimg" style="width:32%;">
            <p>
                These engines were all written in SDL, and were primarily intended for use as a teaching tool. 
                As the semester went on though, we added quite a bit as a class to each game, and that additional code is somewhat hacked on in some cases.
                If you would like to read more about each individual game, please follow the links below.
            </p>
            <ul>
                <li><a href="https://github.com/Stuart-Mouse/odin-mario">odin-mario on GitHub</a></li>
                <li><a href="https://github.com/Stuart-Mouse/odin-zelda">odin-zelda on GitHub</a></li>
            </ul>
            <p>
                Now to be perfectly honest, the code quality on display here could certainly be better.
                Because I was on quite the time crunch, certain aspects are rushed and may not be ideal examples.
                But if you've never written a platformer or top-down game engine before, these examples are simple enough that you could certainly use them as a jumping-off point.
                If I had the spare time to do so, I would definitely like to refactor and improve these (and probably also remove the blatant copyright infringement) so that beginners could use them as a real learning tool.
            </p>
            
            <hr/>
            <h2>OpenEnded</h2>
            <p>
                OpenEnded was an engine I was developing in C for a new precision platforming game.
                As the name implies, it was highly inspired by The End is Nigh, but brought in a lot of ideas from other precision platforming games.
                In particular, the engine has a unique approach to movement, both for the player and the tilemaps in a level.
                My first two devlogs were written about the game's movement components, and although those are now outdated, you may still find them of interest.
                Now, I've essentially ported all the important bits to Jai to continue my work there.
                This game will be released in some form one day, but it will be much more than just a TEiN clone!
                Click <a href="
_inserted_html_);
write_var(make_path_absolute("oe-videos.html"));
write_html(#string _inserted_html_
">here</a> to see some old videos of the game in action.
            </p>
			<img src="
_inserted_html_);
write_var(make_path_absolute("images/open_ended/sc-00.png"));
write_html(#string _inserted_html_
" alt="Screenshot" class="fitimg" style="width:100%;">
            
            <hr/>
            <h2>Wonky Kong</h2>
            <p>
                A new spin on arcade-style platformers like Donkey Kong, Burger Time, Wrecking Crew, and others in that vein.
                Potentially with rouglike elements and competitive multiplayer?
                More to be announced soon! 
            </p>
            
            <hr/>
            <h2>The End is Nigh Mods (and Randomizer)</h2>
			<p>
				These are pretty old and mostly abandoned at this point, but if you're interested in some of my teenage game design efforts, you can check out my TEiN mods.
				I still think they're relatively well-made for what they are, so if you're a fan of the game I hope you can enjoy some new levels to play around with.
				My old TEiN modding page can be seen <a href="
_inserted_html_);
write_var(make_path_absolute("tein.html"));
write_html(#string _inserted_html_
">here</a>.
			</p>
            
            
            <hr/>
        </div>
    </body>
</html>

_inserted_html_);
});

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:9.
//
table_add(*templates, "tein", () {
write_html(#string _inserted_html_
<!DOCTYPE html>
<html>
    <head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>Uzerro's TEiN Modding Page</title>
		<meta name="description" content="Uzerro's TEiN Modding Page">
		<meta name="keywords" content="The End is Nigh,Modding,TEIN,Mod,Manual,Edmund McMillen,Tyler Glaiel,Random,Randomizer">
		<meta name="author" content="Uzerro">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">

		<link rel="shortcut icon" type="image/x-icon" href="images/randomizer/icon.ico">
		<link rel="stylesheet" type="text/css" href="tein.css">
	</head>
    <body>
		<div class="container">
			<div class="contentback"></div>
			<div class="header">
				<h1 class="heading">Uzerro's TEiN Modding Page</h1>
			</div>
			
_inserted_html_);
 call_template("navbar"); write_html(#string _inserted_html_

			<hr>

			<div class="content">
				<h2 class="center">Welcome</h2>
				<p>This is my page for everything I've done related to TEiN modding. More content coming <s>soon</s> never probably.</p>
				<hr>
				
				<div class="center">
					<h2>TEiN Randomizer</h2>
					<table class="columns">
						<tbody>
							<tr>
								<td>
									<img src="images/randomizer/sc4.png" alt="Screenshot" class="tilescrn">
								</td>
								<td>
									<img src="images/randomizer/sc6.png" alt="Screenshot" class="tilescrn">
								</td>
							</tr>
						</tbody>
					</table>
				</div>
				<p>The TEiN randomizer is currently a work in progress, but it already has a ton of features and content. Click <a href="randomizer.html">here</a> or on the nav bar above to learn more.</p>
				<hr>
		
				<div class="center">
			  <h2>Thermo-Damnation</h2>
				<table class="columns">
						<tbody>
							<tr>
								<td>
									<img src="images/mods/thermo1.png" alt="Screenshot" class="tilescrn">
								</td>
								<td>
									<img src="images/mods/thermo2.png" alt="Screenshot" class="tilescrn">
								</td>
							</tr>
						</tbody>
					</table>
				</div>
				<p>This is the name I've given to my main TEiN modding project. My goal is to create a full game replacement mod with several new areas to explore, an altered progression system, and as many new gameplay mechanics as possible.</p>
				<hr>
			
				<div class="center">
					<h2>The Rainbow Goblins</h2>
					<table class="columns">
							<tbody>
								<tr>
									<td>
										<img src="images/mods/goblins1.png" alt="Screenshot" class="tilescrn">
									</td>
									<td>
										<img src="images/mods/goblins2.png" alt="Screenshot" class="tilescrn">
									</td>
								</tr>
							</tbody>
						</table>
					</div>
				<p>An experimental mod focusing on physics modding, challenging level design, and absurd visual design. This mod is named after the Story of the Seven Rainbow Goblins, a very interesting childrens book which inspired some really cool albums.</p>
				<hr>

				<div class="center">
					<h2>Ironsides</h2>
					<table class="columns">
							<tbody>
								<tr>
									<td>
										<img src="images/mods/ironsides1.png" alt="Screenshot" class="tilescrn">
									</td>
									<td>
										<img src="images/mods/ironsides2.png" alt="Screenshot" class="tilescrn">
									</td>
								</tr>
							</tbody>
						</table>
					</div>
				<p>What would happen if The End got flipped on its side? This mod attempts to answer that question by reworking many of the games levels at a 90° rotation from the originals.</p>
				<hr>

				<h2 class="center">Modding Tutorials</h2>
				<p>I'm gonna make them one day, I swear.</p>
				<hr>

			</div>
		</div>
	</body>
</html>
_inserted_html_);
});

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:10.
//
table_add(*templates, "open-ended", () {
write_html(#string _inserted_html_
<!DOCTYPE html>
<html>
    <head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>OpenEnded</title>
		
		<meta name="description" content="OpenEnded">
		<meta name="keywords" content="The End is Nigh,Modding,TEIN,Mod,Manual,Edmund McMillen,Tyler Glaiel,Random,Randomizer">
		<meta name="author" content="Uzerro">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">

		<link rel="shortcut icon" type="image/x-icon" href="images/randomizer/icon.ico">
		<link rel="stylesheet" type="text/css" href="style.css">
	</head>
    <body>
		
_inserted_html_);
 call_template("navbar"); write_html(#string _inserted_html_

			<div class="content">
				<h1>OpenEnded</h1>
				<p>
					The original concept for this project was to be an open-source recreation of the engine for The End is Nigh. 
					As a long-time modder of TEiN, I became dissatsfied with working within the limitations of the original engine and wanted to try my hand at creating something new which I would have more creative control over. 
					As time has gone on, my plans have shifted and I am now more focused on using this project as a chance to explore new types of gameplay for precision platforming, as well as developing my C programming skills generally.
				<p>

				<hr>

				<h2>Development Blog</h2>
				<p>
					For ongoing updates on the game and technical breakdowns of the game's engine, check out the <a href="devlogs/devlogs.html">development blog</a>.
				</p>

				<hr>

				<h2>Videos</h2>
				<p>
					For a collection of various video clips, click <a href="oe_videos.html">here</a>. 
					These clips come from various stages in development, and showcase only a few of the features from the game.
				</p>

				<hr>

				<h2>State of the Project</h2>
				<p>
					This project has been in development for around 9 months now, with more slightly more serious attention during the last 2 or 3 months.
				</p>
				<p>
					Originally, this project began as an open-source remake of The End is Nigh (TEiN), with plans to support new movement mechanics, enemies, and better modding tools. 
					However, over the course of development it has evolved to become an entirely new game with some novel ideas which I have not seen explored quite in the same manner anywhere else before.
				</p>
				<p>
					In this post I want briefly outline the major features of the game's engine (so far) as well as some of the design consideration which have driven my development decisions.
					As a side note: it shouldn't really have to be said, but obviously the current graphics are not at all even remotely representative of the final product. 
					They're only meant to be some bare-bones placeholders so that I can work on making the game functional before making it pretty. 
					And most of the graphics are stolen from Super Mario Bros. anyhow, so that's not going to fly.
				</p>
				<img src="images/open_ended/sc-00.png" alt="Screenshot" class="fitimg" style="width:100%;">

				<h3>Player Physics</h3>
				<p>
					As I developed the new movement mechanics for the game, I began experimenting with modifying the player's physics so that they could retain more momentum. This turned out to be very fun, and since it did not detract from the focus on precision platforming, I continued to modify the player's physics further to suit the type of movement the player could encounter in the world of this new engine.
				</p>
				<p>
					The player's movement has much more weight to it as compared to TEiN. Instead of thinking in terms of your player's position, you'll be thinking more in terms of velocity. This makes handling in very small, precise sections a bit more difficult, but opens up a whole new range of movement options that were not previously possible. The player can make use of the environment to gain and maintain speed, but unlike something like Sonic the Hedgehog, the player has much more stopping power and maintains control across varying speeds.
				</p>

				<h3>Movement Mechanics</h3>
				<p>
					The movement of objects in the game world are governed by a simple, but powerful system with two main structures. These are "Movement Components" and "Progress Controllers". Movement components can be thought of as essentially the "path" that an object moves along, while progress controllers determine the position of an object along said path.
				</p>

				<h4>Movement Components</h4>
				<p>
					The movement of the various tile layers which make up a level are governed by movement components. A movement component is essentially a function of time which reports a position offset along a predetermined path, as well as a rotation. Each movement component references a specific cycle timer which loops after some number of seconds.
				</p>
				<p>
					A tile layer may have multiple movement components which comprise its movement, and combining these components is as simple as adding together the reported offsets. This system allows a level designer to easily create complex systems of movement. 
					Rotations from a movement component can also be used as a second parameter to a later movement component, which will rotate the offset produced around the movement component's local origin.
				</p>
				<p>
					There are currently four basic types of movement components:
					<ul>
						<li>sine movement (circles, ellipses, figure eights, etc.)</li>
						<li>pendulum motion</li>
						<li>linear splines</li>
						<li>bezier splines</li>
						<li>rotation</li>
					</ul>
				</p>
				<p>
					I think this method of conceptualizing the movement of objects is very intuitive and provides a very simple means for designers to come up with new ideas. 
				</p>
				<img src="images/open_ended/sine_movement.png" alt="Screenshot" class="fitimg" style="height:500px;">
				<img src="images/open_ended/sine_movement_markup.png" alt="Screenshot" class="fitimg" style="height:500px;">
				<p>
					For example, in the image above you can see the movement patterns created by some very simple adjustment of the parameters of the sine movement component. 
					You can get some even more interesting results if you start to play with the phase or add a rotation to it.
				</p>

				<h4>Progress Controllers</h4>

				<p>
					Progress controllers are an abstraction on the purpose of what were originally simply timers. These timers would control cycles of motion in a level by reporting global_time % cycle_time. 
				</p>

				<p>
					Previously, the only method of controlling movement components was through the use of cycle timers. Now movement components can be controlled through other means. At the moment, there are only two other kinds of progress controllers, these are:
					<ul>
						<li>gravity</li>
						<li>weighted</li>
					</ul>
				</p>

				<p>
					The gravity controller can be used for any kind of acceleration generally, as it actually has no concept of direction (until applied through a movement component). The weighted controller responds to the contact of the player with a tile layer. If a weighted controller is applied to multiple movement components, you can get some very cool results. 
				</p>

				<h3>Tile System</h3>

				<h4> Tile Types</h4>
				<p>
					The tile system attempts to make tile properties as composable as possible. At the moment, the basic "ground" tile types are Solid, Semisolid, Crumble, and Breakable.
					Solid represents the basic type of a solid tile, while the other three are behavioral modifiers which can all be composed to produce unique results.					
				</p>
				<img src="images/open_ended/tile_types.png" alt="Screenshot" class="fitimg">
				<p>
					Semisolids for each basic solid tile types (solid, crumble, breakable) are pictured on the second row in the image above, and all directional variants of the semisolid tiles are pictured below.
				</p>
				<img src="images/open_ended/semisolids.png" alt="Screenshot" class="fitimg">
				<p>
					In addition to this, tiles can have behavioural modifiers placed on each individual surface. These modifiers are sticky (black), slippery (blue), bouncy (green), conveyor belts (not pictured for lack of presentable graphics), and a purple surface which sets your player's gravity direction to the normal vector of the tile's surface. And of course, these behaviours stack with the behaviours of the root tile that the modifier is applied to.
				</p>
				<img src="images/open_ended/tile_mods.png" alt="Screenshot" class="fitimg">

				<h4>Slopes and Rotation</h4>
				<p>
					In most tile-based games, slopes come in only a few varieties. Typically you'll have about 3 different angles of slopes which are all behave as just standard ground tiles. In this game, all slopes are made up of standard tiles, and can be rotated to any angle. This means that you can have slopes of disappearing or breakable blocks, spikes, bouncy tiles, and more, giving the designer many more options for level design.
				</p>
				<p>
					Because of the emphasis on consistent behaviours on rotated tiles, the entire player physics system is agnostic to the direction of collisions and gravity. This means that the engine also supports gravity in any direction, gravity manipulation, and radial sources of gravity.
				</p>
				<img src="images/open_ended/tile_layer_rotation.png" alt="Screenshot" class="fitimg">

				<h3>Design Considerations</h3>
				<p>
					There are two primary design considerations which have driven many of the decisions I have made through this game's development: composability and designer control. 
					The movement systems are built around the idea of composing basic movement primitives to create more complex patterns. Due to the top-down nature of the game's update loop, a small change to a single timer can be used to modify the behaviours of an entire level.
					The tile system is built around providing the designer with the ability to combine all of the tile behaviours in as many ways as possible, with specific parameters to each behaviour giving even more fine-grain control.
				</p>
				<p>
					The gameplay possibilities are provided by composition, and the tools of the editor provide a means to control these possibilities and shape them to the very particular goals of the designer.
					Not only do the inner workings of the gae need to be as solid as possible in order to acheive the composability of mechanics that I want, but the tools need to be powerful so that I can actually make full use of the mechanics. One can have a very beautiful piece of marble, but without a sharp chisel it would be impossible to shape it into a sculpture.
				</p>

				<h3>Tools</h3>
				<p>
					Speaking of chisels, let's talk about tools. The game has a built-in level editor which allows you to quickly switch between testing and editting with the press of a single button. This allows for tweaking and iterating on levels extremely quickly.
				</p>
				<p>
					The editor is currently a work in progress just as much as the game, but it already has quite a few useful features. 
					In arrange mode, you can arrange all of the tile layers present in the level. 
					In layer edit mode, you can draw tiles into a specific layer, change the rotation of a layer, and set the rotation point of the layer. 
					Tile Layers will automatically grow as you place more tiles to accomodate whatever dimensions you require. 
				</p>
				<p>The editor will render gridlines in the coordinate space of whatever tile layer you are actively editting, so you can easily count spaces between tiles.</p>
				<img src="images/open_ended/editor_gridlines.png" alt="Screenshot" class="fitimg" >
				<p>
					The editor can also render a preview for the path a tile layer will take once the level is in motion. 
					Expect more features to come which will help you further visualize the behaviours of your level, such as viewing the positions and rotations of all objects at a given time.
					In combination with greater control over timers, this should help to greatly expedite the process of lining up the timing of moving platforms relative to one another.
				</p>
				<img src="images/open_ended/editor_paths.png" alt="Screenshot" class="fitimg">
			</table>

			<h3>More to Come</h3>
			<p>
				I could go on and on about any of the individual topics I touched on here (and many more that I didn't), but I'll have to save that for another post.
				As development continues, I will try to write up some more comprehensive posts on the particulars of each of the systems in the game.
			</p>

			</div>
	</body>
</html>
_inserted_html_);
});

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:11.
//
table_add(*templates, "oe-videos", () {
write_html(#string _inserted_html_
<!DOCTYPE html>
<html>
    <head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>OpenEnded</title>
		
		<meta name="description" content="OpenEnded">
		<meta name="keywords" content="The End is Nigh,Modding,TEIN,Mod,Manual,Edmund McMillen,Tyler Glaiel,Random,Randomizer">
		<meta name="author" content="Uzerro">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">

		<link rel="shortcut icon" type="image/x-icon" href="images/randomizer/icon.ico">
		<link rel="stylesheet" type="text/css" href="style.css">
	</head>
    <body>
		
_inserted_html_);
 call_template("navbar"); write_html(#string _inserted_html_

			<div class="content">
				<h1>OpenEnded Video Clips</h1>
				<p>
					Various clips and recordings of the game and the editor.
					Currently, most of the clips posted are gameplay clips, though I plan to add some better clips of the editor in the near future.  
					This page will be updated whenever I create new video clips for the website, so it will be a sort of central repository where you can always find the complete collection of clips. 
				<p>
				<p>
					Apologies for the low framerate on the videos, they've been capped to 15 fps in order to reduce the file size. 
					The actual game runs buttery smooth at 60, 120, or 144 fps.
				</p>

				<hr>

				<h2>Gameplay Clips</h2>
				<p>
					Below are a few small demo levels I created in order to test some of the features as I added them.
				</p>

				<h3>Breakable Tiles / Slopes Test Level</h3>
				<p>
					This level gives the player a little bit of an option about how to approach it. 
					There's a simple route for first-time players, and then a faster (but more technical) route for more experienced players.
				</p>
				<p>The slow route:</p>
				<video controls width="100%">
					<source src="videos/oe_level_1_1.mp4" type="video/mp4"/>
				</video>
				<p>The fast route:</p>
				<video controls width="100%">
					<source src="videos/oe_level_1_2.mp4" type="video/mp4"/>
				</video>
				

				<h3>Easy Test Level</h3>
				<p>
					This level was just made for fun one day, and as a way of testing how the player's physics felt in a standard "World 1"-esque level scenario.
					Like the previous level, there are alternate routes in the level. 
					This is something I want to explore a lot in the earlier worlds. 
					Where the base level designs are simpler, it seems like a fun way to add depth and replay value.
				</p>
				<p>The standard route:</p>
				<video controls width="100%">
					<source src="videos/oe_level_2_1.mp4" type="video/mp4"/>
				</video>
				<p>The faster route:</p>
				<video controls width="100%">
					<source src="videos/oe_level_2_2.mp4" type="video/mp4"/>
				</video>
				<p>The fast backtracking route:</p>
				<video controls width="100%">
					<source src="videos/oe_level_2_3.mp4" type="video/mp4"/>
				</video>

				<h3>Disappearing (Crumble) Tiles Test</h3>
				<p>
					This level initially started as a test of the disappearing tiles, but morphed more into a general test of the slope physics as I built it out.
					I still think the setup with the disappearing tiles at the start is pretty neat though.
				</p>
				<video controls width="100%">
					<source src="videos/oe_level_3.mp4" type="video/mp4"/>
				</video>

				<h3>Spreading Crumble Tiles Test</h3>
				<p>
					This second test level is very short, but it shows the functionality of a second type of crumble tiles which spread to adjacent tiles.
					The "no-sides" semisolid variant of the tile can be used as a sort of "background" crumble tile to connect groups of foreground crumbling tiles together.
					The speed at which all crumble tiles disappear and the speed at which spreading tiles affect their neighbors can be editted on a per-tileset basis. (More about that to come...)
				</p>				
				<video controls width="100%">
					<source src="videos/oe_crumble_2.mp4" type="video/mp4"/>
				</video>
				<p>
					And another test of the spreading crumble tiles.
					This one shows how they can be used as a sort of timer to force the player to navigate a level at a faster pace.
				</p>
				<video controls width="100%">
					<source src="videos/oe_crumble_3.mp4" type="video/mp4"/>
				</video>

				<h3>Bouncy Tiles Test</h3>
				<p>
					This level was a fun test for the bouncy tile modifier.
					I'm quite happy with how this one is functioning at the moment.
					It opens up a lot of possibilities for redirecting the player's momentum and increasing the flow of levels.
					This modifier can be placed on any tile type, as seen with its use on the crumbling tiles in the second obstacle.
				</p>
				<video controls width="100%">
					<source src="videos/oe_level_4.mp4" type="video/mp4"/>
				</video>
				<p>
					This next level is moreso a test of some slightly altered physics code, which made the player much more capable when scaling walls.
					I quickly dialed it back down to a reasonable level, but this test level has made me carefully consider how mobile I want the player to be on steep slopes (since it can be quite fun to just crawl all over a level). 
				</p>
				<video controls width="100%">
					<source src="videos/oe_level_5.mp4" type="video/mp4"/>
				</video>

				<h3>Gravity Manipulation Tests</h3>
				<p>
					This section brings a lot of the previous mechanics together in addition to introducing the gravity tile modifier.
				</p>
				<p>
					But first, a demonstration of how gravity can function in any direction, and with fluidly changing directions.
				</p>
				<video controls width="100%">
					<source src="videos/oe_gravity_1.mp4" type="video/mp4"/>
				</video>

					
				<p>
					This purple surface is the gravity tile modifier.
					When the player comes into contact with the surface, the player's gravity will be set to match the angle of the surface.
				</p>
				<video controls width="100%">
					<source src="videos/oe_gravity_2.mp4" type="video/mp4"/>
				</video>

				<p>
					This mechanic becomes much more interesting when combined with moving/rotating platforms, since the player can use the rotation of the platform and some careful timing to essentially set their gravity direction to whatever angle they choose. 
				</p>
				<video controls width="100%">
					<source src="videos/oe_gravity_3.mp4" type="video/mp4"/>
				</video>

				<p>
					This clip follows a similar idea to the previous clip, however it makes use of relative motion to apply the rotation of the background pillar to the pendulum movement component that governs the moving platform.
					While the explanation may sound complicated, the result is surprisingly intuitive if the player is already familiar with the preceding mechanics.
				</p>
				<video controls width="100%">
					<source src="videos/oe_gravity_8.mp4" type="video/mp4"/>
				</video>

				<p>
					And some more levels with gravity shenanigans. 
					I don't feel that these ones require all that much individual explanation.
				</p>
				<video controls width="100%">
					<source src="videos/oe_gravity_4.mp4" type="video/mp4"/>
				</video>
				<video controls width="100%">
					<source src="videos/oe_gravity_5.mp4" type="video/mp4"/>
				</video>
				<video controls width="100%">
					<source src="videos/oe_gravity_7.mp4" type="video/mp4"/>
				</video>

				<p>
					The following two levels are quite complicated, but they could make for interesting late-game levels.
					The rotation is derived automatically from the sine movement components that are used, similarly to the rotations derived from the pendulum motion in the previous clips.
				</p>
				<p>
					In this first example, we have a double figure eight shape combined with a circle, and the rotation from both of those movements are applied to the platform as well.
				</p>
				<video controls width="100%">
					<source src="videos/oe_gravity_9.mp4" type="video/mp4"/>
				</video>
				<p>
					In this second example, I've used the same basic shapes but I've altered the phase of their cycles relative to one another.
				</p>
				<video controls width="100%">
					<source src="videos/oe_gravity_10.mp4" type="video/mp4"/>
				</video>


				<h3>Player Teleport Test</h3>
				<p>
					This is a bit of a sneak peak for a late-game area mechanic.
					In the level below, the player is able to press a button to save his position in space (but not his velocity).
					Then when pressing the button again, the player teleports instantly to the saved position and sets their previous position as the new saved position.
					Effectively, the player can hop back and forth between the two positions while maintaining a continuous velocity.
				</p>
				<video controls width="100%">
					<source src="videos/oe_level_6.mp4" type="video/mp4"/>
				</video>
				<p>
					This little clips uses the same mechanic, but this time in conjunction with the gravity tile modifer.
				</p>
				<video controls width="100%">
					<source src="videos/oe_gravity_6.mp4" type="video/mp4"/>
				</video>
				<p>
					It may be a bit difficult to follow in these videos, but I blame part of that on the low framerate.
					The other part should be remedied with the addition of some decent sound design, maybe a particle effect, and several levels of introduction. 
				</p>


				<hr>

			</div>
	</body>
</html>
_inserted_html_);
});

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:12.
//
table_add(*templates, "randomizer", () {
write_html(#string _inserted_html_
<!DOCTYPE html>
<html>
	<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>TEiN Randomizer</title>
		<meta name="description" content="The End is Nigh Randomizer Official Webpage">
		<meta name="keywords" content="The End is Nigh,Modding,TEIN,Mod,Manual,Edmund McMillen,Tyler Glaiel,Random,Randomizer">
		<meta name="author" content="Uzerro">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<link rel="shortcut icon" type="image/x-icon" href="
_inserted_html_);
write_var(make_path_absolute("images/randomizer/icon.ico"));
write_html(#string _inserted_html_
">
		<link rel="stylesheet" type="text/css" href="tein.css">
		<script type="text/javascript" src="
_inserted_html_);
write_var(make_path_absolute("slideshow.js"));
write_html(#string _inserted_html_
"></script>
	</head>
	<body>
		<div class="container">
    		<div class="contentback"></div>
    		<div class="header">
    			<h1 class="heading">The End is Nigh Randomizer</h1>
    		</div>
    		
_inserted_html_);
 call_template("navbar"); write_html(#string _inserted_html_

    		<hr>
        		
    		<div class="content">
    			<h2 class="center">About</h2>
    			<p>
    				<img src="
_inserted_html_);
write_var(make_path_absolute("images/randomizer/icon.png"));
write_html(#string _inserted_html_
" alt="Randomizer Icon" id="randoicon">
    				The End is Nigh Randomizer is a nifty little program that shuffles around all the levels in the game and creates a new world for you to play through.
    				It is also capable of randomizing the palettes, tilesets, overlays, particle effects, shaders, and more!
    				Every playthrough will give you a unique experience.
    			</p>
    			<hr>
    
    			<h2 class="center">Download</h2>
    			<p>You can find the project on GitHub <a href="https://github.com/Stuart-Mouse/TEiN-Randomizer">here</a>.<br/>Alternatively, you can download the program directly <a href="https://github.com/Stuart-Mouse/TEiN-Randomizer/releases/download/0.9.2/Release092.zip">here</a>.</p>
    			<hr>
    			
    			<h2 class="center">Screenshots</h2>
    			<!-- Slideshow container -->
    			<div class="slideshow-container">
    
    				<!-- Full-width images with number and caption text -->
    				<div class="mySlides fade">
    					<img src="
_inserted_html_);
write_var(make_path_absolute("images/randomizer/sc4.png"));
write_html(#string _inserted_html_
" style="width:100%">
    				</div>
    
    				<div class="mySlides fade">
    					<img src="
_inserted_html_);
write_var(make_path_absolute("images/randomizer/sc6.png"));
write_html(#string _inserted_html_
" style="width:100%">
    				</div>
    
    				<div class="mySlides fade">
    					<img src="
_inserted_html_);
write_var(make_path_absolute("images/randomizer/sc10.png"));
write_html(#string _inserted_html_
" style="width:100%">
    				</div>
    
    				<div class="mySlides fade">
    					<img src="
_inserted_html_);
write_var(make_path_absolute("images/randomizer/sc17.png"));
write_html(#string _inserted_html_
" style="width:100%">
    				</div>
    
    				<div class="mySlides fade">
    					<img src="
_inserted_html_);
write_var(make_path_absolute("images/randomizer/sc19.png"));
write_html(#string _inserted_html_
" style="width:100%">
    				</div>
    
    				<div class="mySlides fade">
    					<img src="
_inserted_html_);
write_var(make_path_absolute("images/randomizer/sc3.png"));
write_html(#string _inserted_html_
" style="width:100%">
    				</div>
    
    				<div class="mySlides fade">
    					<img src="
_inserted_html_);
write_var(make_path_absolute("images/randomizer/sc5.png"));
write_html(#string _inserted_html_
" style="width:100%">
    				</div>
    
    				<!-- Next and previous buttons -->
    				<a class="prev" onclick="step_slides(slideshow, -1)">&#10094;</a>
    				<a class="next" onclick="step_slides(slideshow, 1)">&#10095;</a>
    			</div>
    			<br>
                
    			<!-- The dots/circles -->
    			<div style="text-align:center">
    				<span class="dot active" onclick="set_slide(slideshow, 0)"></span>
    				<span class="dot active" onclick="set_slide(slideshow, 1)"></span>
    				<span class="dot active" onclick="set_slide(slideshow, 2)"></span>
    				<span class="dot active" onclick="set_slide(slideshow, 3)"></span>
    				<span class="dot active" onclick="set_slide(slideshow, 4)"></span>
    				<span class="dot active" onclick="set_slide(slideshow, 5)"></span>
    				<span class="dot active" onclick="set_slide(slideshow, 6)"></span>
    			</div>
    			
    			<script>
    			    var slideshow = make_slideshow("mySlides", "dot");
    			</script>
    		</div>
		</div>
	</body>
</html>
_inserted_html_);
});

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:13.
//
table_add(*templates, "randomizer-dev", () {
write_html(#string _inserted_html_
<!DOCTYPE html>
<html>
	<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>TEiN Randomizer</title>
		<meta name="description" content="The End is Nigh Randomizer Official Webpage">
		<meta name="keywords" content="The End is Nigh,Modding,TEIN,Mod,Manual,Edmund McMillen,Tyler Glaiel,Random,Randomizer">
		<meta name="author" content="Uzerro">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<link rel="shortcut icon" type="image/x-icon" href="images/randomizer/icon.ico">
		<link rel="stylesheet" type="text/css" href="style.css">
	</head>
	<body>
		
_inserted_html_);
 call_template("navbar"); write_html(#string _inserted_html_

	
		<div class="container">
			<div class="contentback"></div>
			<div class="header">
				<h1 class="heading">Randomizer Development Updates</h1>
			</div>

			<hr>

      <div class="content">

        <h2 class="center">Post-Mortem on the TEiN Randomizer</h2>

        <h3>Moving on to Better Things</h3>
        <p>
          So at this point, I think it is safe to say that the randomizer is basically dead, which is sad because I feel as though it hardly got a chance to live. 
          The primary reason I'm no longer working on this is because I lost interest, and got tired of dealing with the limitations of what I could reasonably do without the ability to write the randomizer directly into the game engine. 
        </p>
        <p>
          I still think this randomizer is one of the most ambitious randomizers out there, and I think some of the ideas that I implemented (and those which never saw the light of day) were some of the most unique and most fun of any randomizer.
          The core features are still very fine on their own, and if the game's community weren't so dead (or if I had released the randomizer at a much earlier date), it probably would have been a lot more sucessful in terms of people actually playing it.
        </p>
        <p>
          In this post, I want to describe some of the parts of the randomizer that I find the most interesting, and which may have applications in other randomizers or game design generally.
        </p>

        <h3>Theory of Randomization</h3>
        <p>
          Before diving into specific features, I want to describe the basic idea behind what a randomizer is supposed to accomplish, specifically in the context of a platforming game.
          <br/>
          The most basic features of most platforming game randomizers are:
        </p>
        <ul>
          <li>change the order of levels</li>
          <li>change how the game looks and sounds</li>
          <li>change the layouts of levels in non-game-breaking ways</li>
        </ul>
        <p>
          The goal of these changes is to leave the core game experience intact, but to add just a little diversity to repeat playthroughs so that they break up your muscle memory and make you rethink how to approach certain sections. 
          Typically, changes within levels are slight, because one of the main goals of any randomizer is not to allow the randomizations to produce an un-winable game. This makes altering level layouts more drastically very difficult, as this usualy results in one of two outcomes:
        </p>
        <ul>
          <li>Levels are altered (or generated) in such a way that they are possible, yet boring.</li>
          <li>Levels are altered (or generated) in such a way that they are more interesting, but risk being impossible.</li>
        </ul>
        <p>
          So the goal is to create randomizations that do just enough to trip up the player and keep things interesting, without impeding the base gameplay from expressing itself or making the game impossible.
          This is a very delicate balancing act and it represents the central design challenge of game randomization.
          For some games, it is possible to write a procedural algorithm which produces fun levels, however the degree to which  this is possible scales inversely with the complexity of the game.
        </p>

        <h3>The Basic Features</h3>
        <p>
          The basic features which have been implemented in the randomizer since virtually the first release all fit into the category of basic features that most randomizers support.
          These include changing the order of levels, selecting random music tracks for each area, and randomizing visuals such as color palettes, shaders, particle effects, and tile graphics.
        </p>
        <p>
          This randomizer also later included more sophisticated particle effect randomization, which could generate unique particle effects not seen in the base game.
          While these features are cool on their own, I wanted to push the set of features further and experiment with some new ideas.
        </p>

        <h3>Advanced Features</h3>
        <p>
          Now we finally get into the meat and potatoes.
          Over the rest of this post, I will expand on specific features and try to explain how they relate to the aforementioned central design theory of game randomizers.
        </p>

        <h3>Level Corruptions</h3>
        <p>
          This is perhaps the most simple of the advanced features, as it stems from a very simple core idea. 
          However, there was still some care taken to explore a more interesting permutation of the idea rather than to simply provide the most straightforward implementation.
        </p>
        <p>
          The idea of level corruptions comes from the video game emulation scene, stemming from the days of cartridge-tilting and memory modifiers like the Game Genie.
          By creating plugins for emulators that periodically change the values of random addresses in memory (thereby "corrupting" the system's memory), one can see very interesting and entertaining side-effects.
          Of course, this experience often ends with the game crashing and needing to be reset, but in the mean time it offers a distinct experience of exploring the very fringes of a game's mechanics.
        </p>
        <p>
          Similarly, my randomizer's corruption engine will operate on the game's levels, replacing data (somewhat) randomly.
          This "somewhat" is important because we do not *really* want to allow total chaos, which would likely result in much more difficult or unfair gameplay.
          Instead, the tiles which make up a level are replaced based on a lookup table of tiles which are deemed more or less interchangeable.
          This nearly always guarantees that levels remain playable while also mixing things up both visually and tactically.
        </p>
        <p>
          Additionally, the radomizer features controls to tailor the corruptions to the particular desires of the player.
          If one has a higher level of experience and wants the corruption engine to run a little more wild, they can activate further corruption patterns and turn up the density of corruptions.
        </p>

        <h3>Physics Randomization</h3>
        <p>
          This is definitely the most interesting of any of the features implemented in the released builds.
          However, it is also the feature of most questionable quality, as it results extremely unpredictable gameplay that will require skipping many levels.
        </p>
        <p>
          There are two major components that go into making a set of randomized physics which are reasonably within the range of making levels possible. 
          These are the player's movement speed and jump height.
        </p>
        <p>
          There is a predefined range of valid jump heights which can be used, but it is not quite as simple as just selecting a random number within a given range. 
          The game also supports double/triple/etc. air jumps, so in order to expand the range of possible jump heights, these bonus jumps are calculated as part of the player's jump height. 
          IIRC the number of jumps that the player will have is selected first, then the jump height is divided by the number of jumps to get the height per jump.
        </p>
        <p>
          The player's movement speed has a much wider range of accepted values, which often results in the player being too slow to complete a level or so fast as to be uncontrollable. 
          However, this is accepted because of the possibility that it forces the player to use ledge jumps to maneuver, which can lead to more interesting gameplay. 
        </p>
        <p>
          There are other variables involved which can result in much deeper intricacies to the resulting gameplay, however I won't go into all of those at this time.
        </p>

        <h3>Map Generation</h3>
        <p>
          This topic could warrant an extensive post of its own, but I'll attempt to give a brief idea of how map generation works in the TEiN Randomizer. 
          The maps in TEiN are stored as a csv file, where each level is reprented by a file name in a cell of the spreadsheet.
          This means that internally, we can just store areas in a 2D array.
          However, there are some complications such as the addition of ".." cells, which the game skips over when checking for the adjacent level to connect to.
          This means that we can technically build very non-euclidean maps, in which paths can cross over one another and distances can be artificially shortened.
          This feature actually becomes essential for generating full game maps, as it is important in linking together separately generated areas into a cohesive whole.
          <br/>
          In the end, the structure of the randomization system is roughly as follows:
        </p>
        <ul>
          <li>At the highest level, areas are connected in a linked-list type structure, but with nodes connecting, potentially, in all four directions.</li>
          <li>At the level of areas, screens are placed procedurally directly into a 2D array.</li>
          <li>At the lowest level, there is a complex, though quite optimized, procedure for checking compatibility between the connection types of individual screens.</li>
        </ul>

        <h3>Full Level Generation</h3>
        <p>
          Level generation works by linking together small level pieces, which typically contain only one or two obstacles.
          The generator would use some additional data provided with each piece to determine how these peices could/would connect, and placed them one-by-one while also taking into account the structure of the overall level.  
        </p>
        <p>
          As far as I got with the implementation, pieces would only be placed from linearly from left-to-right, however it would not have been much more effort to add vertical connections and allow building backwards in certain cases.
          After all of the pieces have been placed which will make up the level, ceilings and floors are filled in, and "out-of-bounds" areas are generated.
        </p>
        <p>
          There were additionally plans to write an auto-decorator, which would generate background elements based on the layout of foreground tiles, however this was not completed due to placing the entire level generator on hiatus.
          The main reason the level generator was not finished was because of the time-consuming nature of creating enough level pieces as input data to be able to properly test and deploy the generator in a release build.
        </p>

        <h3>Color Tiles</h3>
        <p>
          Taking a step back from full level generation, I wanted to establish some way to create smaller randomizations which were more finely tuned, retaining the feeling of being hand-crafted.
          The resulting solution was perhaps the best idea to come out of the randomizer's development: color-coded tiles for which specific randomization rules are defined over a set of contiguous tiles.
        </p>
        <p>
          These give very fine-grain control over "micro-randomizations", and are useful for creating the basic template of an idea for a level and then letting randomization fill in the rest.
          They are also useful for creating different arrangements of challenges which exist in the same basic space.
          Below are some short descriptions of the various colors' functions.
        </p>
        <p>
          Blue: <br/>
          Represents a basic category of tiles/entities with similar enough characteristics as to be relatively interchangeable. 
          For example, tall spikes and short spikes are lumped into one group so that the designer can simply draw a straight line of blue spikes and let the randomization engine decide whether to place tall or short spikes at each specific index.
        </p>
        <p>
          Yellow: <br/>
          Places a given number of a tile within a specified area of contiguous yellow tiles. 
          (e.g. "Place X number of spikes on the top of this platform.") 
          Can be used to guarantee playability while offering potentially hundreds/thousands of minor permutations of a level. Can also be used with objects of different types. 
          (e.g. "Place either a cannon on this platform, or a fish spawner in the water here.")
        </p>
        <p>
          Red and Green Tiles: <br/>
          Originally these were more different, but they have become almost the same now with one subtle difference. 
          Red/green tiles will collect all contiguous red/green tiles' indices and put them into a list. 
          Then, iterating over the list, will flip a weighted coin on whether or not to place the tile into the level. 
          Additionally, the use of number tiles can guarantee that no more than a certain number of solids or blanks are placed in a row. 
          (For example, we could lay out a straight row of red solid ground tiles and attach a number 5 tile. This would result in a randomized row of ground tiles with the guarantee that there will be at least one ground tile every 5 tiles, that way we know our player will be able to cross the gap.) 
          The difference between red and green tiles now is only that red tiles will only selected contigues red tiles of the exact same tileID, which green tiles will select ALL contiguous green tiles regardless of specific tileID. 
          Without over-explaining the difference here, I will simply say that it is a very useful distinction to make.
        </p>
        <p>
          Used in tandem with the level generation scheme described above, I think a full level generation system could be devised which creates relatively unique levels while still feeling as though it was designed by a human.
          Of course, procedurally generated levels will never reach the level of quality of truly hand-made levels, but they can provide a solid experience in their own right.
        </p>

        <h3>Lessons Learned</h3>
        <p>
          In the realm of slightly less technical things, there were also some takeways which have influenced the direction for my next project, OpenEnded, which is to some degree a successor to the randomizer.
        </p>
        <p>
          I have decided to develop my new project in C, rather than C#. 
          The saying that "In the beginning, all one wants is results, and in the end all you want is control," is very true.
          I found myself constantly at odds with the opinionated language design of C#, and when I needed to optimize sections of code, I struggled more to find out how to get around the abstractions of C# than I did to write the necessary algorithms.
          And in the end, there are many optimizations that would have been highly useful which I simply could not reasonably implement in C#.
        </p>
        <p>
          The decision to use C# was originally made so that I could easily draft up a user interface using WPF, but in the long run it became a burden.
          It was also incredibly inefficient to perform all of the randomization upfront, and then write everything to data files for the game to load. 
          Unfortunately, this is the only real way to implement this program without writing a much more complex system for meddling directly with the game's process memory.
        </p>

        <p style="font-size: 10pt;">This post may later be expanded further as a video thing, so if I ever get around to that, I'll be sure to post a link back here.</p>

			  <hr>

        <h2 class="center">A Brief History of the TEiN Randomizer</h2>

        <p>
          As the first real dev update, I think a recap is probably in order. I first started working on the current incarnation of the randomizer this February (2021).
          I say this incarnation because I did make a basic TEiN randomizer back in 2018 in Python. Unfortunately this program was not very good and I gave up on it relatively soon after starting it.
          Since starting work on this new version, I have continued to add new features throughout the year, until recently when I realized I was running out of things to randomize.
          Now I am beginning work on the map generator, which I believe will totally overhaul the randomizer experience.
        </p>

        <h3>Adding Basic Features</h3>
        <p>
          My initial plan was to rewrite the original Python randomizer in C++ (which took hardly any time at all) and then begin adding new features. Perhaps the most important feature however, is a menu.
          At this point I looked to the TEiN mod loader, which had a simple, well functioning UI. Although I had never working in C# before, I decided to build the randomizer on top of the mod loader.
          I learned the basics of C# and how to use WPF in order to customize the menu (which has now gone through several iterations).
          After a month, I put up the first public release (version 0.9), which already had randomization of music, palettes, shaders, particles (including a custom particle generator), overlays, tile graphics, and art alts, as well as support for modded levels.
          Basically anything I could possibly randomize simply by manipulating the data files was already supported.
        </p>

        <h3>Subsequent Releases</h3>
        <p>
          The next release came two months later. The big improvement here was the inclusion of level corruptors and physics randomization.
          Adding level corruptors was a big deal to me because this entailed being able to read in and algorithmically edit level files.
          This opens up tons of possibilities for modifying gameplay with the use of simple rulesets/functions.
        </p>
        <p>
          After working with the corruptors and getting a handle on manipulating level files, I began working on a level generator which would build levels by connecting random level pieces together.
          This is still not complete, as I've put off finishing this in favor of working other features which I think will add more value to the experience (namely the map generator).
        </p>
        <p>
          The physics randomization is still a bit janky to this day (there's not much getting around this), but it was designed in order to maximize the chances of getting something that is relatively playable.
        </p>
        <p>
          The menu had also been reformatted to be much more readable, as the level pools, settings, etc. had been moved to seperate tabs.
          Some modding tools were also included that would manipulate levels in ways not supported by the TEiN Editor.
        </p>
        <p>
          The final official release added NPC randomization, as well as some slight menu improvements. There's not much else to be said about this one.
        </p>
        <p>
          There was however another release that I sent out to testers in the TEiN Modding Discord channel, but I guess I forgot to upload it on Github.
          This build re-implemented mod loading (including multi-mod loading), and added a few mod randomization options. This is a feature I would like to expand further after finishing the map generator.
          There were also further menu improvements and improved corruptor settings which allowed for a more fine-tuned experience.
        </p>

        <h3>Where to go from here?</h3>
        <p>
          Throughout the entire development process, there was always the looming question of what feature could be added next. The scope of the project has continually expanded further than I expected it could.
          Now, there are three main features that remain:
        </p>
        <ul>
          <li>map generation</li>
          <li>game memory manipulation</li>
          <li>level generation</li>
        </ul>
        <p>
          Each of these features poses a unique challenge in its implementation, but I think the potential rewards make the challenge worth it.
          I would like to go into each of these in more detail at a later date, because I find them all very interesting.
        </p>
        <p>
          Well, that's all for this first post. It's probably already far too long-winded anyways.
          I will probably go more in-depth on individual aspects of the randomizer at a later time, but that time is not now.
        </p>
        
      </div>  

    </div>
  </body>
_inserted_html_);
});

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:14.
//
table_add(*templates, "devlogs", () {
write_html(#string _inserted_html_
<!DOCTYPE html>
<html>
    <head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>OpenEnded</title>
		
		<meta name="description" content="OpenEnded">
		<meta name="keywords" content="The End is Nigh,Modding,TEIN,Mod,OpenEnded,devlog,gamedev">
		<meta name="author" content="Uzerro">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">

		<link rel="shortcut icon" type="image/x-icon" href="images/randomizer/icon.ico">
		<link rel="stylesheet" type="text/css" href="../style.css">
	</head>
    <body>
		
_inserted_html_);
 call_template("navbar"); write_html(#string _inserted_html_

		<div class="content">
			<h1>Development Blog</h1>
			<p>
				On this page, you can find links to all of my development blog posts.
			<p>
					
			<hr>
			
			<h2>Contents</h2>
			<p>
				Posts are organized by project and numbered chronologically.
			</p>

			<h3>OpenEnded</h3>
			<ul>
				<li><a href="oe1_movement_101.html">#OE1 - Movement 101</a></li>
				<li><a href="oe2_movement_102.html">#OE2 - Movement 102</a></li>
			</ul>

			<hr>

		</div>
	</body>
</html>
_inserted_html_);
});

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:15.
//
table_add(*templates, "devlogs-oe1_movement_101", () {
write_html(#string _inserted_html_
<!DOCTYPE html>
<html>
    <head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>OpenEnded</title>
		
		<meta name="description" content="OpenEnded">
		<meta name="keywords" content="The End is Nigh,Modding,TEIN,Mod,OpenEnded,devlog,gamedev">
		<meta name="author" content="Uzerro">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">

		<link rel="shortcut icon" type="image/x-icon" href="images/randomizer/icon.ico">
		<link rel="stylesheet" type="text/css" href="../style.css">
	</head>
    <body>
		
_inserted_html_);
 call_template("navbar"); write_html(#string _inserted_html_

			<div class="content">
				<h1>#OE1 - Movement 101</h1>
				<p>
					This is probably a good place to start for the first real individual-topic development post, since the movement mechanics of this game are really fundamental to everything I'm trying to do here. 
					I'll try not to wax on about the design philosophy and the "why" behind it all in this post (though I'm sure to do that at some point), instead I'll try to present the "how" as clearly as I can. 
					I will also be skipping over a lot of the complexities that have emerged around this system as it's become more developed so you can get an idea for the basic concepts first.
				<p>
						
				<hr>
				
				<h2>A Broad Overview</h2>
				<p>
					Let's start with the basics.
					The game world is made up of several individual tilemaps I call "tile layers". 
					Tile layers come in all shapes and sizes, and they all have somewhere to be (that is, they have some defined location in the broader world). 
					Knowing where a tile layer is gives us the power to do all sorts of things like render it on the screen and let the player interact with it. 
					But many tile layers don't just sit still, they move around giving us all kinds of fun obstacles to contend with. 
					Some of them even spin too.
				</p>
				<img src="../images/open_ended/devlogs/oe1_tile_layers.png" alt="Screenshot" class="fitimg" style="width:100%">
				<p>
					But in order to move, tile layers need to know where they're going. 
					In this game, we like to keep things predictable, so tile layers (basically) always move along a predetermined path. 
					In order to accomplish all sorts of interesting types of movement, we construct these paths from simple primitives. 
					These primitives of movement are called "movement components".
				</p>
				<p>
					Each movement component describes a simple path. 
					This can be a line (or series of lines), circle, ellipse, curvy line (or series of curvy lines), or the path traced by a pendulum.
					These are the five basic types of movement components:
					<ul>
						<li>linear splines (straight lines)</li>
						<li>bezier splines (curvy lines)</li>
						<li>sine movement  (circle, ellipse, figure-eight)</li>
						<li>pendulum</li>
						<li>rotation</li>
					</ul>
					Rotation is a bit of a special case, so we won't really be talking about it until Movement 102.
				</p>
				<p>
					Movement components generally represent a closed path (one where the start and end point are the same), though this is not always the case.
					This is because in a platforming game, you usually want motion to be cyclical. 
					This gives the player another chance if they "miss the bus" on a moving platform so-to-speak. 
				</p>
				<p>
					But even if we have a path, we need to know how quickly we are supposed to move down it. We have the "where" but not the "when". 
					So the last piece of our puzzle is to introduce the concept of a timer.
					A timer lasts for some number of seconds, and if we start a timer when the level starts we can use our progress through the timer to determine where we need to be along our path. 
					For example, if we have a path that is a straight line 5 units long and a 6-second timer, then we know that at 3 seconds we should be 2.5 units down the line (because 50% of our time has elapsed, we have traveled 50% of the distance).
					The same principle applies for a curvy line or a circle just the same, but instead of traveling a straight line we follow a curve, or a path of any arbitrary shape.
				</p>
				<p>
					Like I mentioned about the paths above, we usually want movement to by cyclical. 
					So instead of simply starting a timer and then stopping it when it's expired, we allow it to loop on its n-second long cycle.
				</p>
				<p>
					Using some simple math, we can determine our progress through any given cycle using only the global time since the level began.
				</p>

				<pre><code class="code">time_in_cycles = global_time / cycle_time;
current_cycle  = floor(time_in_cycles);
progress       = time_in_cycles - current_cycle;</code></pre>

				<p>
					We divide the global time by the number of seconds per cycle to get the number of cycles which have elapsed since start. 
					The integer portion of this value is the number of whole cycles completed, and the fractional portion is the percent progress in the current cycle. 
					We can then use this progress value to determine our offset in space by interpolating along the path of our movement component.
				</p>
				<p>
					As I mentioned above, we can also build more complex types of motion from our simple movement primitives. 
					This is as easy as adding together the offsets of multiple movement components.
					If we apply the same movement component to two tile layers, and then add a second movement component to only one of the tile layers, the apparent result is motion of one tile layer relative to the other.
				</p>

				<p>
					Hopefully you've understood everything up until now, because we've essentially worked backwards to explain how the system works.
					In practice, we start with the timers, then update our movement components to obtain our position offsets, and then finally apply those offsets to our tile layers.
					It is important to keep in mind the relationships between these objects. 
					Each movement component has a one-way dependency on a timer (but many movement components may share the same timer), and each tile layer depends on any number of movement components to determine its final position for that moment in time. 
					And at the very source of it all, each timer is simply a product of subdividing the global time into smaller sections.
				</p>

				<hr>

				<h2>Implications</h2>
				<p>
					We can use this top-down control to our advantage, as it gives us a singular point of control over the entire level. 
					The global timer may be the single most important variable in the game, because it ultimately determines the location of all the tile layers in the game world.
				</p>
				<p>
					If you're an astute reader, you've likely noticed that we can compute the positions of all tile layers in the game discretely. 
					That is to say, we don't depend on any state that carries over from the previous frame(s). 
					The game update loop proceeds linearly from the most basic constructs in the game to the most complex, bootstrapping from almost nothing to the state of the world and all of its complex interactions every single frame.
					We can compute the positions of all the tile layers at any given time just as easily as computing them for the next frame, and the entire operation of the world is deterministic. 
					I'll save the diatribe on time manipulation shenanigans for antoher post, but needless to say, there will be some by the time this game's development is all said and done.
				</p>
				<p>
					Anyways at this point (once we know the locations of all the tile layers for a given frame), we can finally run our player update loop and allow the player to interact with all the tile layers that make up the world. 
					In a game based around movement and the player's interactions with it, we definitely want to know more than just position however, we also need to know velocity.
					In most games, its trivial to determine the velocity of an object because the world operates in a relatively continuous manner.
					In the traditional model, forces apply some acceleration on an object which changes its velocity, and then the velocity is applied to position on each frame.
					Since we determine position from scratch every single frame, we actually have to work the opposite direction and derive our velocity from position.
					When time is operating normally, we just subtract our current position from our previous position in order to determine the instantaneous velocity of our tile layers. 
					Again, we'll talk about when time is not operating normally in another post.
					We never really need to know the acceleration of a tile layer, but it could be derived similarly if the need arose.
				</p>
				<p>
					Though it's probably a bit unconventional, hopefully you can start to see some of the utility in such a system of movement.
					I know I said this post would mostly focus on the "how" and not the "why", but I would be remiss not to outline just a few of the reasons for using this system.
				</p>


				<p>
					Firstly, the amount of possibilities you can acheive by composing the simple movement primitives is actually insane.
					I have yet to see a platforming game which does as much with moving platforms as can already be done in this engine.
					Of course, it's a lot of work to present each of those ideas in an interesting and approachable way and if your game is not *just* about jumping on moving platforms, I can understand why you would put your focus elsewhere. 
					Lucky for me, this game is basically just about jumping on moving platforms, so I get to explore all ten million ways of doing that.
				</p>
				<p>
					Secondly, and this reason is related to the first, it gives far more control to the designer of a level to express the particular ideas they want to express, without needing to get caught up on what should be trivial side effects.
					Designing levels using this system of timing means that we are thinking about movement less in terms of speed and moreso in terms of time-to-complete, which is a subtle but meaningful difference. 
					Instead of having two platforms which move at a given speed, and then trying to coordinate their movement relative to once another by moving them around or changing their speed manually and hoping for the best, we can be assured of a platform's location at critical points in time. 
					I can't tell you how many times I've had platforms de-synchronize while modding The End is Nigh because one of them has to move one tile further than the other and cycle time is a product of distance and speed rather than speed being a product of time and distance.
					I really do not care if a platform moves at 4.5 tiles/second or 5.2 tiles/second, so long as it stays coordinated with the other elements of the level.
				</p>
				<p>
					Anyways, that about wraps up all I want to write for this post at the moment. 
					I'm bound to have forgotten something but either I'll just add that back in her elater or mention it in the next post.
					I hope you were able to get something out of this and it was worth your time, so until the next one, have a good one.
				</p>

				<hr>

			</div>
	</body>
</html>
_inserted_html_);
});

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:16.
//
table_add(*templates, "devlogs-oe2_movement_102", () {
write_html(#string _inserted_html_
<!DOCTYPE html>
<html>
    <head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<title>OpenEnded</title>
		
		<meta name="description" content="OpenEnded">
		<meta name="keywords" content="The End is Nigh,Modding,TEIN,Mod,OpenEnded,devlog,gamedev">
		<meta name="author" content="Uzerro">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">

		<link rel="shortcut icon" type="image/x-icon" href="images/randomizer/icon.ico">
		<link rel="stylesheet" type="text/css" href="../style.css">
	</head>
    <body>
		
_inserted_html_);
 call_template("navbar"); write_html(#string _inserted_html_

			<div class="content">
				<h1>#OE2 - Movement 102</h1>
				<p>
					In the previous post, I described how the basics of the movement system for this game work. 
          If you haven't read that post, it may be a good idea to at least read the first part before starting this one.
          Today, I'm going to go over how to specify timers and movement components for a simple level in GON markup.
				<p>
						
				<hr>
				
        <h2>Understanding GON</h2>  

        In GON, all data is essentially a key/value pair, where the key is the object's name, and the value can be anything that can be expressed as text.
        In the example below, we have two key/value pairs: "type" has a value of "timer" and "seconds" has a value of "10".
        Both of these fields are nested inside an object, specified by the { curly braces }.
        This object is named "my_timer_1", and just like the fields inside it, the name directly precedes the value.

				<pre><code class="code">my_timer_1 {
  type    timer
  seconds 10
}</code></pre>

        When the game loads a level, it reads the corresponding GON file in order to initialize the variables that describe all of the timers and movement components in the level.
        (The technically inclined among you may notice that this is less efficient than using a binary format, but the benefits of using a human-readable format for easy editting outweighs the drawbacks at this point in development.)
        You can define many timers for your level in a root object called "progress_controllers". 
        (The reason for this name will be explained in the next post.)
        Likewise, your movement components will be in a root object called "movement_components".

        Here's an example of a more fleshed out file:

<pre><code class="code">progress_controllers {
  timer_1 {
    type    timer
    seconds 10
    looping reverse
  }
}

movement_components {
  figure_8 {
    type        sine
    controller  timer_1
    amplitude   [ 5, 10 ]
    frequency   [ 3, 1 ]
    phase       [ 0, 0 ]
  }
}

tile_layers {
  tl_figure_8 { 
    movement [figure_8]
  }
}</code></pre>

        <p>
          In this example, we have a ten second timer, a figure-eight movement component, and a tile layer that uses that movement component.
          You may have also noticed the [ square brackets ] with multiple values inside them. This is called an array.
          It's very similar to an object in GON, except that the values within do not have names.
          The commas between values are also not necessary, but they don't hurt anything either, so you can use them if you like or ignore them.
          We use an array to specify the values for amplitude, frequency, and phase because they have both an x and y component.
          We do the same for specifying the movement components in the tile layers, because a tile layer may have more than one movement coponent.
        </p>

				<hr>

        <h2>Declaring Movement Components</h2>  

        <p>
          If all of that makes sense to you so far, then we'll get into declaring specific types of movement components.
          We will talk more about timers in a future post, but for now all you need to know is that you can change the number of seconds a timer takes to complete.
        </p>

        <h3>Sine Movement</h3>
        <p>
          First, lets look at the sine movement type:
        </p>
        
        <pre><code class="code">circle {
  type        sine
  controller  timer_1
  amplitude   [ 5, 5 ]
  frequency   [ 1, 1 ]
  phase       [ 0, 0.25 ]
}

ellipse {
  type        sine
  controller  timer_1
  amplitude   [ 5, 10 ]
  frequency   [ 1, 1 ]
  phase       [ 0, 0.25 ]
}

figure_8 {
  type        sine
  controller  timer_1
  amplitude   [ 5, 10 ]
  frequency   [ 3, 1 ]
  phase       [ 0, 0 ]
}</code></pre>

        <p>
          Sine movement components can be used to make circles, ellipses, figure-eights, or any other simlar shapes which are comprised of sine- or cosine-based movement.
          Sine movement components have both an x and y component. This is done to allow more easily configuring the relationship between the axes and ensuring that cycles remain consistent. Additionally, it ensures that movement on both axes refers to the same timer.
          There are three values which can be tweaked to produce different movement shapes. These are Amplitude, Frequency, and Phase.
        </p>

        <h4>Amplitude</h4>
        <p>
          Amplitude specifies the distance of travel from the origin point on each axis. 
          When x and y values for amplitude are the same, the result will be a circle of radius x (or y if you prefer). 
          When amplitude values are different, the resulting shape is an oval.
        </p>

        <h4>Frequency</h4>
        <p>
          Frequency specifies the number of cycles each axis will complete during one full cycle of the movement component as a whole. 
          What's relevant here is the ratio between the x axis and the y axis. 
          Say for example that the x axis has a frequency of 2 while the y axis has a frequency of 1. 
          This means that the platform completes a horizontal cycle in half the time it takes to complete a vertical cycle. 
          Then the resulting shape produced by the movement component is that of a vertical figure eight. 
          Likewise, we can add more loops by increasing the x frequency further, or we can create horizontal figure eights by increasing the y value when the x value is set to 1.
        </p>
        
        <p>
          Fractional values can produce very odd results, and may produce discontinuities (jumps in position). 
          For this reason, it is recommended that you stick to integer values. 
          It is possible to create some cool shapes with fractional values, but you have to think carefully about the relationship between the frequency and y phase (an aspect of the cycle offset which will be explained in the following section) in order to prevent discontinuities.
        </p>
        
        <h4>Phase</h4>
        <p>
          Phase is given in two components, base phase and y phase (as opposed to simply x and y components).
          The base phase is applied to both the x and y axis cycles, while the y phase is computed relative to the x axis. 
          Both of these offsets are normalized from 0 to 1 as a factor of 2pi. This is much more useful than using absolute numbers.
          Using a base phase allows the designer to shift the starting position along a sine movment component without affecting the shape of the movement component. 
          The Y phase however, will change the shape of the movement component and the starting position. 
          I would recommend playing with the phase of the movment component first in order to find the desired shape, and then use the base phase to adjust the starting point. 
          Keep in mind that the direction of travel along the movement component is ostensibly controlled by the Y Phase, since all phase values from 0 to 0.5 mirror those from 0.5 to 1. 
          Therefore, if you want to maintain the shape of a Sine MC and reverse the direction of travel, you only need to either add or subtract 0.5 from the phase.
        </p>
        <p>
          There are a few basic y-phase values you need to know when getting started:<br/>
          For a circle, use y-phase 0.25 (counter-clockwise) or 0.75 (clockwise)<br/>
          For a figure eight, use y-phase 0 or 0.5<br/>
          For any x:1 ratio of frequencies:<br/>
            when x is even, use y-phase 0 or 0.5<br/>
            when x is odd, use y-phase 0.25 or 0.75<br/>
        </p>

        <h3>Linear Splines</h3>
        <p>
          Linear splines are a bit simpler to conceptualize than sine movement, but the syntax is slightly more complicated.
          The linear spline is comprised of one or more points in space, which are defined relative to one another.
          They are essentially a series of instructions telling the movement component how far to move on each axis on each step of the spline.
        </p>

        <pre><code class="code">linear_spline {
  type        linear
  controller  timer_1
  smoothing   steps
  points [
    [  5,  0 ]
    [  0,  5 ]
    [ -5, -5 ]
  ]
}</code></pre>

        <img src="../images/open_ended/devlogs/oe2_linear_spline.png" alt="Screenshot" class="fitimg" style="width:30%; margin-left:35%">
        <p>
          In the above example, we will move right 5 tiles, down 5 tiles, and then back up-left diagonally to the origin point. 
          Don't let the nested array syntax mess you up, because it only gets worse with bezier splines.
        </p>
        <p>
          Splines can also optionally have smoothing applied to them.
          The valid values for smoothing are "steps", "whole", or "none".
          Omitting this field, the value will default to none.
          As the names suggest, "steps" applies a smoothing over each individual step of the path and "whole" applies smoothing over the path as a whole.
        </p>

        <h3>Bezier Splines</h3>
        <p>
          Bezier splines are defined in much the same way as linear splines, however they require 3 points per step. 
          The first point specified is the next critical point on the path, and the 2nd and 3rd points are the two control points for the bezier curve.
          If you want to better understand how bezier curves work, I recommend just watching whatever you can find on YouTube to explain the concept.
        </p>

<pre><code class="code">bezier_spline {
  type        bezier
  controller  timer_1
  smoothing   whole
  points [ 
    [ [ 20, -20], [15, -5], [  5, -15] ]
    [ [-20,  20], [-5, 15], [-15,   5] ]
  ]
}</code></pre>

        <img src="../images/open_ended/devlogs/oe2_bezier_spline.png" alt="Screenshot" class="fitimg" style="width:40%; margin-left:30%">

        <p>
          Each step is an array of 3 points, each of which is a set of x and y coordinates.
          I recommend typing out your file in such a way that it's easy to see at a glance that you have the number of brackets and in the right places.
        </p>

        <h3>Pendulums</h3>
        <p>
          Pendulums are one of the simplest movement components to define overall. 
          They have only a few parameters that you need to know.
        </p>

<pre><code class="code">pendulum {
  type        pendulum
  controller  timer_1
  frequency 1
  angle     50
  amplitude 14
}</code></pre>

        <img src="../images/open_ended/devlogs/oe2_pendulum.png" alt="Screenshot" class="fitimg" style="width:30%; margin-left:35%">

        <p>
          Frequency is the number of times the pendulum will cycle in one full cycle of its controlling timer.
          This variable makes it easier for you to coordinate multiple pendulums off of the same timer, as instead of using several timers which are mutliples of one another, you can just increase the frequency in the omvement component.
          Angle is how wide the swing of the pendulum is. 
          So with a value of 50, the pendulum will swing 25 degrees in each direction.
          Amplitude is the distance that the pendulum "hangs" from the origin point. 
          Think of it like the length of the chain that a chandelier hangs from.
        </p>

        <h2>Next time...</h2>
        <p>
          That's all I've got for this time. 
          In the next post, I'll be talking about new types of timers, a little bit of the theory behind movement compontents, and maybe even rotations.
          
        </p>

				<hr>

			</div>
	</body>
</html>
_inserted_html_);
});

//
// #insert text. Generated from C:/Users/Noah/Documents/GitHub/Stuart-Mouse.github.io/.build/.added_strings_w2.jai:17.
//
table_add(*templates, "navbar", () {
write_html(#string _inserted_html_

<div class="topbar">
    <ul class="nav">
_inserted_html_);
 for settings.navbar_items { write_html(#string _inserted_html_
<li><a href="
_inserted_html_);
write_var(make_path_absolute(it.path));
write_html(#string _inserted_html_
">
_inserted_html_);
write_var(it.name);
write_html(#string _inserted_html_
</a></li>
_inserted_html_);
 } write_html(#string _inserted_html_
</ul>
</div>

_inserted_html_);
});
