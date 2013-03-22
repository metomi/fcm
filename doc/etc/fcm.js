/**********************************************************************
 * (C) British Crown Copyright 2006-2013 Met Office.
 *
 * This file is part of FCM.
 *
 * FCM is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FCM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with FCM. If not, see <http://www.gnu.org/licenses/>.
 *
 **********************************************************************/

/**********************************************************************
 * JS for displaying information of FCM documents.
 *
 **********************************************************************/

FCM = {
    // List of heading tags for the contents
    "CONTENT_INDEX_OF": {"H2": 0, "H3": 1, "H4": 2, "H5": 3, "H6": 4},
    // ID in a document, for the content
    "ID_OF_CONTENT": "fcm-content",
    // ID in a document, for the breadcrumb trail
    "ID_OF_TRAIL": "fcm-js-trail",
    // ID in a document, for the breadcrumb trail
    "ID_OF_VERSION": "fcm-version",

    // Making DOM manipulation less painful
    "DOM": {
        // The current document
        "DOC": document,

        // Adds an array of "nodes" (Node or String) to "node"
        "append": function(node, items) {
            if (node == null || items == null) {
                return;
            }
            for (var i = 0; i < items.length; i++) {
                if (items[i] == null) {
                    continue;
                }
                if (items[i].nodeType == null) {
                    node.appendChild(this.DOC.createTextNode(items[i]));
                }
                else {
                    node.appendChild(items[i]);
                }
            }
        },

        // Returns the base name of a URL, relative to current document
        "basename": function(url) {
            if (url == null) {
                url = this.DOC.URL;
            }
            return url.substr(this.DOC.URL.lastIndexOf("/") + 1);
        },

        // Creates and returns an element
        "create": function(tag, items, attribs) {
            var element = this.DOC.createElement(tag);
            this.append(element, items);
            if (attribs == null) {
                return element;
            }
            for (var i = 0; i < attribs.length; i++) {
                element[attribs[i][0]] = attribs[i][1];
            }
            return element;
        },

        // Shorthand for root[attrib]
        "get_attrib": function(root, attrib) {
            return root[attrib];
        },

        // Shorthand for this.DOC.getElementById(id)
        "get_by_id": function(id) {
            return this.DOC.getElementById(id);
        },

        // Shorthand for root.getElementsByTagName(name)[i]
        "get_by_name": function(root, name, i) {
            var elements = root.getElementsByTagName(name);
            if (i == null) {
                return elements;
            }
            if (elements == null || i >= elements.length) {
                return null;
            }
            return elements[i];
        },

        "map": function(action_on, items) {
            var ret = [];
            for (var i = 0; i < items.length; i++) {
                ret = ret.concat(action_on(items[i], i));
            }
            return ret;
        }
    },

    // Creates and returns the content
    "create_content": function() {
        var root = $D.get_attrib($D.DOC, "body");
        var stack = [{content: null, item: null}];
        for (var node = root.firstChild; node != null; node = node.nextSibling) {
            if (
                node.nodeType != 1
                || node.id == null
                || node.id == ""
                || this.CONTENT_INDEX_OF[node.tagName] == null
                || this.CONTENT_INDEX_OF[node.tagName] + 1 > stack.length
            ) {
                continue;
            }
            while (this.CONTENT_INDEX_OF[node.tagName] + 1 < stack.length) {
                stack.shift();
            }
            if (stack[0].content == null) {
                stack[0].content = $D.create("ul");
                if (stack[0].item != null) {
                    $D.append(stack[0].item, [stack[0].content]);
                }
            }
            var item = $D.create(
                "li",
                [$D.create("a", [node.innerHTML], [["href", "#" + node.id]])]
            );
            $D.append(stack[0].content, [item]);
            stack.unshift({content: null, item: item});
            // Adds a section link as well
            var sectionlink
                = $D.create("a", ["\xb6"], [["href", "#" + node.id]]);
            sectionlink.className = "sectionlink";
            $D.append(node, [sectionlink]);
        }
        return [stack[stack.length - 1].content];
    },

    // Creates a breadcrumb trail from a list of [[href, text], ...]
    "create_trail": function() {
        var title = $D.get_by_name($D.DOC, "title", 0).innerHTML;
        var head = title.substr(0, title.indexOf(":"));
        var tail = title.substr(title.indexOf(":") + 1);
        return [].concat($D.create("a", [head], [["href", "."]]), " > ", tail);
    },

    // A simple facade for doing the onload tasks
    "load": function() {
        var tasks = [
            {
                "id": FCM.ID_OF_CONTENT,
                "task": function() {
                    return FCM.create_content();
                }
            },
            {
                "id": FCM.ID_OF_TRAIL,
                "task": function() {
                    return FCM.create_trail();
                }
            },
            {
                "id": FCM.ID_OF_VERSION,
                "task": function() {
                    return FCM.VERSION;
                }
            }
        ];
        for (var i = 0; i < tasks.length; i++) {
            var node = $D.get_by_id(tasks[i].id);
            if (node == null) {
                continue;
            }
            $D.append(node, tasks[i].task());
        }
    }
};
$D = FCM.DOM;
window.onload = FCM.load;
