+++
title = "Folder Notes in Obsidian Publish"
description = "Wiring up Folder Notes behavior on your Publish site."
template =  "blog/single.html"

[taxonomies]
tags = [
    "Obsidian",
]

# [extra.image]
# path = "cover.jpg"
# colocated = true
# photographer = "Cristiano Firmani"
# source = "https://unsplash.com/photos/tmTidmpILWw"
+++

Recently, I've been participating in some very fun TTRPG games. [Obsidian](https://obsidian.md/) has become my favorite tool for taking notes.
One addon I've found which I quite like is [Folder Notes](https://github.com/LostPaul/obsidian-folder-notes).

I ended up getting a [Publish](https://obsidian.md/publish) subscription, and wanted to have a similar experience on the published site.
This weekend, I sat down and hacked a bit on it.
I'm relatively pleased with the end result and wanted to share.

<!-- more -->

I'm happy to report Obsidian feels pleasantly hackable, it's clearly a tool designed with malleability in mind.
I'm not much of a JS hacker anymore, but this was fun enough that I look foward to doing more.
Besides, it's nice to flex old muscles occasionally.

## Implementation

Without further ado, add the following to your [`publish.js`](https://help.obsidian.md/publish/customize#Static+assets):

```js
// publish.js

/** Selects an expandable. */
const folderNoteExpandableSelector = "div.tree-item-self.mod-collapsible:not(.mod-root)";
/** Selects an individual menu item. */
const foderNoteIndividualSelector = "div.tree-item-self:not(.mod-collapsible):not(.mod-root)";

/**
 * If the provided `expandableElement` has a Folder Note, wire up navigation.
 * @param {HTMLElement} expandableElem 
 * @returns 
 */
function updateFolderNoteExpandable(expandableElem) {
    let path = expandableElem.getAttribute("data-path");

    // Folder notes by default have the format `{parents}/{folder}/{folder}.md`
    // If you configured this differently, you might need to update this.
    let pathWithFolderNote = `${path}/${path.split("/").last()}.md`;

    // Obsidian's `app.site.cache.getCache` lets us find if the page exists.
    // We can't just scan the DOM, since the element might not exist yet.
    let detectedFolderNote = app.site.cache.getCache(pathWithFolderNote);
    if (detectedFolderNote === null || detectedFolderNote === undefined) {
        return;
    }
    expandableElem.classList.add("has-folder-note");
    
    // Add our own click handler to the expandable that uses Obsidian's `app.navigate`,
    // doing an `<a href="...">` results in page reload jank.
    let expandableInnerElem = expandableElem.querySelector("div.tree-item-inner");
    expandableInnerElem.addEventListener("click", _ => {
        app.navigate(pathWithFolderNote, "", null);
    });
 
    // We stash the children to use later on the replacement, they keep their events.
    let expandableChildren = expandableElem.childNodes;
    
    // Strip click events off the expandable by cloning it.
    let replacerElem = expandableElem.cloneNode(false);
    // Put the children back (with events)
    replacerElem.replaceChildren(...expandableChildren);
    // Swap the old evented element with the new one we've wired in.
    expandableElem.replaceWith(replacerElem);
}

/**
 * If the provided `individualElem` is a Folder Note, hide it.
 * @param {HTMLElement} individualElem 
 * @returns 
 */
function updateFolderNoteIndividual(individualElem) {
    let individualElemPath = individualElem.getAttribute("data-path");
    
    // If a folder note exists, it'll be called `{parents}/{note_without_extension}`
    let fileName = individualElemPath.split("/").last();

    if (!fileName.endsWith(".md")) {
        // This is a folder... That's not good. Bail.
        console.warn("Got an individual update for a folder?", individualElem);
        return;
    }

    let fileNameExtensionless = fileName.replace(".md", "");
    let folderNotePath = individualElemPath.replace(`${fileNameExtensionless}/${fileName}`, fileNameExtensionless);
    if (individualElemPath == folderNotePath) {
        // This item did not have the makings of a Folder Note, the path didn't make sense.
        return;
    }

    // See if a folder exists that this is a Folder Note for.
    let folderNoteSelector = `${folderNoteExpandableSelector}[data-path="${folderNotePath}"]`;
    let detectedFolderNoteElem = document.querySelector(folderNoteSelector);
    if (detectedFolderNoteElem === null) {
        // This is not the Folder Note for a menu item.
        return;
    }

    individualElem.classList.add("folder-note");
}

/**
 * Wire up Folder Notes for anything in the `rootElem`.
 * @param {HTMLElement} rootElem 
 */
function updateFolderNotes(rootElem) {
    for (individualElem of rootElem.querySelectorAll(foderNoteIndividualSelector)) {
        updateFolderNoteIndividual(individualElem);
    }
    for (expandableElem of rootElem.querySelectorAll(folderNoteExpandableSelector)) {
        updateFolderNoteExpandable(expandableElem);
    }
}

/**
 * Start up the `MutationObserver` for Folder Notes.
 */
function injectFolderNoteObserver() {
    let config = { childList: true, subtree: true };
    let callback = (mutationList, _observer) => {
        for (let mutation of mutationList) {
            if (mutation.type !== "childList") {
                return;
            }
            for (addedNode of mutation.addedNodes) {
                updateFolderNotes(addedNode);
            }
        }
    };
    updateFolderNotes(document);
    let observer = new MutationObserver(callback);
    let nav = document.querySelector("div.nav-view");
    observer.observe(nav, config);
}

injectFolderNoteObserver();
```

Then, in your [`publish.css`](https://help.obsidian.md/publish/customize#Static+assets) add this rule:

```css
/* publish.css */
div.folder-note {
	display: none;
}
```

## Caveats

You apparently need a [Custom Domain](https://help.obsidian.md/publish/domains) for this. I had one, so it wasn't a problem for me.

This may break in future versions of Obsidian Publish. I likely won't update this unless I am still using Obsidian Publish myself, and Folder Notes, and notice, and remember to update this page. You might need to hack yourself, so I left it well commented.