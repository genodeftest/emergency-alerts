/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2024 Leonhard (leo.kargl@proton.me)
 */

public class EmA.RSSProvider : ProviderTemplate {
    public string feed_url { private get; construct; }
    public CountryCode country_code { private get; construct; }

    public RSSProvider (string feed_url, CountryCode country_code) {
        Object (feed_url: feed_url, country_code: country_code);
    }

    construct {
        name = _("%s RSS").printf (country_code.to_string ());
        add_supported_country_code (country_code);

        supports_fill_for_point = false;
    }

    public override async void fill_for_all (Gee.HashSet<Warning> updated_warnings) throws Error {
        var doc = yield Utils.get_xml (feed_url);

        var rss = doc->get_root_element ();

        try {
            yield parse_rss (updated_warnings, rss);
        } catch (Error e) {
            throw e;
        } finally {
            delete doc;
        }
    }

    private async void parse_rss (Gee.HashSet<Warning> updated_warnings, Xml.Node* rss) throws Error {
        if (rss->name != "rss" || rss->children == null) {
            throw new IOError.FAILED ("Unexpected element");
        }

        Xml.Node* channel = null;
        for (Xml.Node* node = rss->children; node != null; node = node->next) {
            if (node->name == "channel") {
                channel = node;
                break;
            }
        }

        if (channel == null) {
            throw new IOError.FAILED ("Missing channel element");
        }

        for (Xml.Node* node = channel->children; node != null; node = node->next) {
            if (node->name == "item") {
                yield parse_item (updated_warnings, node);
            }
        }
    }

    private async void parse_item (Gee.HashSet<Warning> updated_warnings, Xml.Node* node) throws Error {
        assert (node->name == "item");

        if (node->children == null) {
            throw new IOError.FAILED ("Unexpected element");
        }

        for (Xml.Node* child = node->children; child != null; child = child->next) {
            if (child->name == "link") {
                var link = child->children->get_content ();
                var doc = yield Utils.get_xml (link);
                var doc_object = new DocObject (doc);
                yield load_warning (link, doc_object, updated_warnings);
                break;
            }
        }
    }

    protected async override MultiPolygon get_warning_area (string id, Object? data) throws Error {
        var doc_object = (DocObject) data;
        var doc = doc_object.doc;

        var alert = doc->get_root_element ();

        if (alert->name != "alert") {
            throw new IOError.FAILED ("Unexpected element");
        }

        Xml.Node* info_node = null;
        for (Xml.Node* node = alert->children; node != null; node = node->next) {
            if (node->name == "info") {
                info_node = node;
                break;
            }
        }

        if (info_node == null) {
            throw new IOError.FAILED ("Missing info element");
        }

        Xml.Node*[] polygon_nodes = {};
        for (Xml.Node* node = info_node->children; node != null; node = node->next) {
            if (node->name == "area") {
                for (Xml.Node* area_child = node->children; area_child != null; area_child = area_child->next) {
                    if (area_child->name == "polygon") {
                        polygon_nodes += area_child;
                    }
                }
            }
        }

        if (polygon_nodes.length == 0) {
            throw new IOError.FAILED ("Missing polygon element");
        }

        var content = polygon_nodes[0]->children->get_content ();

        var points = content.split (" ");
        var coordinates = new Coordinate[0];
        for (uint i = 0; i < points.length; i++) {
            var str = points[i];

            if (str.strip () == "") {
                continue;
            }

            var coords = str.split (",");

            if (coords.length != 2) {
                throw new IOError.FAILED ("Invalid coordinate format");
            }

            var lat = double.parse (coords[0]);
            var lon = double.parse (coords[1]);

            coordinates += new Coordinate (lat, lon);
        }

        var polygon = new Polygon.from_coordinates (coordinates);

        return new MultiPolygon.from_polygons ({ polygon });
    }

    protected async override void fill_warning (Warning warn, Object? data) throws Error {
        var doc_object = (DocObject) data;
        var doc = doc_object.doc;

        var alert = doc->get_root_element ();

        if (alert->name != "alert") {
            throw new IOError.FAILED ("Unexpected element");
        }

        CAP.fill_warning_details_from_alert_xml (warn, alert);
    }

    private class DocObject : Object {
        public Xml.Doc* doc;

        public DocObject (Xml.Doc* doc) {
            this.doc = doc;
        }

        ~DocObject () {
            delete doc;
        }
    }
}
