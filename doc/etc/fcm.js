/**********************************************************************
 * Copyright (C) 2006-2021 British Crown (Met Office) & Contributors.
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

FCM = {};
$(function() {
    var TITLE_COLLAPSE = "collapse";
    var TITLE_EXPAND = "expand";
    var IS_MAIN = true;

    // Toggle a collapse/expand image.
    function collapse_expand_icon_toggle(anchor) {
        var icon = $("span", anchor);
        if (icon.attr("title") == TITLE_EXPAND) {
            icon.attr("title", TITLE_COLLAPSE);
            icon.removeClass("glyphicon-triangle-right");
            icon.addClass("glyphicon-triangle-bottom");
            anchor.siblings().filter("ul").show();
        }
        else { // if (icon.attr("title") == "collapse")
            icon.attr("title", TITLE_EXPAND);
            icon.removeClass("glyphicon-triangle-bottom");
            icon.addClass("glyphicon-triangle-right");
            anchor.siblings().filter("ul").hide();
        }
    }

    // Add collapse/expand anchor to a ul tree.
    function ul_collapse_expand(ul, is_main) {
        var nodes = $("li", ul);
        nodes.each(function(i) {
            var li = $(this);
            var li_anchor = li.children().first();
            if (!li_anchor.is("a")) {
                return;
            }
            var li_ul = $("> ul", li);
            li_ul.hide();
            var icon = $("<span/>", {"title": TITLE_EXPAND, "aria-hidden": "true"});
            icon.addClass("glyphicon");
            icon.addClass("glyphicon-triangle-right");
            icon.css("cursor", "pointer");
            icon.css("opacity", 0.5);
            var anchor = $("<a/>").append(icon);
            li.prepend(" ");
            li.prepend(anchor);
            if (is_main) {
                anchor.click(function() {
                    var href = li_anchor.attr("href");
                    $.get(
                        href,
                        function(data) {
                            collapse_expand_icon_toggle(anchor);
                            anchor.unbind("click");
                            if (content_gen(li, data, href)) {
                                ul_collapse_expand(li.children().filter("ul"));
                                anchor.click(function() {
                                    collapse_expand_icon_toggle(anchor);
                                });
                            }
                            else {
                                icon.css("opacity", 0.1);
                            }
                        },
                        "html"
                    )
                    .error(function(b) {
                        alert(b);
                        anchor.unbind("click");
                        icon.css("opacity", 0.1);
                    });
                });
            }
            else if (li_ul.length) {
                anchor.click(function() {
                    collapse_expand_icon_toggle(anchor);
                });
            }
            else {
                icon.css("opacity", 0.1);
            }
        });
    }

    // Generate table of content of a document.
    function content_gen(root, d, d_href) {
        if (d == null) {
            d = document;
        }
        var CONTENT_INDEX_OF = {"h2": 1, "h3": 2, "h4": 3, "h5": 4, "h6": 5};
        var stack = [];
        var done_something = false;
        var headings = $("h2, h3, h4, h5, h6", $(d));
        headings.each(function(i) {
            if (this.id == null || this.id == "") {
                return;
            }
            var tag_name = this.tagName.toLowerCase();
            // Add to table of content
            while (CONTENT_INDEX_OF[tag_name] < stack.length) {
                stack.shift();
            }
            while (stack.length < CONTENT_INDEX_OF[tag_name]) {
                var node = stack.length == 0 ? root : $("> :last-child", stack[0]);
                stack.unshift($("<ul/>").appendTo(node).addClass("list-unstyled"));
            }
            var href = "#" + this.id;
            if (d_href) {
                href = d_href + href;
            }
            var padding = "";
            for (var i = 0; i < stack.length; i++) {
                padding += "&nbsp;&nbsp;&nbsp;&nbsp;";
            }
            stack[0].append($("<li/>").html(padding).append(
                $("<a/>", {"href": href}).html($(this).text())
            ));

            // Add a section link as well
            if (d == document) {
                var section_link_anchor = $("<a/>", {"href": "#" + this.id});
                section_link_anchor.addClass("sectionlink");
                section_link_anchor.append("\xb6");
                $(this).append(section_link_anchor);
            }

            done_something = true;
        });
        return done_something;
    }

    var NODE;

    // Top page table of content
    NODE = $(".fcm-top-content");
    if (NODE) {
        ul_collapse_expand(NODE, IS_MAIN);
    }

    // Table of content
    NODE = $(".fcm-page-content");
    if (NODE) {
        if (content_gen(NODE)) {
            ul_collapse_expand(NODE);
        }
    }

    // Display version information
    NODE = $(".fcm-version");
    if (NODE) {
        NODE.text("FCM " + FCM.VERSION);
    }
});
