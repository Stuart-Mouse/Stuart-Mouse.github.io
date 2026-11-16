
# SOTL Website Notes

## Issues with old site

The top bar does not stick properly
there's a weird bug with the scroll-to-top button
the background image has the logo text on it, but there's also text overlaid separately

## Needed functionality

- calendar
- integrate with tithe.ly stuff



## Layout Overview

Home Page:
- navigation bar
    - links to social media
    - administration
    - about orthodoxy
    - directions
    - service schedule
    - contact
    - wishlist
    - articles 
    - donation
- header
    - large image and title
- Lk. 19:10 and parish info
- building fund and donation link
- should also have a banner for upcoming or recent church events
- quotations from church fathers
- miniature calendar (next three days)
- feast days and scripture readings, troparia
    - need to fetch this info dynamically and then format accordingly

Home page TODO:
- [ ] complete the navigation bar
    - [ ] add navigation bar that only shows when screen is wide enough
        - when screen is too narrow, we should just always show the hamburger menu and top bar
    - [ ] fade out navigation bar during first half of logo transition
    - [X] fade in top bar during second hald of transition
    - [ ] fade in hamburger menu during second half of transition
    - [ ] cards with church fathers quotations
        - [X] columnar layout for displays with enough width
        - [ ] horizontally-scrolling layout for slimmer screens
            - This will also be needed for "This Week" service schedule
    - [ ] upcoming feast days
        - The current site has links to holytrinityorthodox.com which contain a bit more information about each feast day.
            - These links should be made more visible and should open up the content of the linked page inline somehow (iframe? But would be nice if we can re-style the contents...)
    - [ ] weekly scripture readings, troparia


Monthly Calendar
- need to be able to fetch this information and present it using the same basic template

Articles
- need better organization and ability to search



## CSS Notes

After trying several methods of making a better carousel for the cards of church father quotations,
I have temporarily given up in favor of just using a columnar layout for these cards.
Ultimately, this will not be a good approach for mobile, but maybe we can just swap to a more simple horizontally-scrolling layout in that case.


## Backend

I would like to try using Datastar to implement the basic backend functionality that will be needed for the website.  Unfortunately, I probably won't be able to use Jai and my own templating engine for this, since I am really blocked on that by not having a sufficient HTTP server to use.  

For now, it seems the best option available is to learn to write a little bit of Go, and to use Go with Templ and Datastar to serve the website.  I don't think I will really need a database for the time being, since there's not really any need to store data, only to retrieve and serve it.  And with the small amount of data I really need for the site, I can probably just store these things in simple text files or spreadsheets.


## References

An example of a Go application using Datastar, Templ, and Templier (hot reload for Templ, I guess):
https://github.com/romshark/todostar

As a better starting point, it seems that romshark also has a full framework called 'datapages':
https://github.com/romshark/datapages

I was able to get a fresh datapages project up and running relatively quickly, though there are a lot of stupid dependencies that need to be installed.  It seems like one it's up and running with hot reload, the workflow should be quite nice to quickly iterate.

FWIW, Templ seems like it may be a good reference when I eventually get around to working on my own Jai HTML templater again.  There are of course a million and one tweaky things to think about, and Templ seems to have documented a lot of those things in their guide.


Recently, a Jai discord user has also created their own new HTTP server framework called Falcon, which seems interesting.  There's also hyperserve by Raphael Luba to consider.  I may try using both of these a little bit and evaluate which one I want to use for my website generator / server.

Before doing too much with either of those though, I need to rewrite the website generator again and try to make it much cleaner using dynamic specialize.  A top priority will be making hot reloading work well, using a file watcher to detect changes in template files, recompiling and re-rendering the site as needed.  I will probably end up dropping the idea of statically linking / calling between templates/pages and instead use a reflection-based approach.  After rewriting the parser for the tamplating language, I can workshop ways to make the syntax nice while still balancing flexibility and static checking.  


I am also quite interested in the design choices of an Odin HTTP server / concurrency framework called 'tina':
https://github.com/pmbanugo/tina

This seems to be a well-architected solution, though I am probbaly not really in the best position to evaluate it.  The part that is most critical to me here is that it is fault-tolerant and can recover after crashes on the Isolates, which seems like a very important feature for a reliable web server.  Falcon does not yet have such an ability to recover after a crash, though I wonder how much effort would be required in order to implement that.



