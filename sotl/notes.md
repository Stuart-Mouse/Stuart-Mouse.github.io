
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


Monthly Calendar
- need to be able to fetch this information and present it using the same basic template

Articles
- need better organization and ability to search





## Backend

I would like to try using Datastar to implement the basic backend functionality that will be needed for the website.  Unfortunately, I probably won't be able to use Jai and my own templating engine for this, since I am really blocked on that by not having a sufficient HTTP server to use.  

For now, it seems the best option available is to learn to write a little bit of Go, and to use Go with Templ and Datastar to serve the website.  I don't think I will really need a database for the time being, since there's not really any need to store data, only to retrieve and serve it.  And with the small amount of data I really need for the site, I can probably just store these things in simple text files or spreadsheets.


## References

An example of a Go application using Datastar, Templ, and Templier (hot reload for Templ, I guess):
https://github.com/romshark/todostar
